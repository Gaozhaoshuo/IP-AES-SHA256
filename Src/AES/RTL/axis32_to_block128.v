module axis32_to_block128 #(
    parameter AXIS_DATA_WIDTH = 32,
    parameter DEPTH = 4  // 4x128b ibuf
) (
    input wire clk,
    input wire rst_n,

    // AXI-Stream slave (32-bit)
    input  wire [31:0] s_axis_tdata,
    input  wire        s_axis_tvalid,
    output wire        s_axis_tready,
    input  wire        s_axis_tlast,

    // 128-bit block output (peek + pop)
    output wire [127:0] m_block_data,
    output wire         m_block_valid,
    input  wire         m_block_pop,    // assert 1T at "block end" to pop head

    // status
    output wire ibuf_full,
    output wire ibuf_empty
);

  // ----------------------------
  // FIFO: DEPTH x 128
  // ----------------------------
  reg [127:0] mem[0:DEPTH-1];
  reg [1:0] wr_ptr, rd_ptr;  // DEPTH=4 -> 2 bits
  reg [2:0] count;  // 0..4

  assign ibuf_full = (count == DEPTH[2:0]);
  assign ibuf_empty = (count == 3'd0);


  // peek head (stable as long as rd_ptr not advanced)
  assign m_block_data = mem[rd_ptr];
  assign m_block_valid = !ibuf_empty;

  // ----------------------------
  // 4-beat packer (32 -> 128)
  // ----------------------------
  reg         assembling;
  reg [  1:0] beat_cnt;
  reg [127:0] assemble_reg;

  // allow starting a new 4-beat group only if fifo not full
  // once started, keep ready high to finish the 4 beats
  assign s_axis_tready = assembling ? 1'b1 : !ibuf_full;

  wire axis_hs = s_axis_tvalid && s_axis_tready;

  wire [31:0] w_swapped = {s_axis_tdata[7:0], s_axis_tdata[15:8], s_axis_tdata[23:16], s_axis_tdata[31:24]};


  // combinational "insert current beat"
  reg [127:0] assemble_next;
  always @(*) begin
    assemble_next = assemble_reg;
    case (beat_cnt)
      2'd0: assemble_next[127:96] = w_swapped;
      2'd1: assemble_next[95:64] = w_swapped;
      2'd2: assemble_next[63:32] = w_swapped;
      2'd3: assemble_next[31:0] = w_swapped;
    endcase
  end

  // write one 128b into FIFO when beat_cnt==3 handshake
  wire push_128 = axis_hs && (beat_cnt == 2'd3);

  // pop head when flowctrl says so (typically at AES block end)
  wire pop_128 = m_block_pop && m_block_valid;

  integer i;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      wr_ptr       <= 2'd0;
      rd_ptr       <= 2'd0;
      count        <= 3'd0;
      assembling   <= 1'b0;
      beat_cnt     <= 2'd0;
      assemble_reg <= 128'd0;
    end else begin
      // ---- packer state ----
      if (!assembling) begin
        if (axis_hs) begin
          assembling   <= 1'b1;
          beat_cnt     <= 2'd1;  // accepted beat0
          assemble_reg <= assemble_next;
        end
      end else begin
        if (axis_hs) begin
          assemble_reg <= assemble_next;
          if (beat_cnt == 2'd3) begin
            assembling <= 1'b0;
            beat_cnt   <= 2'd0;
          end else begin
            beat_cnt <= beat_cnt + 2'd1;
          end
        end
      end

      // ---- FIFO write (on completed 128b) ----
      if (push_128) begin
        mem[wr_ptr] <= assemble_next;
        wr_ptr <= (wr_ptr == (DEPTH - 1)) ? 2'd0 : (wr_ptr + 2'd1);
      end

      // ---- FIFO pop ----
      if (pop_128) begin
        rd_ptr <= (rd_ptr == (DEPTH - 1)) ? 2'd0 : (rd_ptr + 2'd1);
      end

      // ---- count update (handle push/pop same cycle) ----
      case ({
        push_128, pop_128
      })
        2'b10:   count <= count + 3'd1;
        2'b01:   count <= count - 3'd1;
        default: count <= count;
      endcase

    end
  end

endmodule
