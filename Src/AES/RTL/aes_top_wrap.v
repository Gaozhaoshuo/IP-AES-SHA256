module aes_top_wrap (
    // APB
    input  wire         psel,
    input  wire         penable,
    input  wire [7:0]   paddr,
    input  wire         pwrite,
    input  wire [31:0]  pwdata,
    output wire         pready,
    output wire [31:0]  prdata,

    // AXI (tb/axi32_slave_model 期望的“完整版”)
    input  wire [3:0]   arid,
    output wire [31:0]  araddr,
    output wire [7:0]   arlen,
    output wire [2:0]   arsize,
    output wire [1:0]   arburst,
    output wire [1:0]   arlock,
    output wire [3:0]   arcache,
    output wire [2:0]   arprot,
    output wire         arvalid,
    input  wire         arready,

    output wire [3:0]   rid,
    input  wire [31:0]  rdata,
    input  wire [1:0]   rresp,
    input  wire         rlast,
    input  wire         rvalid,
    output wire         rready,

    input  wire [3:0]   awid,
    output wire [31:0]  awaddr,
    output wire [7:0]   awlen,
    output wire [2:0]   awsize,
    output wire [1:0]   awburst,
    output wire [1:0]   awlock,
    output wire [3:0]   awcache,
    output wire [2:0]   awprot,
    output wire         awvalid,
    input  wire         awready,

    input  wire [3:0]   wid,
    output wire [31:0]  wdata,
    output wire [3:0]   wstrb,
    output wire         wlast,
    output wire         wvalid,
    input  wire         wready,

    output wire [3:0]   bid,
    input  wire [1:0]   bresp,
    input  wire         bvalid,
    output wire         bready,

    output wire         intr,
    input  wire         clk,
    input  wire         rstn
);

  // -----------------------------
  // tie-off signals DUT 不用管的
  // -----------------------------
  assign arlock  = 2'b00;
  assign arcache = 4'b0000;
  assign arprot  = 3'b000;

  assign awlock  = 2'b00;
  assign awcache = 4'b0000;
  assign awprot  = 3'b000;

  // -----------------------------
  // 处理 ID：axi32_slave_model 会用 rid/bid
  // 简化 aes_top 没有 id，所以 wrapper 自己记住最近一次的 id
  // -----------------------------
  reg [3:0] arid_q, awid_q;

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      arid_q <= 4'd0;
      awid_q <= 4'd0;
    end else begin
      if (arvalid && arready) arid_q <= arid;
      if (awvalid && awready) awid_q <= awid;
    end
  end

  assign rid = arid_q;
  assign bid = awid_q;

  // -----------------------------
  // 实例化你现在的“简化版 aes_top”
  // -----------------------------
  aes_top u_aes_top (
      .clk     (clk),
      .rst_n   (rstn),

      // APB
      .psel    (psel),
      .penable (penable),
      .paddr   (paddr),
      .pwrite  (pwrite),
      .pwdata  (pwdata),
      .pready  (pready),
      .prdata  (prdata),
      .intr    (intr),

      // AXI READ
      .m_axi_araddr  (araddr),
      .m_axi_arlen   (arlen),
      .m_axi_arsize  (arsize),
      .m_axi_arburst (arburst),
      .m_axi_arvalid (arvalid),
      .m_axi_arready (arready),
      .m_axi_rdata   (rdata),
      .m_axi_rresp   (rresp),
      .m_axi_rlast   (rlast),
      .m_axi_rvalid  (rvalid),
      .m_axi_rready  (rready),

      // AXI WRITE
      .m_axi_awaddr  (awaddr),
      .m_axi_awlen   (awlen),
      .m_axi_awsize  (awsize),
      .m_axi_awburst (awburst),
      .m_axi_awvalid (awvalid),
      .m_axi_awready (awready),

      .m_axi_wdata   (wdata),
      .m_axi_wstrb   (wstrb),
      .m_axi_wlast   (wlast),
      .m_axi_wvalid  (wvalid),
      .m_axi_wready  (wready),

      .m_axi_bresp   (bresp),
      .m_axi_bvalid  (bvalid),
      .m_axi_bready  (bready)
  );

endmodule
