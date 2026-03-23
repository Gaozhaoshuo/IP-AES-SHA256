module aes_encipher (
    input wire clk,
    input wire rst_n,

    input  wire           enc_next,       //1T pulse start a 128b blk encrypt
    input  wire [    1:0] key_len,        //0:128b, 2:256b
    output wire [  3 : 0] enc_round_idx,  //round cnt
    input  wire [127 : 0] enc_round_key,  //{b0, b1, ..., b15}

    output wire [127 : 0] sbox,     //subbyte input
    input  wire [127 : 0] new_sbox, //subbyte output

    input  wire [127 : 0] enc_block,      //{b0, b1, ..., b15}
    output wire [127 : 0] new_enc_block,  //{b0, b1, ..., b15}
    output wire           enc_ready       //high level, a 128bit enc_block ended
);

  localparam IDLE = 2'd0;
  localparam INIT = 2'd1;
  localparam MAIN = 2'd2;

  reg [127:0] new_enc_block_reg, new_enc_block_next;
  reg [1:0] state_reg, state_next;
  reg [3:0] enc_round_idx_reg, enc_round_idx_next;
  reg [3:0] total_rounds_reg, total_rounds_next;
  reg enc_ready_reg, enc_ready_next;

  assign enc_round_idx = enc_round_idx_reg;
  assign sbox = new_enc_block_reg;
  assign new_enc_block = new_enc_block_reg;
  assign enc_ready = enc_ready_reg;

  // 输入 s = {b0,b1,...,b15} 对应 S0..S15
  // 输出按 AES ShiftRows：
  // row0: S0 S4 S8  S12   -> 不变
  // row1: S1 S5 S9  S13   -> 左移1 => S5 S9 S13 S1
  // row2: S2 S6 S10 S14   -> 左移2 => S10 S14 S2 S6
  // row3: S3 S7 S11 S15   -> 左移3 => S15 S3 S7 S11
  function [127:0] aes_shiftrows;
    input [127:0] s;
    begin
      aes_shiftrows = {
        s[127:120],  // out b0  = in b0  (S0)
        s[87:80],  // out b1  = in b5  (S5)
        s[47:40],  // out b2  = in b10 (S10)
        s[7:0],  // out b3  = in b15 (S15)

        s[95:88],  // out b4  = in b4  (S4)
        s[55:48],  // out b5  = in b9  (S9)
        s[15:8],  // out b6  = in b14 (S14)
        s[103:96],  // out b7  = in b3  (S3)

        s[63:56],  // out b8  = in b8  (S8)
        s[23:16],  // out b9  = in b13 (S13)
        s[111:104],  // out b10 = in b2  (S2)
        s[71:64],  // out b11 = in b7  (S7)

        s[31:24],  // out b12 = in b12 (S12)
        s[119:112],  // out b13 = in b1  (S1)
        s[79:72],  // out b14 = in b6  (S6)
        s[39:32]  // out b15 = in b11 (S11)
      };
    end
  endfunction

  // GF(2^8) 乘2：xtime(a) = (a<<1) ^ (0x1b if a[7]==1)
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

  function [7:0] aes_mul3;
    input [7:0] a;
    begin
      aes_mul3 = aes_xtime(a) ^ a;
    end
  endfunction

  // MixColumns: 对每一列做矩阵乘法（02 03 01 01 ...）
  function [127:0] aes_mixcolumns;
    input [127:0] s;  // {b0..b15}
    reg [7:0] s0, s1, s2, s3, s4, s5, s6, s7, s8, s9, s10, s11, s12, s13, s14, s15;
    reg [7:0] o0, o1, o2, o3, o4, o5, o6, o7, o8, o9, o10, o11, o12, o13, o14, o15;
    begin
      // unpack
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
      o0 = aes_mul2(s0) ^ aes_mul3(s1) ^ s2 ^ s3;
      o1 = s0 ^ aes_mul2(s1) ^ aes_mul3(s2) ^ s3;
      o2 = s0 ^ s1 ^ aes_mul2(s2) ^ aes_mul3(s3);
      o3 = aes_mul3(s0) ^ s1 ^ s2 ^ aes_mul2(s3);

      // col1: (s4,s5,s6,s7)
      o4 = aes_mul2(s4) ^ aes_mul3(s5) ^ s6 ^ s7;
      o5 = s4 ^ aes_mul2(s5) ^ aes_mul3(s6) ^ s7;
      o6 = s4 ^ s5 ^ aes_mul2(s6) ^ aes_mul3(s7);
      o7 = aes_mul3(s4) ^ s5 ^ s6 ^ aes_mul2(s7);

      // col2: (s8,s9,s10,s11)
      o8 = aes_mul2(s8) ^ aes_mul3(s9) ^ s10 ^ s11;
      o9 = s8 ^ aes_mul2(s9) ^ aes_mul3(s10) ^ s11;
      o10 = s8 ^ s9 ^ aes_mul2(s10) ^ aes_mul3(s11);
      o11 = aes_mul3(s8) ^ s9 ^ s10 ^ aes_mul2(s11);

      // col3: (s12,s13,s14,s15)
      o12 = aes_mul2(s12) ^ aes_mul3(s13) ^ s14 ^ s15;
      o13 = s12 ^ aes_mul2(s13) ^ aes_mul3(s14) ^ s15;
      o14 = s12 ^ s13 ^ aes_mul2(s14) ^ aes_mul3(s15);
      o15 = aes_mul3(s12) ^ s13 ^ s14 ^ aes_mul2(s15);

      // pack
      aes_mixcolumns = {o0, o1, o2, o3, o4, o5, o6, o7, o8, o9, o10, o11, o12, o13, o14, o15};
    end
  endfunction

  // AddRoundKey: state ^ enc_round_key
  // 约定：state = {b0,b1,...,b15}, enc_round_key = {b0,b1,...,b15}
  function [127:0] aes_addroundkey;
    input [127:0] state;
    input [127:0] rkey;
    begin
      aes_addroundkey = state ^ rkey;
    end
  endfunction

  integer i;

  always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      state_reg <= IDLE;
      total_rounds_reg <= 4'd0;
      enc_round_idx_reg <= 4'd0;
      new_enc_block_reg <= 128'd0;
      enc_ready_reg <= 1'b0;
    end else begin
      state_reg <= state_next;
      total_rounds_reg <= total_rounds_next;
      enc_round_idx_reg <= enc_round_idx_next;
      new_enc_block_reg <= new_enc_block_next;
      enc_ready_reg <= enc_ready_next;
    end
  end

  always @(*) begin
    state_next = state_reg;
    total_rounds_next = total_rounds_reg;
    enc_round_idx_next = enc_round_idx_reg;
    new_enc_block_next = new_enc_block_reg;
    enc_ready_next = enc_ready_reg & ~enc_next;
    case (state_reg)
      IDLE: begin
        if (enc_next) begin
          state_next = INIT;
          total_rounds_next = (key_len == 2'd2) ? 4'd14 : 4'd10;
          new_enc_block_next = enc_block;
        end else begin
          state_next = IDLE;
        end
        enc_round_idx_next = 4'd0;
      end
      INIT: begin
        new_enc_block_next = aes_addroundkey(new_enc_block_reg, enc_round_key);
        enc_round_idx_next = 4'd1;
        state_next = MAIN;
      end
      MAIN: begin
        if (enc_round_idx_reg == total_rounds_reg) begin
          new_enc_block_next = aes_addroundkey(aes_shiftrows(new_sbox), enc_round_key);
          enc_round_idx_next = 4'd0;
          state_next = IDLE;
          enc_ready_next = 1'b1;
        end else begin
          new_enc_block_next = aes_addroundkey(aes_mixcolumns(aes_shiftrows(new_sbox)), enc_round_key);
          enc_round_idx_next = enc_round_idx_reg + 4'd1;
          state_next = MAIN;
        end
      end
    endcase
  end

endmodule