module aes_flow_ctrl #(
    parameter AXI_ADDR_WIDTH = 32,
    parameter LEN_WIDTH      = 20,
    parameter TAG_WIDTH      = 8
) (
    input wire clk,
    input wire rst_n,

    // -------------------------
    // cfg
    // -------------------------
    input wire         cfg_key_gen,    // 1T pulse to start key expansion
    input wire         cfg_blk_sof,    // 1T pulse, start a bulk
    input wire [ 31:0] cfg_blk_base,
    input wire [ 31:0] cfg_blk_len,    // bytes-1, low nibble should be 4'hf
    input wire [ 31:0] cfg_code_base,
    input wire         cfg_enc_dec,
    input wire [  1:0] cfg_blk_mode,
    input wire [  1:0] cfg_key_len,
    input wire [255:0] cfg_key,
    input wire [127:0] cfg_iv,

    output reg set_blk_end,  // 1T pulse to cfg

    // -------------------------
    // DMA-RD descriptor
    // -------------------------
    output wire [AXI_ADDR_WIDTH-1:0] rd_desc_addr,
    output wire [     LEN_WIDTH-1:0] rd_desc_len,
    output wire [     TAG_WIDTH-1:0] rd_desc_tag,
    output wire                      rd_desc_valid,
    input  wire                      rd_desc_ready,
    input  wire [               3:0] rd_desc_status_error,
    input  wire                      rd_desc_status_valid,

    // -------------------------
    // DMA-WR descriptor
    // -------------------------
    output wire [AXI_ADDR_WIDTH-1:0] wr_desc_addr,
    output wire [     LEN_WIDTH-1:0] wr_desc_len,
    output wire                      wr_desc_valid,
    input  wire                      wr_desc_ready,
    input  wire [               3:0] wr_desc_status_error,
    input  wire                      wr_desc_status_valid,

    // -------------------------
    // ibuf (axis32_to_block128)
    // -------------------------
    output reg  ibuf_pop,   // 1T pulse at block end
    input  wire ibuf_empty,

    // -------------------------
    // obuf (block128_to_axis32)
    // -------------------------
    input wire obuf_full,

    // -------------------------
    // aes_core
    // -------------------------
    output wire         aes_encdec,
    output wire [127:0] aes_iv,
    output wire         aes_init,
    output wire         aes_next,
    input  wire         key_ready,
    output wire         aes_first_blk,
    output wire [  1:0] aes_blk_mode,
    output wire [255:0] aes_key_in,
    output wire [  1:0] aes_key_len,
    input  wire         aes_result_valid
);

  // ------------------------------------------------------------
  // latch cfg at bulk start
  // ------------------------------------------------------------
  reg [31:0] blk_base_reg, blk_base_next;
  reg [31:0] code_base_reg, code_base_next;
  reg [31:0] blk_len_reg, blk_len_next;
  reg enc_dec_reg, enc_dec_next;
  reg [1:0] blk_mode_reg, blk_mode_next;
  reg [1:0] key_len_reg, key_len_next;
  reg [255:0] key_reg, key_next;
  reg [127:0] iv_reg, iv_next;

  // ------------------------------------------------------------
  // descriptor regs
  // ------------------------------------------------------------
  reg [AXI_ADDR_WIDTH-1:0] rd_desc_addr_reg, rd_desc_addr_next;
  reg [LEN_WIDTH-1:0] rd_desc_len_reg, rd_desc_len_next;
  reg [TAG_WIDTH-1:0] rd_desc_tag_reg, rd_desc_tag_next;
  reg rd_desc_valid_reg, rd_desc_valid_next;

  reg [AXI_ADDR_WIDTH-1:0] wr_desc_addr_reg, wr_desc_addr_next;
  reg [LEN_WIDTH-1:0] wr_desc_len_reg, wr_desc_len_next;
  reg wr_desc_valid_reg, wr_desc_valid_next;

  assign rd_desc_addr  = rd_desc_addr_reg;
  assign rd_desc_len   = rd_desc_len_reg;
  assign rd_desc_tag   = rd_desc_tag_reg;
  assign rd_desc_valid = rd_desc_valid_reg;

  assign wr_desc_addr  = wr_desc_addr_reg;
  assign wr_desc_len   = wr_desc_len_reg;
  assign wr_desc_valid = wr_desc_valid_reg;

  // ------------------------------------------------------------
  // aes outputs from latched cfg
  // ------------------------------------------------------------
  assign aes_encdec    = enc_dec_reg;
  assign aes_iv        = iv_reg;
  assign aes_blk_mode  = blk_mode_reg;
  assign aes_key_in    = key_reg;
  assign aes_key_len   = key_len_reg;

  // pulses are regs (1T)
  reg aes_init_reg, aes_init_next;
  reg aes_next_reg, aes_next_next;
  reg aes_first_blk_reg, aes_first_blk_next;

  assign aes_init      = aes_init_reg;
  assign aes_next      = aes_next_reg;
  assign aes_first_blk = aes_first_blk_reg;

  // ------------------------------------------------------------
  // block counters
  // cfg_blk_len is bytes-1, aligned to 16B => total_blks = (blk_len>>4) + 1
  // here: total_blks = (blk_len[31:4]) + 1
  // ------------------------------------------------------------
  reg [27:0] total_blks_reg, total_blks_next;
  reg [27:0] blk_sent_reg, blk_sent_next;  // number of blocks already issued (aes_next fired)
  reg last_inflight_reg, last_inflight_next;

  wire [27:0] total_blks_calc = {4'd0, blk_len_reg[31:4]} + 28'd1;
  wire        can_start_block = key_ready && !ibuf_empty && !obuf_full;

  // ------------------------------------------------------------
  // handshake / status
  // ------------------------------------------------------------
  wire        rd_hs = rd_desc_valid_reg && rd_desc_ready;
  wire        wr_hs = wr_desc_valid_reg && wr_desc_ready;

  reg rd_issued_reg, rd_issued_next;
  reg wr_issued_reg, wr_issued_next;

  reg rd_done_reg, rd_done_next;
  reg wr_done_reg, wr_done_next;

  // ------------------------------------------------------------
  // key_gen latch (optional but robust): convert 1T pulse to pending
  // ------------------------------------------------------------
  reg keygen_req_reg, keygen_req_next;

typedef enum logic [2:0] {
  IDLE       = 3'd0,
  ISSUE_DESC = 3'd1,
  RUN        = 3'd2,
  WAIT_CAL   = 3'd3,
  DONE       = 3'd4
} state_t;

state_t state_reg, state_next;


  // ------------------------------------------------------------
  // sequential
  // ------------------------------------------------------------
  always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      state_reg         <= IDLE;

      blk_base_reg      <= 32'd0;
      code_base_reg     <= 32'd0;
      blk_len_reg       <= 32'd0;
      enc_dec_reg       <= 1'b0;
      blk_mode_reg      <= 2'd0;
      key_len_reg       <= 2'd0;
      key_reg           <= 256'd0;
      iv_reg            <= 128'd0;

      rd_desc_addr_reg  <= {AXI_ADDR_WIDTH{1'b0}};
      rd_desc_len_reg   <= {LEN_WIDTH{1'b0}};
      rd_desc_tag_reg   <= {TAG_WIDTH{1'b0}};
      rd_desc_valid_reg <= 1'b0;

      wr_desc_addr_reg  <= {AXI_ADDR_WIDTH{1'b0}};
      wr_desc_len_reg   <= {LEN_WIDTH{1'b0}};
      wr_desc_valid_reg <= 1'b0;

      aes_init_reg      <= 1'b0;
      aes_next_reg      <= 1'b0;
      aes_first_blk_reg <= 1'b0;

      total_blks_reg    <= 28'd0;
      blk_sent_reg      <= 28'd0;
      last_inflight_reg <= 1'b0;

      rd_issued_reg     <= 1'b0;
      wr_issued_reg     <= 1'b0;
      rd_done_reg       <= 1'b0;
      wr_done_reg       <= 1'b0;

      keygen_req_reg    <= 1'b0;

    end else begin
      state_reg         <= state_next;

      blk_base_reg      <= blk_base_next;
      code_base_reg     <= code_base_next;
      blk_len_reg       <= blk_len_next;
      enc_dec_reg       <= enc_dec_next;
      blk_mode_reg      <= blk_mode_next;
      key_len_reg       <= key_len_next;
      key_reg           <= key_next;
      iv_reg            <= iv_next;

      rd_desc_addr_reg  <= rd_desc_addr_next;
      rd_desc_len_reg   <= rd_desc_len_next;
      rd_desc_tag_reg   <= rd_desc_tag_next;
      rd_desc_valid_reg <= rd_desc_valid_next;

      wr_desc_addr_reg  <= wr_desc_addr_next;
      wr_desc_len_reg   <= wr_desc_len_next;
      wr_desc_valid_reg <= wr_desc_valid_next;

      aes_init_reg      <= aes_init_next;
      aes_next_reg      <= aes_next_next;
      aes_first_blk_reg <= aes_first_blk_next;

      total_blks_reg    <= total_blks_next;
      blk_sent_reg      <= blk_sent_next;
      last_inflight_reg <= last_inflight_next;

      rd_issued_reg     <= rd_issued_next;
      wr_issued_reg     <= wr_issued_next;
      rd_done_reg       <= rd_done_next;
      wr_done_reg       <= wr_done_next;

      keygen_req_reg    <= keygen_req_next;
    end
  end

  // ------------------------------------------------------------
  // combinational
  // ------------------------------------------------------------
  always @(*) begin
    // defaults
    state_next         = state_reg;

    blk_base_next      = blk_base_reg;
    code_base_next     = code_base_reg;
    blk_len_next       = blk_len_reg;
    enc_dec_next       = enc_dec_reg;
    blk_mode_next      = blk_mode_reg;
    key_len_next       = key_len_reg;
    key_next           = key_reg;
    iv_next            = iv_reg;

    rd_desc_addr_next  = rd_desc_addr_reg;
    rd_desc_len_next   = rd_desc_len_reg;
    rd_desc_tag_next   = rd_desc_tag_reg;
    rd_desc_valid_next = rd_desc_valid_reg;

    wr_desc_addr_next  = wr_desc_addr_reg;
    wr_desc_len_next   = wr_desc_len_reg;
    wr_desc_valid_next = wr_desc_valid_reg;

    // 1T pulses default low
    aes_init_next      = 1'b0;
    aes_next_next      = 1'b0;
    aes_first_blk_next = 1'b0;

    ibuf_pop           = 1'b0;
    set_blk_end        = 1'b0;

    total_blks_next    = total_blks_reg;
    blk_sent_next      = blk_sent_reg;
    last_inflight_next = last_inflight_reg;

    rd_issued_next     = rd_issued_reg;
    wr_issued_next     = wr_issued_reg;
    rd_done_next       = rd_done_reg;
    wr_done_next       = wr_done_reg;

    // keygen latch: capture pulse -> pending
    keygen_req_next    = keygen_req_reg | cfg_key_gen;

    // descriptor valid hold-until-handshake
    if (rd_hs) rd_desc_valid_next = 1'b0;
    if (wr_hs) wr_desc_valid_next = 1'b0;

    // issued flags set on handshake, cleared on new bulk
    if (rd_hs) rd_issued_next = 1'b1;
    if (wr_hs) wr_issued_next = 1'b1;

    // done flags set on status_valid, cleared on new bulk
    if (rd_desc_status_valid) rd_done_next = 1'b1;
    if (wr_desc_status_valid) wr_done_next = 1'b1;

    // if keygen pending and core not ready, fire aes_init once
    if (keygen_req_reg && !key_ready) begin
      aes_init_next   = 1'b1;
      keygen_req_next = 1'b0;  // 已经发出 init
    end

    case (state_reg)
      // --------------------------------------------------------
      // IDLE: wait cfg_blk_sof, latch cfg, prepare to issue desc
      // --------------------------------------------------------
      IDLE: begin
        // 清 bulk 相关标志
        rd_issued_next     = 1'b0;
        wr_issued_next     = 1'b0;
        rd_done_next       = 1'b0;
        wr_done_next       = 1'b0;
        blk_sent_next      = 28'd0;
        last_inflight_next = 1'b0;

        // latch cfg
        blk_base_next      = cfg_blk_base;
        code_base_next     = cfg_code_base;
        blk_len_next       = cfg_blk_len;
        enc_dec_next       = cfg_enc_dec;
        blk_mode_next      = cfg_blk_mode;
        key_len_next       = cfg_key_len;
        key_next           = cfg_key;
        iv_next            = cfg_iv;

        if (cfg_blk_sof) begin
          // total blocks (note: use cfg directly to avoid old-reg bug)
          total_blks_next    = {4'd0, blk_len_reg[31:4]} + 28'd1;

          // issue RD descriptor
          rd_desc_addr_next  = blk_base_reg;
          rd_desc_len_next   = blk_len_reg[LEN_WIDTH-1:0];
          rd_desc_tag_next   = {TAG_WIDTH{1'b0}};
          rd_desc_valid_next = 1'b1;

          // issue WR descriptor
          wr_desc_addr_next  = code_base_reg;
          wr_desc_len_next   = blk_len_reg[LEN_WIDTH-1:0];
          wr_desc_valid_next = 1'b1;

          state_next         = ISSUE_DESC;
        end
      end

      // --------------------------------------------------------
      // ISSUE_DESC: keep valid high until both handshakes done
      // --------------------------------------------------------
      ISSUE_DESC: begin
        // stay here until both descriptors accepted
        if (rd_issued_reg && wr_issued_reg) begin
          state_next = RUN;
        end
      end

      // --------------------------------------------------------
      // RUN: wait for resources, fire aes_next to start one block
      // --------------------------------------------------------
      RUN: begin
        if (can_start_block) begin
          // fire aes_next 1T
          aes_next_next = 1'b1;

          // first block flag only for the first issued block
          if (blk_sent_reg == 28'd0) aes_first_blk_next = 1'b1;
          else aes_first_blk_next = 1'b0;

          // mark whether this in-flight block is last one
          if (blk_sent_reg == (total_blks_reg - 28'd1)) last_inflight_next = 1'b1;
          else last_inflight_next = 1'b0;

          // count issued block
          blk_sent_next = blk_sent_reg + 28'd1;

          // go wait calculation done
          state_next = WAIT_CAL;
        end
      end

      // --------------------------------------------------------
      // WAIT_CAL: wait aes_result_valid, then pop ibuf
      // --------------------------------------------------------
      WAIT_CAL: begin
        if (aes_result_valid) begin
          // pop input block AFTER result valid
          ibuf_pop = 1'b1;

          if (last_inflight_reg) begin
            state_next = DONE;
          end else begin
            state_next = RUN;
          end
        end
      end

      // --------------------------------------------------------
      // DONE: wait DMA status, then pulse set_blk_end
      // --------------------------------------------------------
      DONE: begin
        if (wr_done_reg) begin
          set_blk_end = 1'b1;  // 1T pulse
          state_next  = IDLE;
        end
      end

      default: begin
        state_next = IDLE;
      end
    endcase
  end

endmodule
