// ------------------------------------------------------------
// 寄存器定义（AES）
//
// addr | bit   | name         | access | description
// ------------------------------------------------------------
// 00   | 0     | aes_sof      | r/w    | SW 写 1 启动一个数据块的 AES 处理；SW 读返回 0
//      | 3:1   | NA           | r      | Reserved
//      | 4     | keg_gen      | r/w    | SW 写 1 启动一次 AES 中 key expand 过程；SW 读返回 0
//      |31:5   | NA           | r      | Reserved
//
// 04   | 0     | enc_dec      | r/w    | 1: encipher mode；0: decipher mode
//      | 3:1   | NA           | r      | Reserved
//      | 5:4   | blk_mode     | r/w    | 0: ECB；1: CBC；2: CFB；3: OFB；CFB/OFB 模式暂不支持
//      | 7:6   | NA           | r      | Reserved
//      | 9:8   | key_len      | r/w    | 0: 128bit key；1: 196bit key；2: 256bit key
//      |31:10  | NA           | r      | Reserved
//
// 08   |31:0   | NA           | r      | Reserved
//
// 0C   | 0     | intr         | r/w    | 1: AES 结束一个数据块处理；SW 写 0 清楚中断
//      |31:1   | NA           | r      | Reserved
//
// 10   |31:0   | blk_base     | r/w    | AES 读取的源数据的系统地址（byte 单位）；必须 128bit 对齐，blk_base[3:0]=4'b0000
//
// 14   |31:0   | code_base    | r/w    | AES 处理后写出数据的系统地址（byte 单位）；必须 128bit 对齐，code_base[3:0]=4'b0000
//
// 18   |31:0   | blk_len      | r/w    | AES 处理的数据块大小（byte 单位，从 0 计数）；必须 16byte 整数倍，blk_len[3:0]=4'b1111
//
// 1C   |31:0   | NA           | r      | Reserved
//
// 20   |31:0   | iv[31:0]     | r/w    | initial vector
// 24   |31:0   | iv[63:32]    | r/w    | initial vector
// 28   |31:0   | iv[95:64]    | r/w    | initial vector
// 2C   |31:0   | iv[127:96]   | r/w    | initial vector
//
// 30   |31:0   | NA           | r      | Reserved
// 34   |31:0   | NA           | r      | Reserved
// 38   |31:0   | NA           | r      | Reserved
// 3C   |31:0   | NA           | r      | Reserved
//
// 40   |31:0   | key[31:0]    | r/w    | key vector
// 44   |31:0   | key[63:32]   | r/w    | key vector
// 48   |31:0   | key[95:64]   | r/w    | key vector
// 4C   |31:0   | key[127:96]  | r/w    | key vector
// 50   |31:0   | key[159:128] | r/w    | key vector，valid for 256bit key length
// 54   |31:0   | key[191:160] | r/w    | key vector，valid for 256bit key length
// 58   |31:0   | key[223:192] | r/w    | key vector，valid for 256bit key length
// 5C   |31:0   | key[255:224] | r/w    | key vector，valid for 256bit key length
//
// ------------------------------------------------------------
module aes_cfg #(
    parameter APB_ADDR_WIDTH = 8,
    parameter APB_DATA_WIDTH = 32
) (
    input  wire                      clk,
    input  wire                      rst_n,
    input  wire                      psel,
    input  wire                      penable,
    input  wire [APB_ADDR_WIDTH-1:0] paddr,          //byte addr
    input  wire                      pwrite,
    input  wire [APB_DATA_WIDTH-1:0] pwdata,
    output wire                      pready,
    output reg  [APB_DATA_WIDTH-1:0] prdata,
    output reg                       cfg_key_gen,    //1T pulse start the key expansion process
    output reg                       cfg_blk_sof,    //1T pulse start the enc/dec of a bulk data block
    output reg  [              31:0] cfg_blk_base,   //must be 16B aligned, bit[3:0] == 'd0, cnt from 1
    output reg  [              31:0] cfg_blk_len,    //must be Nx16B size, cnt from 0
    output reg  [              31:0] cfg_code_base,
    output reg                       cfg_enc_dec,    //1: enc; 0: dec
    output reg  [               1:0] cfg_blk_mode,   //0: ECB; 1: CBC; 2: CFB; 3: OFB
    output reg  [               1:0] cfg_key_len,    //0:128b; 2: 256bit
    output wire [             255:0] cfg_key,        //big-endian; when 128bit key len, just bit[255:128] is valid
    output wire [             127:0] cfg_iv,         //big-endian
    input  wire                      set_blk_end,
    output reg                       intr
);
  //--- apb inf
  wire         apb_write;
  wire         apb_read;
  wire [  4:0] apb_addr;  //32b addr
  wire         clr_intr;
  reg  [255:0] key;
  reg  [127:0] iv;

  assign apb_write = psel & pwrite & penable;
  assign apb_read = psel & (!pwrite);
  assign apb_addr = paddr[2+:5];
  assign pready = 1'b1;
  assign clr_intr = apb_write & penable & (apb_addr == 'd3) & (!pwdata[0]);

  //1T pulse start the key expansion process
  always @(posedge clk or negedge rst_n)
    if (~rst_n) cfg_key_gen <= 1'b0;
    else if (apb_write && (apb_addr == 'd0) && pwdata[4]) cfg_key_gen <= 1'b1;
    else cfg_key_gen <= 1'b0;

  //1T pulse start the enc/dec of a bulk data block
  always @(posedge clk or negedge rst_n)
    if (~rst_n) cfg_blk_sof <= 1'b0;
    else if (apb_write && (apb_addr == 'd0) && pwdata[0]) cfg_blk_sof <= 1'b1;
    else cfg_blk_sof <= 1'b0;

  always @(posedge clk or negedge rst_n)
    if (~rst_n) begin
      cfg_enc_dec  <= 1'b1;
      cfg_blk_mode <= 'd0;
      cfg_key_len  <= 'd0;
    end else if (apb_write && (apb_addr == 'd1)) begin
      cfg_enc_dec  <= pwdata[0];
      cfg_blk_mode <= pwdata[5:4];
      cfg_key_len  <= pwdata[9:8];
    end

  always @(posedge clk or negedge rst_n)
    if (~rst_n) intr <= 1'b0;
    else if (set_blk_end) intr <= 1'b1;
    else if (clr_intr) intr <= 1'b0;

  always @(posedge clk or negedge rst_n)
    if (~rst_n) cfg_blk_base <= 'd0;
    else if (apb_write && (apb_addr == 'd4)) cfg_blk_base <= {pwdata[31:4], 4'h0};

  always @(posedge clk or negedge rst_n)
    if (~rst_n) cfg_code_base <= 'd0;
    else if (apb_write && (apb_addr == 'd5)) cfg_code_base <= {pwdata[31:4], 4'h0};

  always @(posedge clk or negedge rst_n)
    if (~rst_n) cfg_blk_len <= 32'hf;
    else if (apb_write && (apb_addr == 'd6)) cfg_blk_len <= {pwdata[31:4], 4'hf};

  always @(posedge clk or negedge rst_n)
    if (~rst_n) iv[0*32+:32] <= 'd0;
    else if (apb_write && (apb_addr == 'd8)) iv[0*32+:32] <= pwdata[31:0];

  always @(posedge clk or negedge rst_n)
    if (~rst_n) iv[1*32+:32] <= 'd0;
    else if (apb_write && (apb_addr == 'd9)) iv[1*32+:32] <= pwdata[31:0];

  always @(posedge clk or negedge rst_n)
    if (~rst_n) iv[2*32+:32] <= 'd0;
    else if (apb_write && (apb_addr == 'd10)) iv[2*32+:32] <= pwdata[31:0];

  always @(posedge clk or negedge rst_n)
    if (~rst_n) iv[3*32+:32] <= 'd0;
    else if (apb_write && (apb_addr == 'd11)) iv[3*32+:32] <= pwdata[31:0];

  always @(posedge clk or negedge rst_n)
    if (~rst_n) key[0*32+:32] <= 'd0;
    else if (apb_write && (apb_addr == 'd16)) key[0*32+:32] <= pwdata[31:0];

  always @(posedge clk or negedge rst_n)
    if (~rst_n) key[1*32+:32] <= 'd0;
    else if (apb_write && (apb_addr == 'd17)) key[1*32+:32] <= pwdata[31:0];

  always @(posedge clk or negedge rst_n)
    if (~rst_n) key[2*32+:32] <= 'd0;
    else if (apb_write && (apb_addr == 'd18)) key[2*32+:32] <= pwdata[31:0];

  always @(posedge clk or negedge rst_n)
    if (~rst_n) key[3*32+:32] <= 'd0;
    else if (apb_write && (apb_addr == 'd19)) key[3*32+:32] <= pwdata[31:0];

  always @(posedge clk or negedge rst_n)
    if (~rst_n) key[4*32+:32] <= 'd0;
    else if (apb_write && (apb_addr == 'd20)) key[4*32+:32] <= pwdata[31:0];

  always @(posedge clk or negedge rst_n)
    if (~rst_n) key[5*32+:32] <= 'd0;
    else if (apb_write && (apb_addr == 'd21)) key[5*32+:32] <= pwdata[31:0];

  always @(posedge clk or negedge rst_n)
    if (~rst_n) key[6*32+:32] <= 'd0;
    else if (apb_write && (apb_addr == 'd22)) key[6*32+:32] <= pwdata[31:0];

  always @(posedge clk or negedge rst_n)
    if (~rst_n) key[7*32+:32] <= 'd0;
    else if (apb_write && (apb_addr == 'd23)) key[7*32+:32] <= pwdata[31:0];

  generate
    genvar i;
    for (i = 0; i <= 15; i = i + 1) begin : iv_big_endian
      assign cfg_iv[i*8+:8] = iv[(15-i)*8+:8];
    end
  endgenerate

  generate
    genvar j;
    for (j = 0; j <= 31; j = j + 1) begin : key_big_endian
      assign cfg_key[j*8+:8] = key[(31-j)*8+:8];
    end
  endgenerate


  //apb read
  always @(posedge clk or negedge rst_n)
    if (~rst_n) prdata <= 'd0;
    else if (apb_read) begin
      case (apb_addr)
        'd0: prdata <= 'd0;
        'd1: prdata <= {20'h0, 2'h0, cfg_key_len, 2'h0, cfg_blk_mode, 3'h0, cfg_enc_dec};

        'd3: prdata <= {31'h0, intr};
        'd4: prdata <= cfg_blk_base;
        'd5: prdata <= cfg_code_base;
        'd6: prdata <= cfg_blk_len;

        'd8:  prdata <= iv[0*32+:32];
        'd9:  prdata <= iv[1*32+:32];
        'd10: prdata <= iv[2*32+:32];
        'd11: prdata <= iv[3*32+:32];

        'd16: prdata <= key[0*32+:32];
        'd17: prdata <= key[1*32+:32];
        'd18: prdata <= key[2*32+:32];
        'd19: prdata <= key[3*32+:32];
        'd20: prdata <= key[4*32+:32];
        'd21: prdata <= key[5*32+:32];
        'd22: prdata <= key[6*32+:32];
        'd23: prdata <= key[7*32+:32];

        default: prdata <= 'd0;
      endcase
    end
endmodule

