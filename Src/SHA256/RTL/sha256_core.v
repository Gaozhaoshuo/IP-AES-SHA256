// ============================================================
// SHA-256 Core (compression only)
// - Expects 512-bit pre-padded blocks: 16 x 32-bit beats
// - cmd_valid_init: start new message (H := IV)
// - cmd_valid_next: start next block (H keeps)
// - cmd_last indicates last block
// - One round per cycle after data accepted (round 0..15 during RECV, 16..63 during RUN)
// ============================================================
module sha256_core (
    input clk,
    input rst_n,

    // Command interface
    input  cmd_valid_init,  // start new message (H=IV)
    input  cmd_valid_next,  // start next block (H keeps)
    input  cmd_last,        // last block of message
    output cmd_ready,       // high only when idle

    // AXI-stream 32-bit input (512-bit block = 16 beats)
    input  [31:0] s_axis_tdata,
    input         s_axis_tvalid,
    input         s_axis_tlast,   // asserted on last beat of every block of message
    output        s_axis_tready,

    // Digest output (pulse valid)
    output [255:0] digest,
    output         digest_valid
);

  // ----------------------------
  // Parameters: IV constants
  // ----------------------------
  localparam [31:0] IV0 = 32'h6a09e667;
  localparam [31:0] IV1 = 32'hbb67ae85;
  localparam [31:0] IV2 = 32'h3c6ef372;
  localparam [31:0] IV3 = 32'ha54ff53a;
  localparam [31:0] IV4 = 32'h510e527f;
  localparam [31:0] IV5 = 32'h9b05688c;
  localparam [31:0] IV6 = 32'h1f83d9ab;
  localparam [31:0] IV7 = 32'h5be0cd19;

  // ----------------------------
  // FSM
  // ----------------------------
  localparam IDLE = 3'd0;
  localparam INIT = 3'd1;
  localparam RECV = 3'd2;  // rounds 0..15 while receiving 16 words
  localparam RUN = 3'd3;  // rounds 16..63 internal
  localparam FINAL = 3'd4;
  localparam DONE = 3'd5;

  wire [ 31:0] Wt;
  wire [ 31:0] Kt;
  wire [255:0] work_out;

  reg [2:0] state_reg, state_next;

  reg [5:0] round_idx_reg, round_idx_next;
  reg [255:0] H_chain_reg, H_next;
  reg last_block_reg, last_block_next;

  wire init_en;
  wire step_en;
  wire s_fire;

  reg cmd_ready_reg, cmd_ready_next;
  reg s_axis_tready_reg, s_axis_tready_next;

  reg [255:0] digest_reg, digest_next;
  reg digest_valid_reg, digest_valid_next;

  assign cmd_ready = cmd_ready_reg;
  assign s_axis_tready = s_axis_tready_reg;
  assign digest = digest_reg;
  assign digest_valid = digest_valid_reg;

  // ---- k_lut (combinational)
  sha256_k_lut u_k_lut (
      .round_idx(round_idx_reg),
      .k_out    (Kt)
  );

  // ---- wreg
  sha256_wreg u_wreg (
      .clk      (clk),
      .rst_n    (rst_n),
      .step_en  (step_en),
      .round_idx(round_idx_reg),
      .in_word  (s_axis_tdata),
      .Wt       (Wt)
  );

  // ---- loop
  sha256_loop u_loop (
      .clk      (clk),
      .rst_n    (rst_n),
      .init_en  (init_en),
      .step_en  (step_en),
      .Wt_in    (Wt),
      .Kt_in    (Kt),
      .H_in     (H_chain_reg),
      .work_out (work_out)
  );

  wire [31:0] wa = work_out[255:224];
  wire [31:0] wb = work_out[223:192];
  wire [31:0] wc = work_out[191:160];
  wire [31:0] wd = work_out[159:128];
  wire [31:0] we = work_out[127:96];
  wire [31:0] wf = work_out[95:64];
  wire [31:0] wg = work_out[63:32];
  wire [31:0] wh = work_out[31:0];

  wire [31:0] Ha = H_chain_reg[255:224];
  wire [31:0] Hb = H_chain_reg[223:192];
  wire [31:0] Hc = H_chain_reg[191:160];
  wire [31:0] Hd = H_chain_reg[159:128];
  wire [31:0] He = H_chain_reg[127:96];
  wire [31:0] Hf = H_chain_reg[95:64];
  wire [31:0] Hg = H_chain_reg[63:32];
  wire [31:0] Hh = H_chain_reg[31:0];

  always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      state_reg <= IDLE;
      round_idx_reg <= 6'd0;
      H_chain_reg <= {IV0, IV1, IV2, IV3, IV4, IV5, IV6, IV7};
      last_block_reg <= 1'b0;
      digest_reg <= 256'd0;
      digest_valid_reg <= 1'b0;
      s_axis_tready_reg <= 1'b0;
      cmd_ready_reg <= 1'b1;
    end else begin
      state_reg <= state_next;
      round_idx_reg <= round_idx_next;
      H_chain_reg <= H_next;
      last_block_reg <= last_block_next;
      digest_reg <= digest_next;
      digest_valid_reg <= digest_valid_next;
      s_axis_tready_reg <= s_axis_tready_next;
      cmd_ready_reg <= cmd_ready_next;
    end
  end

  assign s_fire  = s_axis_tvalid && s_axis_tready_reg;
  assign init_en = (state_reg == INIT);
  assign step_en = (state_reg == RUN) ? 1'b1 : (state_reg == RECV) ? s_fire : 1'b0;


  always @(*) begin
    state_next = state_reg;
    round_idx_next = round_idx_reg;
    H_next = H_chain_reg;
    last_block_next = last_block_reg;
    digest_next = digest_reg;
    digest_valid_next = 1'b0;
    s_axis_tready_next = 1'b0;
    cmd_ready_next = 1'b0;
    case (state_reg)
      IDLE: begin
        cmd_ready_next = 1'b1;
        if (cmd_valid_init || cmd_valid_next) begin
          state_next = INIT;
          round_idx_next = 6'd0;
          H_next = cmd_valid_next ? H_chain_reg : {IV0, IV1, IV2, IV3, IV4, IV5, IV6, IV7};
          last_block_next = cmd_last;
        end else begin
          state_next = IDLE;
        end
      end

      INIT: begin
        state_next = RECV;
        s_axis_tready_next = 1'b1;
      end

      RECV: begin
        s_axis_tready_next = 1'b1;
        if (s_fire) begin
          state_next = (s_axis_tlast && round_idx_reg == 6'd15) ? RUN : RECV;
          round_idx_next = round_idx_reg + 6'd1;
        end
      end

      RUN: begin
        if (round_idx_reg == 6'd63) begin
          state_next = FINAL;
          round_idx_next = 6'd0;
        end else begin
          state_next = RUN;
          round_idx_next = round_idx_reg + 6'd1;
        end
      end

      FINAL: begin
        state_next = last_block_reg ? DONE : IDLE;
        H_next = {(Ha + wa), (Hb + wb), (Hc + wc), (Hd + wd), (He + we), (Hf + wf), (Hg + wg), (Hh + wh)};
      end

      DONE: begin
        state_next = IDLE;
        cmd_ready_next = 1'b1;
        digest_next = H_chain_reg;
        digest_valid_next = 1'b1;
      end
    endcase
  end

endmodule
