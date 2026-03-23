module aes_top #(
    parameter APB_ADDR_WIDTH = 8,
    parameter APB_DATA_WIDTH = 32,

    parameter AXI_ADDR_WIDTH = 32,
    parameter AXI_DATA_WIDTH = 32,
    parameter LEN_WIDTH      = 20,
    parameter TAG_WIDTH      = 8
) (
    input wire clk,
    input wire rst_n,

    // -------------------------
    // APB slave
    // -------------------------
    input  wire                      psel,
    input  wire                      penable,
    input  wire [APB_ADDR_WIDTH-1:0] paddr,
    input  wire                      pwrite,
    input  wire [APB_DATA_WIDTH-1:0] pwdata,
    output wire                      pready,
    output wire [APB_DATA_WIDTH-1:0] prdata,
    output wire                      intr,

    // -------------------------
    // AXI master READ (AR/R)
    // -------------------------
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

    // -------------------------
    // AXI master WRITE (AW/W/B)
    // -------------------------
    output wire [AXI_ADDR_WIDTH-1:0] m_axi_awaddr,
    output wire [               7:0] m_axi_awlen,
    output wire [               2:0] m_axi_awsize,
    output wire [               1:0] m_axi_awburst,
    output wire                      m_axi_awvalid,
    input  wire                      m_axi_awready,

    output wire [  AXI_DATA_WIDTH-1:0] m_axi_wdata,
    output wire [AXI_DATA_WIDTH/8-1:0] m_axi_wstrb,
    output wire                        m_axi_wlast,
    output wire                        m_axi_wvalid,
    input  wire                        m_axi_wready,

    input  wire [1:0] m_axi_bresp,
    input  wire       m_axi_bvalid,
    output wire       m_axi_bready
);

  // ------------------------------------------------------------
  // cfg wires
  // ------------------------------------------------------------
  wire         cfg_key_gen;
  wire         cfg_blk_sof;
  wire [ 31:0] cfg_blk_base;
  wire [ 31:0] cfg_blk_len;
  wire [ 31:0] cfg_code_base;
  wire         cfg_enc_dec;
  wire [  1:0] cfg_blk_mode;
  wire [  1:0] cfg_key_len;
  wire [255:0] cfg_key;
  wire [127:0] cfg_iv;

  wire         set_blk_end;

  aes_cfg #(
      .APB_ADDR_WIDTH(APB_ADDR_WIDTH),
      .APB_DATA_WIDTH(APB_DATA_WIDTH)
  ) u_cfg (
      .clk          (clk),
      .rst_n        (rst_n),
      .psel         (psel),
      .penable      (penable),
      .paddr        (paddr),
      .pwrite       (pwrite),
      .pwdata       (pwdata),
      .pready       (pready),
      .prdata       (prdata),
      .cfg_key_gen  (cfg_key_gen),
      .cfg_blk_sof  (cfg_blk_sof),
      .cfg_blk_base (cfg_blk_base),
      .cfg_blk_len  (cfg_blk_len),
      .cfg_code_base(cfg_code_base),
      .cfg_enc_dec  (cfg_enc_dec),
      .cfg_blk_mode (cfg_blk_mode),
      .cfg_key_len  (cfg_key_len),
      .cfg_key      (cfg_key),
      .cfg_iv       (cfg_iv),
      .set_blk_end  (set_blk_end),
      .intr         (intr)
  );

  // ------------------------------------------------------------
  // flow ctrl <-> dma desc
  // ------------------------------------------------------------
  wire [AXI_ADDR_WIDTH-1:0] rd_desc_addr;
  wire [     LEN_WIDTH-1:0] rd_desc_len;
  wire [     TAG_WIDTH-1:0] rd_desc_tag;
  wire                      rd_desc_valid;
  wire                      rd_desc_ready;
  wire [               3:0] rd_desc_status_error;
  wire                      rd_desc_status_valid;

  wire [AXI_ADDR_WIDTH-1:0] wr_desc_addr;
  wire [     LEN_WIDTH-1:0] wr_desc_len;
  wire                      wr_desc_valid;
  wire                      wr_desc_ready;
  wire [               3:0] wr_desc_status_error;
  wire                      wr_desc_status_valid;

  // ------------------------------------------------------------
  // DMA-RD AXIS -> ibuf
  // ------------------------------------------------------------
  wire [              31:0] rd_axis_tdata;
  wire                      rd_axis_tvalid;
  wire                      rd_axis_tready;
  wire                      rd_axis_tlast;

  axi_dma_rd #(
      .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
      .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
      .LEN_WIDTH     (LEN_WIDTH),
      .TAG_WIDTH     (TAG_WIDTH)
  ) u_dma_rd (
      .clk  (clk),
      .rst_n(rst_n),

      .s_axis_read_desc_addr (rd_desc_addr),
      .s_axis_read_desc_len  (rd_desc_len),
      .s_axis_read_desc_tag  (rd_desc_tag),
      .s_axis_read_desc_valid(rd_desc_valid),
      .s_axis_read_desc_ready(rd_desc_ready),

      .m_axis_read_desc_status_tag  (),
      .m_axis_read_desc_status_error(rd_desc_status_error),
      .m_axis_read_desc_status_valid(rd_desc_status_valid),

      .m_axis_read_data_tdata (rd_axis_tdata),
      .m_axis_read_data_tvalid(rd_axis_tvalid),
      .m_axis_read_data_tready(rd_axis_tready),
      .m_axis_read_data_tlast (rd_axis_tlast),

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

      .enable(1'b1)
  );

  // ibuf: 32->128 pack + fifo
  wire [127:0] ibuf_block;
  wire         ibuf_valid;
  wire         ibuf_full;
  wire         ibuf_empty;
  wire         ibuf_pop;

  axis32_to_block128 u_ibuf (
      .clk  (clk),
      .rst_n(rst_n),

      .s_axis_tdata (rd_axis_tdata),
      .s_axis_tvalid(rd_axis_tvalid),
      .s_axis_tready(rd_axis_tready),
      .s_axis_tlast (rd_axis_tlast),

      .m_block_data (ibuf_block),
      .m_block_valid(ibuf_valid),
      .m_block_pop  (ibuf_pop),

      .ibuf_full (ibuf_full),
      .ibuf_empty(ibuf_empty)
  );

  // ------------------------------------------------------------
  // AES core
  // ------------------------------------------------------------
  wire         aes_encdec;
  wire [127:0] aes_iv;
  wire         aes_init;
  wire         aes_next;
  wire         aes_first_blk;
  wire [  1:0] aes_blk_mode;
  wire [255:0] aes_key_in;
  wire [  1:0] aes_key_len;
  wire         key_ready;

  wire [127:0] aes_result;
  wire         aes_result_valid;

  aes_core u_aes_core (
      .clk  (clk),
      .rst_n(rst_n),

      .encdec   (aes_encdec),
      .iv       (aes_iv),
      .init     (aes_init),
      .next     (aes_next),
      .first_blk(aes_first_blk),
      .blk_mode (aes_blk_mode),

      .key_ready(key_ready),
      .key_in   (aes_key_in),
      .key_len  (aes_key_len),

      .block       (ibuf_block),
      .result      (aes_result),
      .result_valid(aes_result_valid)
  );

  // ------------------------------------------------------------
  // obuf: 128->32 + fifo -> DMA-WR
  // ------------------------------------------------------------
  wire        obuf_full;
  wire        obuf_empty;

  wire [31:0] wr_axis_tdata;
  wire        wr_axis_tvalid;
  wire        wr_axis_tready;
  wire        wr_axis_tlast;

  block128_to_axis32 u_obuf (
      .clk  (clk),
      .rst_n(rst_n),

      .s_block_data (aes_result),
      .s_block_valid(aes_result_valid),
      .s_block_ready(),              

      .m_axis_tdata (wr_axis_tdata),
      .m_axis_tvalid(wr_axis_tvalid),
      .m_axis_tready(wr_axis_tready),
      .m_axis_tlast (wr_axis_tlast),

      .obuf_full (obuf_full),
      .obuf_empty(obuf_empty)
  );

  // DMA-WR
  axi_dma_wr #(
      .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
      .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
      .LEN_WIDTH     (LEN_WIDTH)
  ) u_dma_wr (
      .clk  (clk),
      .rst_n(rst_n),

      .s_axis_write_desc_addr (wr_desc_addr),
      .s_axis_write_desc_len  (wr_desc_len),
      .s_axis_write_desc_valid(wr_desc_valid),
      .s_axis_write_desc_ready(wr_desc_ready),

      .m_axis_write_desc_status_error(wr_desc_status_error),
      .m_axis_write_desc_status_valid(wr_desc_status_valid),

      .s_axis_write_data_tdata (wr_axis_tdata),
      .s_axis_write_data_tvalid(wr_axis_tvalid),
      .s_axis_write_data_tready(wr_axis_tready),
      .s_axis_write_data_tlast (wr_axis_tlast),

      .m_axi_awaddr (m_axi_awaddr),
      .m_axi_awlen  (m_axi_awlen),
      .m_axi_awsize (m_axi_awsize),
      .m_axi_awburst(m_axi_awburst),
      .m_axi_awvalid(m_axi_awvalid),
      .m_axi_awready(m_axi_awready),

      .m_axi_wdata (m_axi_wdata),
      .m_axi_wstrb (m_axi_wstrb),
      .m_axi_wlast (m_axi_wlast),
      .m_axi_wvalid(m_axi_wvalid),
      .m_axi_wready(m_axi_wready),

      .m_axi_bresp (m_axi_bresp),
      .m_axi_bvalid(m_axi_bvalid),
      .m_axi_bready(m_axi_bready),

      .enable(1'b1)
  );

  // ------------------------------------------------------------
  // flow ctrl
  // ------------------------------------------------------------
  aes_flow_ctrl #(
      .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
      .LEN_WIDTH     (LEN_WIDTH),
      .TAG_WIDTH     (TAG_WIDTH)
  ) u_flow (
      .clk  (clk),
      .rst_n(rst_n),

      .cfg_key_gen  (cfg_key_gen),
      .cfg_blk_sof  (cfg_blk_sof),
      .cfg_blk_base (cfg_blk_base),
      .cfg_blk_len  (cfg_blk_len),
      .cfg_code_base(cfg_code_base),
      .cfg_enc_dec  (cfg_enc_dec),
      .cfg_blk_mode (cfg_blk_mode),
      .cfg_key_len  (cfg_key_len),
      .cfg_key      (cfg_key),
      .cfg_iv       (cfg_iv),

      .set_blk_end(set_blk_end),

      .rd_desc_addr        (rd_desc_addr),
      .rd_desc_len         (rd_desc_len),
      .rd_desc_tag         (rd_desc_tag),
      .rd_desc_valid       (rd_desc_valid),
      .rd_desc_ready       (rd_desc_ready),
      .rd_desc_status_error(rd_desc_status_error),
      .rd_desc_status_valid(rd_desc_status_valid),

      .wr_desc_addr        (wr_desc_addr),
      .wr_desc_len         (wr_desc_len),
      .wr_desc_valid       (wr_desc_valid),
      .wr_desc_ready       (wr_desc_ready),
      .wr_desc_status_error(wr_desc_status_error),
      .wr_desc_status_valid(wr_desc_status_valid),

      .ibuf_pop  (ibuf_pop),
      .ibuf_empty(ibuf_empty),

      .obuf_full(obuf_full),

      .aes_encdec      (aes_encdec),
      .aes_iv          (aes_iv),
      .aes_init        (aes_init),
      .aes_next        (aes_next),
      .key_ready       (key_ready),
      .aes_first_blk   (aes_first_blk),
      .aes_blk_mode    (aes_blk_mode),
      .aes_key_in      (aes_key_in),
      .aes_key_len     (aes_key_len),
      .aes_result_valid(aes_result_valid)
  );

endmodule
