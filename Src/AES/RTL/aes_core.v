module aes_core (
    input wire clk,
    input wire rst_n,

    input  wire           encdec,       //1:enc, 0:dec
    input  wire [  127:0] iv,           //initial vector
    input  wire           init,         //1T pulse start the generation of round key
    input  wire           next,         //1T pulse start the encipher or decipher, must wait for key_ready=1
    input  wire           first_blk,    //high level: first blk of a bulk data
    input  wire [    1:0] blk_mode,     //0:ECB; 1:CBC
    output wire           key_ready,    //high level: generation of round key ended
    input  wire [255 : 0] key_in,       //input 128/256bit key
    input  wire [    1:0] key_len,      //0:128b, 2:256b
    input  wire [127 : 0] block,        //keep valid between the time : next=1 to blk_end=1
    output wire [127 : 0] result,       //encipher/decipher result
    output wire           result_valid  //high level: encipher/deciper result valid
);

  wire [3:0] muxed_round_idx;
  wire [31:0] sbox_word;
  wire [127:0] round_key;
  wire [3 : 0] enc_round_idx;
  wire [3 : 0] dec_round_idx;
  wire [127 : 0] enc_sbox;
  wire [127 : 0] new_sbox;
  wire enc_next;
  wire dec_next;
  wire [127:0] new_enc_block;
  wire [127:0] new_dec_block;
  wire enc_ready;
  wire dec_ready;
  reg [127:0] enc_block;
  reg [127:0] dec_block;
  reg init_state_reg;
  reg [255:0] dec_prev_cipher;
  reg [127:0] enc_prev_cipher;
  reg [127:0] result_reg, result_next;
  reg result_valid_reg, result_valid_next;
  reg  first_blk_dec_reg;
  wire posedge_enc_ready;
  wire posedge_dec_ready;

  assign result = result_reg;
  assign result_valid = result_valid_reg;

  assign enc_next = next & encdec & key_ready;
  assign dec_next = next & ~encdec & key_ready;

  assign muxed_round_idx = encdec ? enc_round_idx : dec_round_idx;

  reg enc_ready_reg;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) enc_ready_reg <= 1'b0;
    else enc_ready_reg <= enc_ready;
  end
  assign posedge_enc_ready = enc_ready & ~enc_ready_reg;

  reg dec_ready_reg;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) dec_ready_reg <= 1'b0;
    else dec_ready_reg <= dec_ready;
  end
  assign posedge_dec_ready = dec_ready & ~dec_ready_reg;

  wire enc_done = posedge_enc_ready;
  wire dec_done = posedge_dec_ready;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) init_state_reg <= 1'b0;
    else if (init) init_state_reg <= 1'b1;
    else if (key_ready) init_state_reg <= 1'b0;
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      dec_prev_cipher <= 256'd0;
    end else if (dec_next) begin
      dec_prev_cipher <= {dec_prev_cipher[127:0], block};
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      enc_prev_cipher <= 128'd0;
    end else if (enc_done) begin
      enc_prev_cipher <= new_enc_block;
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      result_reg <= 128'd0;
      result_valid_reg <= 1'b0;
    end else begin
      result_reg <= result_next;
      result_valid_reg <= result_valid_next;
    end
  end


  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      first_blk_dec_reg <= 1'b0;
    end else if (dec_next) begin
      first_blk_dec_reg <= first_blk;  // 启动时锁存
    end else if (dec_done) begin
      first_blk_dec_reg <= 1'b0;  // 完成后清掉（可选）
    end
  end

  always @(*) begin
    enc_block         = 128'd0;
    dec_block         = 128'd0;

    result_next       = result_reg;
    result_valid_next = 1'b0;

    case (blk_mode)
      2'd0: begin
        enc_block = block;
        dec_block = block;
      end
      2'd1: begin
        enc_block = first_blk ? (block ^ iv) : (block ^ enc_prev_cipher);
        dec_block = block;
      end
      default: ;
    endcase

    if (enc_done) begin
      result_next       = new_enc_block;
      result_valid_next = 1'b1;  // <<< done 当拍打一拍
    end

    if (dec_done) begin
      if (blk_mode == 2'd0) begin
        result_next = new_dec_block;
      end else begin
        result_next = first_blk_dec_reg ? (new_dec_block ^ iv) : (new_dec_block ^ dec_prev_cipher[255:128]);
      end
      result_valid_next = 1'b1;  // <<< done 当拍打一拍
    end
  end


  aes_encipher u_aes_encipher (
      .clk          (clk),
      .rst_n        (rst_n),
      .enc_next     (enc_next),
      .key_len      (key_len),
      .enc_round_idx(enc_round_idx),
      .enc_round_key(round_key),
      .sbox         (enc_sbox),
      .new_sbox     (new_sbox),
      .enc_block    (enc_block),
      .new_enc_block(new_enc_block),
      .enc_ready    (enc_ready)
  );

  aes_decipher u_aes_decipher (
      .clk          (clk),
      .rst_n        (rst_n),
      .dec_next     (dec_next),
      .key_len      (key_len),
      .dec_round_idx(dec_round_idx),
      .dec_round_key(round_key),
      .dec_block    (dec_block),
      .new_dec_block(new_dec_block),
      .dec_ready    (dec_ready)
  );

  aes_key_mem u_aes_key_mem (
      .clk          (clk),
      .rst_n        (rst_n),
      .key_gen      (init),
      .key_len      (key_len),
      .key_in       (key_in),
      .key_ready    (key_ready),
      .sbox_word    (sbox_word),
      .new_sbox_word(new_sbox[31:0]),
      .round_idx    (muxed_round_idx),
      .round_key    (round_key)
  );

  wire [127:0] muxed_sbox = init_state_reg ? {96'd0, sbox_word} : enc_sbox;

  aes_sbox_lut u_aes_sbox_lut (
      .sboxw    (muxed_sbox),
      .new_sboxw(new_sbox)
  );

endmodule
