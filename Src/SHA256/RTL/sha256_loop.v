// ============================================================
// SHA-256 round loop (working variables a..h)
// ============================================================
module sha256_loop (
    input  wire         clk,
    input  wire         rst_n,
    input  wire         init_en,
    input  wire         step_en,
    input  wire [ 31:0] Wt_in,
    input  wire [ 31:0] Kt_in,
    input  wire [255:0] H_in,
    output wire [255:0] work_out
);
  reg [31:0] a, b, c, d, e, f, g, h;

  function [31:0] rotr32;
    input [31:0] x;
    input [4:0] n;
    begin
      if (n == 0) rotr32 = x;
      else rotr32 = (x >> n) | (x << (32 - n));
    end
  endfunction

  function [31:0] SIGMA0;
    input [31:0] x;
    begin
      SIGMA0 = rotr32(x, 5'd2) ^ rotr32(x, 5'd13) ^ rotr32(x, 5'd22);
    end
  endfunction

  function [31:0] SIGMA1;
    input [31:0] x;
    begin
      SIGMA1 = rotr32(x, 5'd6) ^ rotr32(x, 5'd11) ^ rotr32(x, 5'd25);
    end
  endfunction

  function [31:0] Ch;
    input [31:0] x;
    input [31:0] y;
    input [31:0] z;
    begin
      Ch = (x & y) ^ (~x & z);
    end
  endfunction

  function [31:0] Maj;
    input [31:0] x;
    input [31:0] y;
    input [31:0] z;
    begin
      Maj = (x & y) ^ (x & z) ^ (y & z);
    end
  endfunction

  wire [31:0] sumE = SIGMA1(e);
  wire [31:0] tmp_Ch_sumE = Ch(e, f, g) + sumE;

  wire [31:0] tmp_K_W = Kt_in + Wt_in;
  wire [31:0] tmp_H_K_W = h + tmp_K_W;

  wire [31:0] t1 = tmp_H_K_W + tmp_Ch_sumE;

  wire [31:0] sumA = SIGMA0(a);
  wire [31:0] t2 = sumA + Maj(a, b, c);

  wire [31:0] newA = t1 + t2;
  wire [31:0] newE = d + t1;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      a <= 32'h0;
      b <= 32'h0;
      c <= 32'h0;
      d <= 32'h0;
      e <= 32'h0;
      f <= 32'h0;
      g <= 32'h0;
      h <= 32'h0;
    end else if (init_en) begin
      a <= H_in[255:224];
      b <= H_in[223:192];
      c <= H_in[191:160];
      d <= H_in[159:128];
      e <= H_in[127:96];
      f <= H_in[95:64];
      g <= H_in[63:32];
      h <= H_in[31:0];
    end else if (step_en) begin
      h <= g;
      g <= f;
      f <= e;
      e <= newE;
      d <= c;
      c <= b;
      b <= a;
      a <= newA;
    end else begin
      a <= a;
      b <= b;
      c <= c;
      d <= d;
      e <= e;
      f <= f;
      g <= g;
      h <= h;
    end
  end

  assign work_out = {a, b, c, d, e, f, g, h};
endmodule