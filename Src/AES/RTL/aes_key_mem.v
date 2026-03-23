module aes_key_mem (
    input wire clk,
    input wire rst_n,

    input  wire [255 : 0] key_in,    //input key_in; when 128bit len: bit[255:128] is valid;
    input  wire [    1:0] key_len,   //0:128bit, 2:256bit
    input  wire           key_gen,   //1T pulse start key_in expansion process
    output wire           key_ready, //high level: key_in expansion ended

    input  wire [  3 : 0] round_idx,  //key_in select cnt
    output wire [127 : 0] round_key,  //output round_idx key_in

    output wire [31 : 0] sbox_word,     //subbyte input
    input  wire [31 : 0] new_sbox_word  //subbyte output
);

  //----------------------------------------------------------------
  // Parameters.
  //----------------------------------------------------------------
  localparam AES_128_BIT_KEY = 2'h0;
  localparam AES_256_BIT_KEY = 2'h2;

  localparam AES_128_NUM_ROUNDS = 10;
  localparam AES_256_NUM_ROUNDS = 14;

  localparam CTRL_IDLE = 3'h0;
  localparam CTRL_INIT = 3'h1;
  localparam CTRL_GENERATE = 3'h2;
  localparam CTRL_DONE = 3'h3;


  //----------------------------------------------------------------
  // Registers.
  //----------------------------------------------------------------
  reg [127 : 0] key_mem[0 : 14];  //round_idx key_in memory, each round_idx use 128bit key_in
  reg [127 : 0] key_mem_new;  //round_idx key_in mem write in data
  reg key_mem_we;  //round_idx key_in mem write enable

  reg [127 : 0] prev_key0_reg;  //DFF, bit[255:128] for 256b key_in length, not used in 128b key_in length
  reg [127 : 0] prev_key0_new;  //combination logic output
  reg prev_key0_we;  //DFF write enable

  reg [127 : 0] prev_key1_reg;  //DFF, bit[127:0] for 128b/256b key_in length
  reg [127 : 0] prev_key1_new;  //combination logic output
  reg prev_key1_we;  //DFF write enable

  reg [3 : 0] round_ctr_reg;  //DFF: round_idx key_in generate cycle counter; each cycle generate 128b round_idx key_in
  reg [3 : 0] round_ctr_new;  //combination logic output
  reg round_ctr_rst;
  reg round_ctr_inc;  //round_ctr + 1
  reg round_ctr_we;

  reg [2 : 0] key_mem_ctrl_reg;  //FSM DFF
  reg [2 : 0] key_mem_ctrl_new;  //next state of FSM
  reg key_mem_ctrl_we;  //FSM DFF write enable

  reg ready_reg;  //DFF: key_in expansion ended
  reg ready_new;  //combination
  reg ready_we;

  reg [7 : 0] rcon_reg;  //GF*2 for a new key_in group(128b or 256b)
  reg [7 : 0] rcon_new;  //combination output
  wire rcon_we;  //DFF write enable
  wire rcon_set;  //set rcon to initial value
  reg rcon_next;  //1T pulse incr to next key_in group(128b/256b)

  //----------------------------------------------------------------
  // Wires.
  //----------------------------------------------------------------
  reg [31 : 0] tmp_sboxw;  //subbyte input
  reg round_key_update;  //1'b1: key_in expansion period
  reg [127 : 0] tmp_round_key;  //MUXed out round_idx key_in

  //----------------------------------------------------------------
  // Concurrent assignments for ports.
  //----------------------------------------------------------------
  assign round_key = tmp_round_key;
  assign key_ready = ready_reg;
  assign sbox_word = tmp_sboxw;

  //----------------------------------------------------------------
  // reg_update
  //
  // Update functionality for all registers in the core.
  // All registers are positive edge triggered with asynchronous
  // active low reset. All registers have write enable.
  //----------------------------------------------------------------
  always @(posedge clk or negedge rst_n) begin : reg_update
    integer i;

    if (!rst_n) begin
      for (i = 0; i <= AES_256_NUM_ROUNDS; i = i + 1) key_mem[i] <= 128'h0;

      ready_reg        <= 1'b0;
      rcon_reg         <= 8'h0;
      round_ctr_reg    <= 4'h0;
      prev_key0_reg    <= 128'h0;
      prev_key1_reg    <= 128'h0;
      key_mem_ctrl_reg <= CTRL_IDLE;
    end else begin
      if (ready_we) ready_reg <= ready_new;

      if (rcon_we) rcon_reg <= rcon_new;

      if (round_ctr_we) round_ctr_reg <= round_ctr_new;

      if (key_mem_we) key_mem[round_ctr_reg] <= key_mem_new;

      if (prev_key0_we) prev_key0_reg <= prev_key0_new;

      if (prev_key1_we) prev_key1_reg <= prev_key1_new;

      if (key_mem_ctrl_we) key_mem_ctrl_reg <= key_mem_ctrl_new;
    end
  end  // reg_update


  //----------------------------------------------------------------
  // key_mem_read
  //
  // Combinational read port for the key_in memory.
  //----------------------------------------------------------------
  always @* begin : key_mem_read
    tmp_round_key = key_mem[round_idx];
  end  // key_mem_read


  //----------------------------------------------------------------
  // round_key_gen
  //
  // The round_idx key_in generator logic for AES-128 and AES-256.
  //----------------------------------------------------------------
  always @(*) begin : round_key_gen
    reg [31 : 0] w0, w1, w2, w3, w4, w5, w6, w7;  //key_in of last group(128b/256b)
    reg [31 : 0] k0, k1, k2, k3;  //new generate key_in of this cycle, each cycle gen 128b key_in
    reg [31 : 0] rconw;  //rcon valid in AES stander
    reg [31 : 0] tw;  //sbox only
    reg [31 : 0] rotstw;  //sbox and rotate
    reg [31 : 0] trw;  //rotate, sbox, XOR rcon

    // Default assignments.
    key_mem_new   = 128'h0;
    key_mem_we    = 1'b0;
    prev_key0_new = 128'h0;
    prev_key0_we  = 1'b0;
    prev_key1_new = 128'h0;
    prev_key1_we  = 1'b0;

    k0 = 32'h0;
    k1 = 32'h0;
    k2 = 32'h0;
    k3 = 32'h0;

    rcon_next  = 1'b0;

    // Extract words and calculate intermediate values.
    // Perform rotation of sbox word etc.
    w0 = prev_key0_reg[127 : 096];    //bit[255:234] of 256b key_in mode of last group
    w1 = prev_key0_reg[095 : 064];    //bit[233:192] of 256b key_in mode of last group
    w2 = prev_key0_reg[063 : 032];    //bit[191:160] of 256b key_in mode of last group
    w3 = prev_key0_reg[031 : 000];    //bit[159:128] of 256b key_in mode of last group

    w4 = prev_key1_reg[127 : 096];    //bit[127:96] of 128b/256b key_in mode of last group
    w5 = prev_key1_reg[095 : 064];
    w6 = prev_key1_reg[063 : 032];
    w7 = prev_key1_reg[031 : 000];    //bit[31:0] of 128b/256b key_in mode of last group

    rconw = {rcon_reg, 24'h0};
    tmp_sboxw = w7;
    rotstw = {new_sbox_word[23 : 00], new_sbox_word[31 : 24]};    //cal order of sbox and rotate can exchange
    trw = rotstw ^ rconw;
    tw = new_sbox_word;

    // Generate the specific round_idx keys.
    if (round_key_update) begin
      key_mem_we = 1'b1;  //each cycle generate a 128b key_in
      case (key_len)
        AES_128_BIT_KEY: begin
          prev_key1_we = 1'b1;  //store key_in of last group
          rcon_next    = 1'b1;  //update rcon for next group

          if (round_ctr_reg == 0) //get from input key_in
                  begin
            key_mem_new   = key_in[255 : 128];
            prev_key1_new = key_in[255 : 128];
          end else begin
            k0            = w4 ^ trw;  //distance of w4 and k0 is 4x32b(a 128b group)
            k1            = w5 ^ w4 ^ trw;  //k0 ^ w5, distance of w5 and k1 is 4x32b
            k2            = w6 ^ w5 ^ w4 ^ trw;  //k1 ^ w6, distance of w6 and k2 is 4x32b
            k3            = w7 ^ w6 ^ w5 ^ w4 ^ trw;  //K2 ^ w7, distance of w7 and k3 is 4x32b

            key_mem_new   = {k0, k1, k2, k3};
            prev_key1_new = {k0, k1, k2, k3};
          end
        end

        AES_256_BIT_KEY: begin
          if (round_ctr_reg == 0)         //get from input key_in
                  begin
            key_mem_new   = key_in[255 : 128];
            prev_key0_new = key_in[255 : 128];
            prev_key0_we  = 1'b1;
          end
                else if (round_ctr_reg == 1)    //get from input key_in
                  begin
            key_mem_new   = key_in[127 : 0];
            prev_key1_new = key_in[127 : 0];
            prev_key1_we  = 1'b1;
            rcon_next     = 1'b1;
          end else begin
            if (round_ctr_reg[0] == 0)  //first 128b of a 256b group
                      begin
              k0 = w0 ^ trw;  //distance of w0 and k0 is 8x32b(a 256b group)
              k1 = w1 ^ w0 ^ trw;  //distance of w1 and k1 is 8x32b
              k2 = w2 ^ w1 ^ w0 ^ trw;
              k3 = w3 ^ w2 ^ w1 ^ w0 ^ trw;  //distance of w3 and k3 is 8x32b
            end else  //second 128b of a 256b group
            begin
              k0        = w0 ^ tw;  //distance of w0 and k0 is 8x32b(a 256b group)
              k1        = w1 ^ w0 ^ tw;
              k2        = w2 ^ w1 ^ w0 ^ tw;
              k3        = w3 ^ w2 ^ w1 ^ w0 ^ tw;
              rcon_next = 1'b1;
            end

            // Store the generated round_idx keys (left shift in 128b).
            key_mem_new   = {k0, k1, k2, k3};
            prev_key1_new = {k0, k1, k2, k3};  //new generated 128b always write in prev_key1
            prev_key1_we  = 1'b1;
            prev_key0_new = prev_key1_reg;  //always shift in from prev_key1
            prev_key0_we  = 1'b1;
          end
        end

        default: begin
        end
      endcase  // case (key_len)
    end
  end  // round_key_gen


  //----------------------------------------------------------------
  // rcon_logic
  //
  // Caclulates the rcon value for the different key_in expansion
  // iterations.
  //----------------------------------------------------------------

  assign rcon_set = (key_mem_ctrl_reg == CTRL_IDLE) & key_gen;
  assign rcon_we  = rcon_next | rcon_set;

  always @(*) begin : rcon_logic
    reg [7 : 0] tmp_rcon;

    tmp_rcon = {rcon_reg[6 : 0], 1'b0} ^ (8'h1b & {8{rcon_reg[7]}});  //GF*2

    if (rcon_next) rcon_new = tmp_rcon[7 : 0];
    else  //if(rcon_set)
      rcon_new = 8'h8d;  //specical choose vlaue to make tmp_rcon = 0x01 at 1st round_idx
  end


  //----------------------------------------------------------------
  // round_ctr
  //
  // The round_idx counter logic with increase and reset.
  //----------------------------------------------------------------
  always @(*) begin : round_ctr
    round_ctr_new = 4'h0;
    round_ctr_we  = 1'b0;

    if (round_ctr_rst) begin
      round_ctr_new = 4'h0;
      round_ctr_we  = 1'b1;
    end else if (round_ctr_inc) begin
      round_ctr_new = round_ctr_reg + 1'b1;
      round_ctr_we  = 1'b1;
    end
  end


  //----------------------------------------------------------------
  // key_mem_ctrl
  //
  //
  // The FSM that controls the round_idx key_in generation.
  //----------------------------------------------------------------
  wire [3 : 0] num_rounds;

  assign num_rounds = (key_len == AES_128_BIT_KEY) ? AES_128_NUM_ROUNDS : AES_256_NUM_ROUNDS;

  always @(*) begin : key_mem_ctrl

    // Default assignments.
    ready_new        = 1'b0;
    ready_we         = 1'b0;
    round_key_update = 1'b0;
    round_ctr_rst    = 1'b0;
    round_ctr_inc    = 1'b0;
    key_mem_ctrl_new = CTRL_IDLE;
    key_mem_ctrl_we  = 1'b0;

    case (key_mem_ctrl_reg)
      CTRL_IDLE: begin
        if (key_gen) begin
          ready_new        = 1'b0;
          ready_we         = 1'b1;
          key_mem_ctrl_new = CTRL_INIT;
          key_mem_ctrl_we  = 1'b1;
        end
      end

      CTRL_INIT: begin
        round_ctr_rst    = 1'b1;
        key_mem_ctrl_new = CTRL_GENERATE;
        key_mem_ctrl_we  = 1'b1;
      end

      CTRL_GENERATE: begin
        round_ctr_inc    = 1'b1;
        round_key_update = 1'b1;
        if (round_ctr_reg == num_rounds) begin
          key_mem_ctrl_new = CTRL_DONE;
          key_mem_ctrl_we  = 1'b1;
        end
      end

      CTRL_DONE: begin
        ready_new        = 1'b1;
        ready_we         = 1'b1;
        key_mem_ctrl_new = CTRL_IDLE;
        key_mem_ctrl_we  = 1'b1;
      end

      default: begin
      end
    endcase  // case (key_mem_ctrl_reg)

  end  // key_mem_ctrl
endmodule  // aes_key_mem

//======================================================================
// EOF aes_key_mem.v
//======================================================================
