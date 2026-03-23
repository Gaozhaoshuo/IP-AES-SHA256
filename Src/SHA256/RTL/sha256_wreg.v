
// ============================================================
// Message schedule Wt generator with 16-word sliding window.
// - For round 0..15: Wt = input word
// - For round 16..63: Wt = s1(W[t-2]) + W[t-7] + s0(W[t-15]) + W[t-16]
// ============================================================
module sha256_wreg (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        step_en,
    input  wire [5:0]  round_idx,
    input  wire [31:0] in_word,
    output wire [31:0] Wt
);
  function [31:0] rotr32;
    input [31:0] x;
    input [4:0]  n;
    begin
      if (n == 0) rotr32 = x;
      else        rotr32 = (x >> n) | (x << (32 - n));
    end
  endfunction

  function [31:0] sigma0;
    input [31:0] x;
    begin
      sigma0 = rotr32(x, 5'd7) ^ rotr32(x, 5'd18) ^ (x >> 3);
    end
  endfunction

  function [31:0] sigma1;
    input [31:0] x;
    begin
      sigma1 = rotr32(x, 5'd17) ^ rotr32(x, 5'd19) ^ (x >> 10);
    end
  endfunction

  reg [31:0] wreg[0:15];
  integer i;

  wire [31:0] wt_16 = wreg[0];   // W[t-16]
  wire [31:0] wt_15 = wreg[1];   // W[t-15]
  wire [31:0] wt_7  = wreg[9];   // W[t-7]
  wire [31:0] wt_2  = wreg[14];  // W[t-2]

  wire [31:0] wt_calc = (round_idx < 6'd16) ? in_word :
                        (sigma1(wt_2) + wt_7 + sigma0(wt_15) + wt_16);

  assign Wt = wt_calc;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (i = 0; i < 16; i = i + 1) begin
        wreg[i] <= 32'h0;
      end
    end else if (step_en) begin
      for (i = 0; i < 15; i = i + 1) begin
        wreg[i] <= wreg[i+1];
      end
      wreg[15] <= wt_calc;
    end
  end
endmodule