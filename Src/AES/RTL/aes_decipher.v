module aes_decipher (
    input wire clk,
    input wire rst_n,

    input  wire           dec_next,       //1T pulse start a 128b blk decrypt
    input  wire [    1:0] key_len,        //0:128b, 2:256b
    output wire [  3 : 0] dec_round_idx,  //round cnt
    input  wire [127 : 0] dec_round_key,  //{b0, b1, ..., b15}

    input  wire [127 : 0] dec_block,      //{b0, b1, ..., b15}
    output wire [127 : 0] new_dec_block,  //{b0, b1, ..., b15}
    output wire           dec_ready       //high level, a 128bit dec_block ended
);

  localparam IDLE = 2'd0;
  localparam INIT = 2'd1;
  localparam MAIN = 2'd2;

  wire [127:0] new_inv_sbox, inv_sbox;

  reg [127:0] new_dec_block_reg, new_dec_block_next;
  reg [1:0] state_reg, state_next;
  reg [3:0] dec_round_idx_reg, dec_round_idx_next;
  reg [3:0] total_rounds_reg, total_rounds_next;
  reg dec_ready_reg, dec_ready_next;

  assign dec_round_idx = dec_round_idx_reg;
  assign new_dec_block = new_dec_block_reg;
  assign dec_ready = dec_ready_reg;
  // -----------------------------
  // InvShiftRows
  // 输入 s = {b0,b1,...,b15} 对应 S0..S15
  // 逆行位移：row1 右移1；row2 右移2；row3 右移3
  // -----------------------------
  function [127:0] aes_inv_shiftrows;
    input [127:0] s;
    begin
      aes_inv_shiftrows = {
        s[127:120],  // out b0  = in b0   (S0)
        s[23:16],  // out b1  = in b13  (S13)
        s[47:40],  // out b2  = in b10  (S10)
        s[71:64],  // out b3  = in b7   (S7)

        s[95:88],  // out b4  = in b4   (S4)
        s[119:112],  // out b5  = in b1   (S1)
        s[15:8],  // out b6  = in b14  (S14)
        s[39:32],  // out b7  = in b11  (S11)

        s[63:56],  // out b8  = in b8   (S8)
        s[87:80],  // out b9  = in b5   (S5)
        s[111:104],  // out b10 = in b2   (S2)
        s[7:0],  // out b11 = in b15  (S15)

        s[31:24],  // out b12 = in b12  (S12)
        s[55:48],  // out b13 = in b9   (S9)
        s[79:72],  // out b14 = in b6   (S6)
        s[103:96]  // out b15 = in b3   (S3)
      };
    end
  endfunction

  function [7:0] aes_xtime;
    input [7:0] a;
    begin
      aes_xtime = {a[6:0], 1'b0} ^ (8'h1b & {8{a[7]}});
    end
  endfunction

  function [7:0] aes_mul2;
    input [7:0] a;
    begin
      aes_mul2 = aes_xtime(a);
    end
  endfunction

  function [7:0] aes_mul4;
    input [7:0] a;
    begin
      aes_mul4 = aes_xtime(aes_xtime(a));
    end
  endfunction

  function [7:0] aes_mul8;
    input [7:0] a;
    begin
      aes_mul8 = aes_xtime(aes_xtime(aes_xtime(a)));
    end
  endfunction

  function [7:0] aes_mul9;
    input [7:0] a;
    begin
      aes_mul9 = aes_mul8(a) ^ a;  // 8a + a
    end
  endfunction

  function [7:0] aes_mul11;
    input [7:0] a;
    begin
      aes_mul11 = aes_mul8(a) ^ aes_mul2(a) ^ a;  // 8a + 2a + a
    end
  endfunction

  function [7:0] aes_mul13;
    input [7:0] a;
    begin
      aes_mul13 = aes_mul8(a) ^ aes_mul4(a) ^ a;  // 8a + 4a + a
    end
  endfunction

  function [7:0] aes_mul14;
    input [7:0] a;
    begin
      aes_mul14 = aes_mul8(a) ^ aes_mul4(a) ^ aes_mul2(a);  // 8a + 4a + 2a
    end
  endfunction

  // -----------------------------
  // InvMixColumns
  // 对每列做逆矩阵乘法：
  // [0e 0b 0d 09;
  //  09 0e 0b 0d;
  //  0d 09 0e 0b;
  //  0b 0d 09 0e]
  // -----------------------------
  function [127:0] aes_inv_mixcolumns;
    input [127:0] s;  // {b0..b15}
    reg [7:0] s0, s1, s2, s3, s4, s5, s6, s7, s8, s9, s10, s11, s12, s13, s14, s15;
    reg [7:0] o0, o1, o2, o3, o4, o5, o6, o7, o8, o9, o10, o11, o12, o13, o14, o15;
    begin
      // unpack（与你的 aes_mixcolumns 完全一致的字节拆包方式）
      s0 = s[127:120];
      s1 = s[119:112];
      s2 = s[111:104];
      s3 = s[103:96];
      s4 = s[95:88];
      s5 = s[87:80];
      s6 = s[79:72];
      s7 = s[71:64];
      s8 = s[63:56];
      s9 = s[55:48];
      s10 = s[47:40];
      s11 = s[39:32];
      s12 = s[31:24];
      s13 = s[23:16];
      s14 = s[15:8];
      s15 = s[7:0];

      // col0: (s0,s1,s2,s3) -> (o0,o1,o2,o3)
      o0 = aes_mul14(s0) ^ aes_mul11(s1) ^ aes_mul13(s2) ^ aes_mul9(s3);
      o1 = aes_mul9(s0) ^ aes_mul14(s1) ^ aes_mul11(s2) ^ aes_mul13(s3);
      o2 = aes_mul13(s0) ^ aes_mul9(s1) ^ aes_mul14(s2) ^ aes_mul11(s3);
      o3 = aes_mul11(s0) ^ aes_mul13(s1) ^ aes_mul9(s2) ^ aes_mul14(s3);

      // col1: (s4,s5,s6,s7)
      o4 = aes_mul14(s4) ^ aes_mul11(s5) ^ aes_mul13(s6) ^ aes_mul9(s7);
      o5 = aes_mul9(s4) ^ aes_mul14(s5) ^ aes_mul11(s6) ^ aes_mul13(s7);
      o6 = aes_mul13(s4) ^ aes_mul9(s5) ^ aes_mul14(s6) ^ aes_mul11(s7);
      o7 = aes_mul11(s4) ^ aes_mul13(s5) ^ aes_mul9(s6) ^ aes_mul14(s7);

      // col2: (s8,s9,s10,s11)
      o8 = aes_mul14(s8) ^ aes_mul11(s9) ^ aes_mul13(s10) ^ aes_mul9(s11);
      o9 = aes_mul9(s8) ^ aes_mul14(s9) ^ aes_mul11(s10) ^ aes_mul13(s11);
      o10 = aes_mul13(s8) ^ aes_mul9(s9) ^ aes_mul14(s10) ^ aes_mul11(s11);
      o11 = aes_mul11(s8) ^ aes_mul13(s9) ^ aes_mul9(s10) ^ aes_mul14(s11);

      // col3: (s12,s13,s14,s15)
      o12 = aes_mul14(s12) ^ aes_mul11(s13) ^ aes_mul13(s14) ^ aes_mul9(s15);
      o13 = aes_mul9(s12) ^ aes_mul14(s13) ^ aes_mul11(s14) ^ aes_mul13(s15);
      o14 = aes_mul13(s12) ^ aes_mul9(s13) ^ aes_mul14(s14) ^ aes_mul11(s15);
      o15 = aes_mul11(s12) ^ aes_mul13(s13) ^ aes_mul9(s14) ^ aes_mul14(s15);

      // pack
      aes_inv_mixcolumns = {o0, o1, o2, o3, o4, o5, o6, o7, o8, o9, o10, o11, o12, o13, o14, o15};
    end
  endfunction

  // -----------------------------
  // AddRoundKey: state ^ round_key
  // 约定保持一致：state = {b0..b15}, rkey = {b0..b15}
  // -----------------------------
  function [127:0] aes_addroundkey;
    input [127:0] state;
    input [127:0] rkey;
    begin
      aes_addroundkey = state ^ rkey;
    end
  endfunction

  aes_inv_sbox_lut u_aes_inv_sbox_lut (
      .sboxw    (inv_sbox),
      .new_sboxw(new_inv_sbox)
  );

  integer i;

  always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      state_reg <= IDLE;
      total_rounds_reg <= 4'd0;
      dec_round_idx_reg <= 4'd0;
      new_dec_block_reg <= 128'd0;
      dec_ready_reg <= 1'b0;
    end else begin
      state_reg <= state_next;
      total_rounds_reg <= total_rounds_next;
      dec_round_idx_reg <= dec_round_idx_next;
      new_dec_block_reg <= new_dec_block_next;
      dec_ready_reg <= dec_ready_next;
    end
  end

  assign inv_sbox = aes_inv_shiftrows(new_dec_block_reg);

  always @(*) begin
    state_next = state_reg;
    total_rounds_next = total_rounds_reg;
    dec_round_idx_next = dec_round_idx_reg;
    new_dec_block_next = new_dec_block_reg;
    dec_ready_next = dec_ready_reg & ~dec_next;
    case (state_reg)
      IDLE: begin
        if (dec_next) begin
          state_next = INIT;
          total_rounds_next = (key_len == 2'd2) ? 4'd14 : 4'd10;
          new_dec_block_next = dec_block;
          dec_round_idx_next = total_rounds_next;
        end else begin
          state_next = IDLE;
          dec_round_idx_next = 4'd0;
        end

      end
      INIT: begin
        new_dec_block_next = aes_addroundkey(new_dec_block_reg, dec_round_key);
        dec_round_idx_next = dec_round_idx_reg - 4'd1;
        state_next = MAIN;
      end
      MAIN: begin
        if (dec_round_idx_reg == 4'd0) begin
          new_dec_block_next = aes_addroundkey(new_inv_sbox, dec_round_key);
          dec_round_idx_next = 4'd0;
          state_next         = IDLE;
          dec_ready_next     = 1'b1;
        end else begin
          new_dec_block_next = aes_inv_mixcolumns(aes_addroundkey(new_inv_sbox, dec_round_key));
          dec_round_idx_next = dec_round_idx_reg - 4'd1;
          state_next         = MAIN;
        end
      end
    endcase
  end

endmodule
