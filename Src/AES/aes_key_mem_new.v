module aes_key_mem (

    input wire clk,
    input wire rst_n,

    input wire         key_gen,
    input wire [  1:0] key_len,  //0:128b; 2:256b
    input wire [255:0] key_in,

    output wire key_ready,

    output wire [31:0] sbox_word,
    input  wire [31:0] new_sbox_word,

    input  wire [  3:0] round_idx,
    output wire [127:0] round_key
);

  localparam IDLE = 2'd0;
  localparam INIT = 2'd1;
  localparam GEN = 2'd2;
  localparam DONE = 2'd3;

  localparam NK_128 = 6'd4;
  localparam NK_256 = 6'd8;

  reg [1:0] key_len_reg, key_len_next;
  reg [1:0] state_reg, state_next;

  reg [31:0] sbox_word_reg;
  assign sbox_word = sbox_word_reg;


  reg [31:0] key_word_mem_reg[0:59], key_word_mem_next[0:59];
  reg [5:0] i_reg, i_next;
  reg [3:0] rcon_idx_reg, rcon_idx_next;

  assign round_key = {
    key_word_mem_reg[round_idx*4+0],
    key_word_mem_reg[round_idx*4+1],
    key_word_mem_reg[round_idx*4+2],
    key_word_mem_reg[round_idx*4+3]
  };

  wire is_aes256 = (key_len_reg == 2'd2);
  wire ks_mod4_eq0 = (i_reg[1:0] == 2'b00);
  wire ks_mod8_eq0 = (i_reg[2:0] == 3'b000);

  // 情况1：i % Nk == 0
  wire ks_br_rcon = is_aes256 ? ks_mod8_eq0 : ks_mod4_eq0;
  // 情况2：AES-256 且 i % Nk != 0 且 i % 4 == 0
  wire ks_br_sub = is_aes256 && ks_mod4_eq0 && ~ks_mod8_eq0;
  // 情况3：其他
  wire ks_br_xor = ~(ks_br_rcon | ks_br_sub);

  wire ks_last_word = is_aes256 ? (i_reg == 6'd59) : (i_reg == 6'd43);


  wire [5:0] imNk = is_aes256 ? (i_reg - NK_256) : (i_reg - NK_128);
  wire [5:0] im1 = i_reg - 6'd1;
  reg ready_reg;

  assign key_ready = ready_reg;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      ready_reg <= 1'b0;
    end else begin
      // 新一轮 key expansion 开始时清零
      if (state_reg == IDLE && key_gen) ready_reg <= 1'b0;
      // 生成结束后置 1，并保持
      else if (state_reg == DONE) ready_reg <= 1'b1;
    end
  end

  function [31:0] ks_rot_word;
    input [31:0] w;
    begin
      ks_rot_word = {w[23:0], w[31:24]};
    end
  endfunction

  function [31:0] ks_xor_rcon;
    input [31:0] w;
    input [7:0] rcon;
    begin
      ks_xor_rcon = w ^ {rcon, 24'h0};
    end
  endfunction

  // 情况1：i % Nk == 0
  // w[i] = w[i-Nk] ^ (SubWord(RotWord(w[i-1])) ^ Rcon)
  function [31:0] ks_word_rcon;
    input [31:0] w_imNk;
    input [31:0] sub_rot;  // = SubWord(RotWord(w_im1))
    input [7:0] rcon;
    begin
      ks_word_rcon = w_imNk ^ ks_xor_rcon(sub_rot, rcon);
    end
  endfunction

  // 情况2：仅AES-256，且 i % Nk !=0 且 i % 4 == 0
  // w[i] = w[i-Nk] ^ SubWord(w[i-1])
  function [31:0] ks_word_sub;
    input [31:0] w_imNk;
    input [31:0] sub_w;  // = SubWord(w_im1)
    begin
      ks_word_sub = w_imNk ^ sub_w;
    end
  endfunction

  // 情况3：其他
  // w[i] = w[i-Nk] ^ w[i-1]
  function [31:0] ks_word_xor;
    input [31:0] w_imNk;
    input [31:0] w_im1;
    begin
      ks_word_xor = w_imNk ^ w_im1;
    end
  endfunction

  function [7:0] rcon_lut;
    input [3:0] idx;  // idx=0 -> 8'h01
    begin
      case (idx)
        4'd0: rcon_lut = 8'h01;
        4'd1: rcon_lut = 8'h02;
        4'd2: rcon_lut = 8'h04;
        4'd3: rcon_lut = 8'h08;
        4'd4: rcon_lut = 8'h10;
        4'd5: rcon_lut = 8'h20;
        4'd6: rcon_lut = 8'h40;
        4'd7: rcon_lut = 8'h80;
        4'd8: rcon_lut = 8'h1B;
        4'd9: rcon_lut = 8'h36;
        default: rcon_lut = 8'h00;  // 超出不用
      endcase
    end
  endfunction

  integer i, k;
  always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      state_reg <= IDLE;
      i_reg <= 'd0;
      rcon_idx_reg <= 4'd0;
      key_len_reg <= 2'd0;
      for (k = 0; k < 60; k = k + 1) begin
        key_word_mem_reg[k] <= 32'd0;
      end
    end else begin
      state_reg <= state_next;
      i_reg <= i_next;
      rcon_idx_reg <= rcon_idx_next;
      key_len_reg <= key_len_next;
      for (k = 0; k < 60; k = k + 1) begin
        key_word_mem_reg[k] <= key_word_mem_next[k];
      end
    end
  end

  always @(*) begin
    state_next = state_reg;
    i_next = i_reg;
    rcon_idx_next = rcon_idx_reg;
    key_len_next = key_len_reg;
    sbox_word_reg = 32'd0;
    for (i = 0; i < 60; i = i + 1) begin
      key_word_mem_next[i] = key_word_mem_reg[i];
    end
    case (state_reg)
      IDLE: begin
        state_next    = key_gen ? INIT : IDLE;
        key_len_next  = key_len;
        i_next        = 6'd0;
        rcon_idx_next = 4'd0;
      end
      INIT: begin
        if (is_aes256) begin
          key_word_mem_next[0] = key_in[255:224];
          key_word_mem_next[1] = key_in[223:192];
          key_word_mem_next[2] = key_in[191:160];
          key_word_mem_next[3] = key_in[159:128];
          key_word_mem_next[4] = key_in[127:96];
          key_word_mem_next[5] = key_in[95:64];
          key_word_mem_next[6] = key_in[63:32];
          key_word_mem_next[7] = key_in[31:0];
          i_next = NK_256;
        end else begin
          key_word_mem_next[0] = key_in[255:224];
          key_word_mem_next[1] = key_in[223:192];
          key_word_mem_next[2] = key_in[191:160];
          key_word_mem_next[3] = key_in[159:128];
          i_next = NK_128;
        end
        state_next = GEN;
        i_next = is_aes256 ? NK_256 : NK_128;
        state_next = GEN;
      end
      GEN: begin
        if (ks_br_rcon) begin
          sbox_word_reg = ks_rot_word(key_word_mem_reg[im1]);
          key_word_mem_next[i_reg] = ks_word_rcon(key_word_mem_reg[imNk], new_sbox_word, rcon_lut(rcon_idx_reg));
          i_next = i_reg + 1;
          rcon_idx_next = rcon_idx_reg + 4'd1;
          state_next = GEN;
        end else if (ks_br_sub) begin
          sbox_word_reg = key_word_mem_reg[im1];
          key_word_mem_next[i_reg] = ks_word_sub(key_word_mem_reg[imNk], new_sbox_word);
          i_next = i_reg + 1;
          state_next = GEN;
        end else begin
          key_word_mem_next[i_reg] = ks_word_xor(key_word_mem_reg[imNk], key_word_mem_reg[im1]);
          i_next = i_reg + 1;
          state_next = ks_last_word ? DONE : GEN;
        end
      end
      DONE: begin
        state_next = IDLE;
      end
    endcase
  end
endmodule

