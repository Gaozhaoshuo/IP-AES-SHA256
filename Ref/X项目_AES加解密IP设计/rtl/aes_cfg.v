// ---------------------------------------------------------------------------//
// The confidential and proprietary information contained in this file may
// only be used by a person authorised under and to the extent permitted
// by a subsisting licensing agreement from SiliconThink.
//
//      (C) COPYRIGHT SiliconThink Limited or its affiliates
//                   ALL RIGHTS RESERVED
//
// This entire notice must be reproduced on all copies of this file
// and copies of this file may only be made by a person if such person is
// permitted to do so under the terms of a subsisting license agreement
// from SiliconThink or its affiliates.
// ---------------------------------------------------------------------------//

//----------------------------------------------------------------------------//
// File name    : aes_cfg.v
// Author       : sky@siliconthink.cn
// E-mail       : 
// Project      : 
// Created      : 
// Copyright    : 
// Description  : 
//----------------------------------------------------------------------------//

module aes_cfg(
	//--- APB configure inf
	psel			,
	penable			,
	paddr			,
	pwrite			,
	pwdata			,
	pready			,
	prdata			,

	//--- cfg regs
    cfg_key_gen     ,
    cfg_blk_sof     ,
    cfg_blk_base    ,
    cfg_blk_len     ,
    cfg_code_base   ,
    cfg_enc_dec     ,
    cfg_blk_mode    ,
    cfg_key_len     ,
    cfg_key         ,
    cfg_iv          ,

    set_blk_end     ,
    intr            ,
    clk             ,
    rstn             
);

input   wire            clk, rstn       ;

//--- APB configure inf
input	wire			psel			;
input	wire			penable			;
input	wire	[7:0]	paddr			;	//byte addr
input	wire			pwrite			;
input	wire	[31:0]	pwdata			;
output	wire			pready			;
output	reg		[31:0]	prdata			;

output  reg             cfg_key_gen     ;   //1T pulse start the key expansion process
output  reg             cfg_blk_sof     ;   //1T pulse start the enc/dec of a bulk data block
output  reg     [31:0]  cfg_blk_base    ;   //must be 16B aligned, bit[3:0] == 'd0, cnt from 1
output  reg     [31:0]  cfg_blk_len     ;   //must be Nx16B size, cnt from 0
output  reg     [31:0]  cfg_code_base   ;
output  reg             cfg_enc_dec     ;   //1: enc; 0: dec
output  reg     [1:0]   cfg_blk_mode    ;   //0: ECB; 1: CBC; 2: CFB; 3: OFB
output  reg     [1:0]   cfg_key_len     ;   //0:128b; 2: 256bit
output  wire    [255:0] cfg_key         ;   //big-endian; when 128bit key len, just bit[255:128] is valid
output  wire    [127:0] cfg_iv          ;   //big-endian

input   wire            set_blk_end     ;
output  reg             intr            ;

//--- apb inf
wire			apb_write		;
wire			apb_read		;
wire	[4:0]	apb_addr		;	//32b addr
wire			clr_intr		;
reg     [255:0] key             ;
reg     [127:0] iv              ;


