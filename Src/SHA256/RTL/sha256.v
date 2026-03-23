// ------------------------------------------------------------
// 寄存器定义
//
// addr | bit  | name     | access | description
// ------------------------------------------------------------
// 00   | 0    | sha_sof  | r/w    | SW 写 1 启动 SHA256 处理；SW 读返回 0
//      |31:1  | NA       | r      | Reserved
//
// 04   |31:0  | blk_base | r/w    | 数据块系统地址（byte 单位），必须 32bit 对齐
//
// 08   |31:0  | blk_len  | r/w    | 数据块长度（byte 单位），必须 64 字节对齐
//
// 0C   | 0    | intr     | r/w    | W1: 完成处理；SW 写 0 清除
//      |31:1  | NA       | r      | Reserved
//
// 10~1C           Reserved
//
// 20   |31:0  | hash_0  |  r     | SHA256 结果 bit[0*32 +: 32]
// 24   |31:0  | hash_1  |  r     | SHA256 结果 bit[1*32 +: 32]
// 28   |31:0  | hash_2  |  r     | SHA256 结果 bit[2*32 +: 32]
// 2C   |31:0  | hash_3  |  r     | SHA256 结果 bit[3*32 +: 32]
// 30   |31:0  | hash_4  |  r     | SHA256 结果 bit[4*32 +: 32]
// 34   |31:0  | hash_5  |  r     | SHA256 结果 bit[5*32 +: 32]
// 38   |31:0  | hash_6  |  r     | SHA256 结果 bit[6*32 +: 32]
// 3C   |31:0  | hash_7  |  r     | SHA256 结果 bit[7*32 +: 32]
//
// ------------------------------------------------------------
module sha256 #(
    parameter APB_ADDR_WIDTH  = 8,
    parameter APB_DATA_WIDTH  = 32,
    parameter AXI_ADDR_WIDTH  = 32,
    parameter AXI_DATA_WIDTH  = 32,
    parameter AXIS_DATA_WIDTH = 32,
    parameter LEN_WIDTH       = 32,
    parameter TAG_WIDTH       = 8,
    parameter ERR_WIDTH       = 4
) (
    input wire clk,
    input wire rst_n,

    // APB slave
    input wire                      psel,
    input wire [APB_ADDR_WIDTH-1:0] paddr,
    input wire                      penable,
    input wire                      pwrite,
    input wire [APB_DATA_WIDTH-1:0] pwdata,

    output wire [APB_DATA_WIDTH-1:0] prdata,
    output wire                      pready,
    // output wire                      pslverr,

    // AXI master read
    output wire [AXI_ADDR_WIDTH-1:0] m_axi_araddr,
    output wire [               7:0] m_axi_arlen,
    output wire [               2:0] m_axi_arsize,
    output wire [               1:0] m_axi_arburst,
    output wire                      m_axi_arvalid,

    input  wire                      m_axi_arready,
    input  wire [AXI_DATA_WIDTH-1:0] m_axi_rdata,
    input  wire [               1:0] m_axi_rresp,
    input  wire                      m_axi_rlast,
    input  wire                      m_axi_rvalid,
    output wire                      m_axi_rready,
    output wire                      intr
);


  // ------------------------------------------------------------
  // APB decode
  // ------------------------------------------------------------
  wire sha_busy;
  wire [APB_ADDR_WIDTH-1:0] reg_addr = paddr;
  wire [APB_ADDR_WIDTH-1:2] word_addr = reg_addr[APB_ADDR_WIDTH-1:2];

  wire reg_read_en = psel & (~pwrite);
  wire reg_write_en = psel & penable & pwrite;

  assign pready  = ~sha_busy;
  // assign pslverr = 1'b0;

  // ------------------------------------------------------------
  // Registers
  // ------------------------------------------------------------
  reg             sha_sof_pulse_reg;
  reg     [ 31:0] blk_base_reg;
  reg     [ 31:0] blk_len_reg;  // byte length, 64B aligned
  reg             intr_reg;

  reg     [ 31:0] hash_reg                                                                 [0:7];  // hash_0..hash_7

  // digest wires
  wire    [255:0] digest;
  wire            digest_valid;

  // intr set/clear
  wire            intr_set = digest_valid;
  wire            intr_clear = reg_write_en && (word_addr == 6'h03) && (pwdata[0] == 1'b0);

  integer         i;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      sha_sof_pulse_reg <= 1'b0;
      blk_base_reg      <= 32'd0;
      blk_len_reg       <= 32'd0;
      intr_reg          <= 1'b0;
      for (i = 0; i < 8; i = i + 1) begin
        hash_reg[i] <= 32'd0;
      end
    end else begin
      // default: pulse deassert
      sha_sof_pulse_reg <= 1'b0;

      // APB writes
      if (reg_write_en) begin
        case (word_addr)
          6'h00: begin
            // sha_sof: 写1启动；读回0，所以不存bit，只产生pulse
            if (pwdata[0]) sha_sof_pulse_reg <= 1'b1;
          end
          6'h01: begin
            blk_base_reg <= pwdata;
          end
          6'h02: begin
            blk_len_reg <= pwdata + 32'd1;
          end
          6'h03: begin
            // intr: 写0清除；写1无影响
            // 清除在下面统一处理 intr_clear
          end
          default: begin
            // reserved / hash_x are read-only
          end
        endcase
      end

      // intr: set has priority over clear (避免同周期丢中断)
      intr_reg <= (intr_reg & ~intr_clear) | intr_set;

      // latch hash regs on digest_valid
      if (digest_valid) begin
        hash_reg[7] <= digest[31:0];
        hash_reg[6] <= digest[63:32];
        hash_reg[5] <= digest[95:64];
        hash_reg[4] <= digest[127:96];
        hash_reg[3] <= digest[159:128];
        hash_reg[2] <= digest[191:160];
        hash_reg[1] <= digest[223:192];
        hash_reg[0] <= digest[255:224];
      end
    end
  end

  // APB read mux
  reg [APB_DATA_WIDTH-1:0] reg_rdata;
  always @(*) begin
    reg_rdata = 32'd0;
    if (reg_read_en) begin
      case (word_addr)
        6'h00:   reg_rdata = 32'd0;  // sha_sof 读回0
        6'h01:   reg_rdata = blk_base_reg;
        6'h02:   reg_rdata = blk_len_reg;
        6'h03:   reg_rdata = {31'd0, intr_reg};
        6'h08:   reg_rdata = hash_reg[0];  // 0x20
        6'h09:   reg_rdata = hash_reg[1];  // 0x24
        6'h0A:   reg_rdata = hash_reg[2];  // 0x28
        6'h0B:   reg_rdata = hash_reg[3];  // 0x2C
        6'h0C:   reg_rdata = hash_reg[4];  // 0x30
        6'h0D:   reg_rdata = hash_reg[5];  // 0x34
        6'h0E:   reg_rdata = hash_reg[6];  // 0x38
        6'h0F:   reg_rdata = hash_reg[7];  // 0x3C
        default: reg_rdata = 32'd0;
      endcase
    end
  end
  assign prdata = reg_rdata;
  assign intr = intr_reg;
  // ------------------------------------------------------------
  // DMA wires
  // ------------------------------------------------------------
  wire [ AXI_ADDR_WIDTH-1:0] dma_desc_addr;
  wire [      LEN_WIDTH-1:0] dma_desc_len;
  wire [      TAG_WIDTH-1:0] dma_desc_tag;
  wire                       dma_desc_valid;
  wire                       dma_desc_ready;

  wire [      TAG_WIDTH-1:0] dma_status_tag;
  wire [      ERR_WIDTH-1:0] dma_status_error;
  wire                       dma_status_valid;

  wire [AXIS_DATA_WIDTH-1:0] axis_read_data_tdata;
  wire [                3:0] axis_read_data_tkeep;
  wire                       axis_read_data_tvalid;
  wire                       axis_read_data_tready;
  wire                       axis_read_data_tlast;

  wire                       dma_enable;

  // ------------------------------------------------------------
  // axi_dma_rd instance
  // ------------------------------------------------------------
  axi_dma_rd #(
      .AXI_DATA_WIDTH   (AXI_DATA_WIDTH),
      .AXI_ADDR_WIDTH   (AXI_ADDR_WIDTH),
      .AXI_MAX_BURST_LEN(16),
      .AXIS_DATA_WIDTH  (AXIS_DATA_WIDTH),
      .AXIS_LAST_ENABLE (1),
      .LEN_WIDTH        (LEN_WIDTH),
      .TAG_WIDTH        (TAG_WIDTH)
  ) u_axi_dma_rd (
      .clk  (clk),
      .rst_n(rst_n),

      .s_axis_read_desc_addr (dma_desc_addr),
      .s_axis_read_desc_len  (dma_desc_len),
      .s_axis_read_desc_tag  (dma_desc_tag),
      .s_axis_read_desc_valid(dma_desc_valid),
      .s_axis_read_desc_ready(dma_desc_ready),

      .m_axis_read_desc_status_tag  (dma_status_tag),
      .m_axis_read_desc_status_error(dma_status_error),
      .m_axis_read_desc_status_valid(dma_status_valid),

      .m_axis_read_data_tdata (axis_read_data_tdata),
      .m_axis_read_data_tvalid(axis_read_data_tvalid),
      .m_axis_read_data_tready(axis_read_data_tready),
      .m_axis_read_data_tlast (axis_read_data_tlast),

      .m_axi_araddr (m_axi_araddr),
      .m_axi_arlen  (m_axi_arlen),
      .m_axi_arsize (m_axi_arsize),
      .m_axi_arburst(m_axi_arburst),
      .m_axi_arvalid(m_axi_arvalid),
      .m_axi_arready(m_axi_arready),
      .m_axi_rdata  (m_axi_rdata),
      .m_axi_rresp  (m_axi_rresp),
      .m_axi_rlast  (m_axi_rlast),
      .m_axi_rvalid (m_axi_rvalid),
      .m_axi_rready (m_axi_rready),

      .enable(dma_enable)
  );

  // ------------------------------------------------------------
  // flow_ctrl instance
  // ------------------------------------------------------------
  wire cmd_init, cmd_next, cmd_last, cmd_ready;

  flow_ctrl #(
      .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
      .LEN_WIDTH     (LEN_WIDTH),
      .TAG_WIDTH     (TAG_WIDTH),
      .ERR_WIDTH     (ERR_WIDTH)
  ) u_flow_ctrl (
      .clk  (clk),
      .rst_n(rst_n),

      .sha_sof_i (sha_sof_pulse_reg),
      .blk_base_i(blk_base_reg[AXI_ADDR_WIDTH-1:0]),
      .blk_len_i (blk_len_reg[LEN_WIDTH-1:0]),
      .sha_busy_o(sha_busy),

      .cmd_init_o    (cmd_init),
      .cmd_next_o    (cmd_next),
      .cmd_last_o    (cmd_last),
      .cmd_ready_i   (cmd_ready),
      .digest_valid_i(digest_valid),

      // to axi_dma_rd desc
      .m_axis_read_desc_addr_o (dma_desc_addr),
      .m_axis_read_desc_len_o  (dma_desc_len),
      .m_axis_read_desc_tag_o  (dma_desc_tag),
      .m_axis_read_desc_valid_o(dma_desc_valid),
      .m_axis_read_desc_ready_i(dma_desc_ready),

      // from axi_dma_rd status
      .s_axis_read_desc_status_tag_i  (dma_status_tag),
      .s_axis_read_desc_status_error_i(dma_status_error),
      .s_axis_read_desc_status_valid_i(dma_status_valid),

      // to axi_dma_rd
      .axi_dma_rd_enable_o(dma_enable)
  );

  // ------------------------------------------------------------
  // sha256_core instance
  // ------------------------------------------------------------
  sha256_core u_sha256_core (
      .clk  (clk),
      .rst_n(rst_n),

      .cmd_valid_init(cmd_init),
      .cmd_valid_next(cmd_next),
      .cmd_last      (cmd_last),
      .cmd_ready     (cmd_ready),

      .s_axis_tdata (axis_read_data_tdata[31:0]),
      .s_axis_tvalid(axis_read_data_tvalid),
      .s_axis_tlast (axis_read_data_tlast),
      .s_axis_tready(axis_read_data_tready),

      .digest      (digest),
      .digest_valid(digest_valid)
  );

endmodule
