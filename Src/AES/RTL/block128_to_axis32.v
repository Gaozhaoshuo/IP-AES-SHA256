module block128_to_axis32 #(
    parameter integer DEPTH = 4  // spec: 4x128b obuf
) (
    input wire clk,
    input wire rst_n,

    // 128-bit block input (write into obuf)
    input  wire [127:0] s_block_data,
    input  wire         s_block_valid,
    output wire         s_block_ready,

    // AXI-Stream master (32-bit)
    output wire [31:0] m_axis_tdata,
    output wire        m_axis_tvalid,
    input  wire        m_axis_tready,
    output wire        m_axis_tlast,

    // status
    output wire obuf_full,
    output wire obuf_empty
);

  // ----------------------------
  // small FIFO: DEPTH x 128
  // ----------------------------
  reg [127:0] mem[0:DEPTH-1];
  reg [1:0] wr_ptr, rd_ptr;
  reg [2:0] count;

  assign obuf_full = (count == DEPTH[2:0]);
  assign obuf_empty = (count == 3'd0);

  // write side handshake
  assign s_block_ready = !obuf_full;
  wire         push_128 = s_block_valid && s_block_ready;

  // ----------------------------
  // stream out 4 beats
  // ----------------------------
  reg          sending;
  reg  [  1:0] beat_idx;
  reg  [127:0] out_reg;

  // when idle and FIFO not empty, preload one block (do NOT pop yet)
  wire         can_load = (!sending) && (!obuf_empty);

  // AXIS outputs
  assign m_axis_tvalid = sending;
  assign m_axis_tlast  = sending && (beat_idx == 2'd3);

  reg [31:0] raw_word;
  always @(*) begin
    case (beat_idx)
      2'd0: raw_word = out_reg[127:96];
      2'd1: raw_word = out_reg[95:64];
      2'd2: raw_word = out_reg[63:32];
      2'd3: raw_word = out_reg[31:0];
    endcase
  end

  assign m_axis_tdata = {raw_word[7:0], raw_word[15:8], raw_word[23:16], raw_word[31:24]};



  wire axis_hs = m_axis_tvalid && m_axis_tready;
  wire done_4 = axis_hs && (beat_idx == 2'd3);

  // pop FIFO at the END of 4 beats (so you也能做到“读取期间保持同一块数据”)
  wire pop_128 = done_4;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      wr_ptr   <= 2'd0;
      rd_ptr   <= 2'd0;
      count    <= 3'd0;
      sending  <= 1'b0;
      beat_idx <= 2'd0;
      out_reg  <= 128'd0;
    end else begin
      // ---- FIFO push ----
      if (push_128) begin
        mem[wr_ptr] <= s_block_data;
        wr_ptr <= (wr_ptr == (DEPTH - 1)) ? 2'd0 : (wr_ptr + 2'd1);
      end

      // ---- load to out_reg when idle ----
      if (can_load) begin
        out_reg  <= mem[rd_ptr];
        sending  <= 1'b1;
        beat_idx <= 2'd0;
      end else if (sending && axis_hs) begin
        if (beat_idx == 2'd3) begin
          // finished one 128b
          if ((count - (pop_128 ? 3'd1 : 3'd0)) != 3'd0) begin
            // next cycle will reload via can_load (simple & safe)
            sending  <= 1'b0;
            beat_idx <= 2'd0;
          end else begin
            sending  <= 1'b0;
            beat_idx <= 2'd0;
          end
        end else begin
          beat_idx <= beat_idx + 2'd1;
        end
      end

      // ---- FIFO pop (end of 4 beats) ----
      if (pop_128) begin
        rd_ptr <= (rd_ptr == (DEPTH - 1)) ? 2'd0 : (rd_ptr + 2'd1);
      end

      // ---- count update (push/pop same cycle) ----
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