assign	apb_write		= psel & pwrite & penable;
assign	apb_read		= psel & (!pwrite);
assign	apb_addr		= paddr[2 +: 5];
assign	pready			= 1'b1;
assign	clr_intr		= apb_write & penable & (apb_addr == 'd3) & (!pwdata[0]);


always @(posedge clk or negedge rstn)
if(~rstn)
    cfg_key_gen <= 1'b0;
else if(apb_write && (apb_addr == 'd0) && pwdata[4])
    cfg_key_gen <= 1'b1;
else
    cfg_key_gen <= 1'b0;

always @(posedge clk or negedge rstn)
if(~rstn)
    cfg_blk_sof <= 1'b0;
else if(apb_write && (apb_addr == 'd0) && pwdata[0])
    cfg_blk_sof <= 1'b1;
else
    cfg_blk_sof <= 1'b0;

always @(posedge clk or negedge rstn)
if(~rstn) begin
    cfg_enc_dec <= 1'b1;
    cfg_blk_mode<= 'd0;
    cfg_key_len <= 'd0;
end else if(apb_write && (apb_addr == 'd1)) begin
    cfg_enc_dec <= pwdata[0];
    cfg_blk_mode<= pwdata[5:4];
    cfg_key_len <= pwdata[9:8];
end

always @(posedge clk or negedge rstn)
if(~rstn)
    intr    <= 1'b0;
else if(set_blk_end)
    intr    <= 1'b1;
else if(clr_intr)
    intr    <= 1'b0;

always @(posedge clk or negedge rstn)
if(~rstn)
    cfg_blk_base <= 'd0; 
else if(apb_write && (apb_addr == 'd4))
    cfg_blk_base <= {pwdata[31:4], 4'h0};

always @(posedge clk or negedge rstn)
if(~rstn)
    cfg_code_base <= 'd0;
else if(apb_write && (apb_addr == 'd5))
    cfg_code_base <= {pwdata[31:4], 4'h0};

always @(posedge clk or negedge rstn)
if(~rstn)
    cfg_blk_len <= 32'hf;
else if(apb_write && (apb_addr == 'd6))
    cfg_blk_len <= {pwdata[31:4], 4'hf};

always @(posedge clk or negedge rstn)
if(~rstn)
    iv[0*32 +: 32]  <= 'd0;
else if(apb_write && (apb_addr == 'd8))
    iv[0*32 +: 32]  <= pwdata[31:0];

always @(posedge clk or negedge rstn)
if(~rstn)
    iv[1*32 +: 32]  <= 'd0;
else if(apb_write && (apb_addr == 'd9))
    iv[1*32 +: 32]  <= pwdata[31:0];

always @(posedge clk or negedge rstn)
if(~rstn)
    iv[2*32 +: 32]  <= 'd0;
else if(apb_write && (apb_addr == 'd10))
    iv[2*32 +: 32]  <= pwdata[31:0];

always @(posedge clk or negedge rstn)
if(~rstn)
    iv[3*32 +: 32]  <= 'd0;
else if(apb_write && (apb_addr == 'd11))
    iv[3*32 +: 32]  <= pwdata[31:0];

always @(posedge clk or negedge rstn)
if(~rstn)
    key[0*32 +: 32] <= 'd0;
else if(apb_write && (apb_addr == 'd16))
    key[0*32 +: 32] <= pwdata[31:0];

always @(posedge clk or negedge rstn)
if(~rstn)
    key[1*32 +: 32] <= 'd0;
else if(apb_write && (apb_addr == 'd17))
    key[1*32 +: 32] <= pwdata[31:0];

always @(posedge clk or negedge rstn)
if(~rstn)
    key[2*32 +: 32] <= 'd0;
else if(apb_write && (apb_addr == 'd18))
    key[2*32 +: 32] <= pwdata[31:0];

always @(posedge clk or negedge rstn)
if(~rstn)
    key[3*32 +: 32] <= 'd0;
else if(apb_write && (apb_addr == 'd19))
    key[3*32 +: 32] <= pwdata[31:0];

always @(posedge clk or negedge rstn)
if(~rstn)
    key[4*32 +: 32] <= 'd0;
else if(apb_write && (apb_addr == 'd20))
    key[4*32 +: 32] <= pwdata[31:0];

always @(posedge clk or negedge rstn)
if(~rstn)
    key[5*32 +: 32] <= 'd0;
else if(apb_write && (apb_addr == 'd21))
    key[5*32 +: 32] <= pwdata[31:0];

always @(posedge clk or negedge rstn)
if(~rstn)
    key[6*32 +: 32] <= 'd0;
else if(apb_write && (apb_addr == 'd22))
    key[6*32 +: 32] <= pwdata[31:0];

always @(posedge clk or negedge rstn)
if(~rstn)
    key[7*32 +: 32] <= 'd0;
else if(apb_write && (apb_addr == 'd23))
    key[7*32 +: 32] <= pwdata[31:0];

generate
genvar i;
for(i=0; i<=15; i=i+1) begin : iv_big_endian
    assign  cfg_iv[i*8 +: 8] = iv[(15-i)*8 +: 8];
end
endgenerate

generate
genvar  j;
for(j=0; j<=31; j=j+1) begin : key_big_endian
    assign  cfg_key[j*8 +: 8] = key[(31-j)*8 +: 8];
end
endgenerate


//apb read
always @(posedge clk or negedge rstn)
if(~rstn)
    prdata  <= 'd0;
else if(apb_read) begin
    case(apb_addr)
    'd0:    prdata  <= 'd0;
    'd1:    prdata  <= {20'h0, 2'h0, cfg_key_len,
                        2'h0, cfg_blk_mode, 3'h0, cfg_enc_dec};

    'd3:    prdata  <= {31'h0, intr};
    'd4:    prdata  <= cfg_blk_base;
    'd5:    prdata  <= cfg_code_base;
    'd6:    prdata  <= cfg_blk_len;

    'd8:    prdata  <= iv[0*32 +: 32];
    'd9:    prdata  <= iv[1*32 +: 32];
    'd10:   prdata  <= iv[2*32 +: 32];
    'd11:   prdata  <= iv[3*32 +: 32];

    'd16:   prdata  <= key[0*32 +: 32];
    'd17:   prdata  <= key[1*32 +: 32];
    'd18:   prdata  <= key[2*32 +: 32];
    'd19:   prdata  <= key[3*32 +: 32];
    'd20:   prdata  <= key[4*32 +: 32];
    'd21:   prdata  <= key[5*32 +: 32];
    'd22:   prdata  <= key[6*32 +: 32];
    'd23:   prdata  <= key[7*32 +: 32];

    default:prdata  <= 'd0;
    endcase
end



endmodule

