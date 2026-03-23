module axi_dma_wr #(
    parameter AXI_DATA_WIDTH    = 32,
    parameter AXI_ADDR_WIDTH    = 32,
    parameter AXI_MAX_BURST_LEN = 16,
    parameter AXIS_DATA_WIDTH   = AXI_DATA_WIDTH,
    parameter AXIS_LAST_ENABLE  = 1,
    parameter LEN_WIDTH         = 20
) (
    input wire clk,
    input wire rst_n,

    // 写描述符：目的地址/长度
    input  wire [AXI_ADDR_WIDTH-1:0] s_axis_write_desc_addr,
    input  wire [     LEN_WIDTH-1:0] s_axis_write_desc_len,
    input  wire                      s_axis_write_desc_valid,
    output wire                      s_axis_write_desc_ready,

    // 写完成状态
    output wire [3:0] m_axis_write_desc_status_error,
    output wire       m_axis_write_desc_status_valid,

    // AXIS 写数据输入
    input  wire [AXIS_DATA_WIDTH-1:0] s_axis_write_data_tdata,
    input  wire                       s_axis_write_data_tvalid,
    output wire                       s_axis_write_data_tready,
    input  wire                       s_axis_write_data_tlast,   // 当前版本不使用

    // AXI 写通道
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
    output wire       m_axi_bready,

    input wire enable
);

  parameter AXI_BURST_SIZE = $clog2(AXI_DATA_WIDTH / 8);
  parameter AXI_MAX_BURST_SIZE = AXI_MAX_BURST_LEN << AXI_BURST_SIZE;

  localparam [3:0] DMA_ERROR_NONE = 4'd0;

  // descriptor / burst regs
  reg [AXI_ADDR_WIDTH-1:0] addr_reg, addr_next;
  reg [LEN_WIDTH-1:0] op_bytes_count_reg, op_bytes_count_next;
  reg [LEN_WIDTH-1:0] tr_bytes_count_reg, tr_bytes_count_next;

  reg [15:0] burst_beats_reg, burst_beats_next;
  reg burst_last_desc_reg, burst_last_desc_next;

  // FSM
  localparam [2:0] ST_IDLE = 3'd0;
  localparam [2:0] ST_ISSUE = 3'd1;  // 发 AW（保持到握手）
  localparam [2:0] ST_W = 3'd2;  // 送 WDATA
  localparam [2:0] ST_B = 3'd3;  // 等 BRESP
  localparam [2:0] ST_DONE = 3'd4;  // 打一拍 status

  reg [2:0] state_reg, state_next;

  // outputs regs
  reg s_axis_write_desc_ready_reg, s_axis_write_desc_ready_next;

  reg [3:0] m_axis_write_desc_status_error_reg, m_axis_write_desc_status_error_next;
  reg m_axis_write_desc_status_valid_reg, m_axis_write_desc_status_valid_next;

  reg [AXI_ADDR_WIDTH-1:0] m_axi_awaddr_reg, m_axi_awaddr_next;
  reg [7:0] m_axi_awlen_reg, m_axi_awlen_next;
  reg m_axi_awvalid_reg, m_axi_awvalid_next;

  reg [AXI_DATA_WIDTH-1:0] m_axi_wdata_reg, m_axi_wdata_next;
  reg [AXI_DATA_WIDTH/8-1:0] m_axi_wstrb_reg, m_axi_wstrb_next;
  reg m_axi_wlast_reg, m_axi_wlast_next;
  reg m_axi_wvalid_reg, m_axi_wvalid_next;

  reg m_axi_bready_reg, m_axi_bready_next;

  assign s_axis_write_desc_ready        = s_axis_write_desc_ready_reg;
  assign m_axis_write_desc_status_error = m_axis_write_desc_status_error_reg;
  assign m_axis_write_desc_status_valid = m_axis_write_desc_status_valid_reg;

  assign m_axi_awaddr                   = m_axi_awaddr_reg;
  assign m_axi_awlen                    = m_axi_awlen_reg;
  assign m_axi_awsize                   = AXI_BURST_SIZE[2:0];
  assign m_axi_awburst                  = 2'b01;
  assign m_axi_awvalid                  = m_axi_awvalid_reg;

  assign m_axi_wdata                    = m_axi_wdata_reg;
  assign m_axi_wstrb                    = m_axi_wstrb_reg;
  assign m_axi_wlast                    = m_axi_wlast_reg;
  assign m_axi_wvalid                   = m_axi_wvalid_reg;

  assign m_axi_bready                   = m_axi_bready_reg;

  // input fifo
  parameter INPUT_FIFO_ADDR_WIDTH = 5;

  reg [INPUT_FIFO_ADDR_WIDTH:0] in_fifo_wr_ptr_reg;
  reg [INPUT_FIFO_ADDR_WIDTH:0] in_fifo_rd_ptr_reg;
  reg in_fifo_half_full_reg;

  wire in_fifo_full = in_fifo_wr_ptr_reg == (in_fifo_rd_ptr_reg ^ {1'b1, {INPUT_FIFO_ADDR_WIDTH{1'b0}}});
  wire in_fifo_empty = in_fifo_wr_ptr_reg == in_fifo_rd_ptr_reg;

  (* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
  reg [AXIS_DATA_WIDTH-1:0] in_fifo_tdata[2**INPUT_FIFO_ADDR_WIDTH-1:0];

  wire [AXIS_DATA_WIDTH-1:0] in_fifo_dout = in_fifo_tdata[in_fifo_rd_ptr_reg[INPUT_FIFO_ADDR_WIDTH-1:0]];
  wire [INPUT_FIFO_ADDR_WIDTH:0] in_fifo_level = $unsigned(in_fifo_wr_ptr_reg - in_fifo_rd_ptr_reg);

  assign s_axis_write_data_tready = !in_fifo_half_full_reg;

  // handshake
  wire aw_hs = m_axi_awvalid_reg && m_axi_awready;
  wire w_hs = m_axi_wvalid_reg && m_axi_wready;
  wire b_hs = m_axi_bready_reg && m_axi_bvalid;

  // main FSM comb
  always @(*) begin
    state_next                          = state_reg;

    s_axis_write_desc_ready_next        = 1'b0;

    // hold valid until handshake
    m_axi_awaddr_next                   = m_axi_awaddr_reg;
    m_axi_awlen_next                    = m_axi_awlen_reg;
    m_axi_awvalid_next                  = m_axi_awvalid_reg && !m_axi_awready;

    m_axi_wdata_next                    = m_axi_wdata_reg;
    m_axi_wstrb_next                    = {AXI_DATA_WIDTH / 8{1'b1}};
    m_axi_wlast_next                    = 1'b0;
    m_axi_wvalid_next                   = m_axi_wvalid_reg && !m_axi_wready;

    m_axi_bready_next                   = 1'b0;

    m_axis_write_desc_status_error_next = m_axis_write_desc_status_error_reg;
    m_axis_write_desc_status_valid_next = 1'b0;

    addr_next                           = addr_reg;
    op_bytes_count_next                 = op_bytes_count_reg;
    tr_bytes_count_next                 = tr_bytes_count_reg;
    burst_beats_next                    = burst_beats_reg;
    burst_last_desc_next                = burst_last_desc_reg;

    case (state_reg)
      ST_IDLE: begin
        s_axis_write_desc_ready_next = enable;
        if (s_axis_write_desc_valid && s_axis_write_desc_ready) begin
          addr_next                           = s_axis_write_desc_addr;
          op_bytes_count_next                 = s_axis_write_desc_len + 1;  // bytes
          // clear status/error for this descriptor
          m_axis_write_desc_status_error_next = DMA_ERROR_NONE;
          state_next                          = ST_ISSUE;
        end
      end

      ST_ISSUE: begin
        // 如果 AW 还没拉起，就计算本 burst 并拉起 AWVALID
        if (!m_axi_awvalid_reg) begin
          // calc tr_bytes_count (<=4KB boundary, <=AXI_MAX_BURST_SIZE)
          if (op_bytes_count_reg <= AXI_MAX_BURST_SIZE) begin
            if (((addr_reg & 12'hfff) + (op_bytes_count_reg & 12'hfff)) >> 12 != 0
                || op_bytes_count_reg >> 12 != 0) begin
              tr_bytes_count_next = 13'h1000 - (addr_reg & 12'hfff);
            end else begin
              tr_bytes_count_next = op_bytes_count_reg;
            end
          end else begin
            if (((addr_reg & 12'hfff) + AXI_MAX_BURST_SIZE) >> 12 != 0) begin
              tr_bytes_count_next = 13'h1000 - (addr_reg & 12'hfff);
            end else begin
              tr_bytes_count_next = AXI_MAX_BURST_SIZE;
            end
          end

          m_axi_awaddr_next    = addr_reg;
          m_axi_awlen_next     = (tr_bytes_count_next - 1) >> AXI_BURST_SIZE;
          m_axi_awvalid_next   = 1'b1;

          // prepare burst bookkeeping (will be used after AW handshake)
          burst_beats_next     = m_axi_awlen_next + 1;
          addr_next            = addr_reg + tr_bytes_count_next;
          op_bytes_count_next  = op_bytes_count_reg - tr_bytes_count_next;
          burst_last_desc_next = (op_bytes_count_next == 0);
        end

        // 等真实 aw_hs 发生后，才进入送 W
        if (aw_hs) begin
          state_next = ST_W;
        end
      end

      ST_W: begin
        // 只有当 FIFO 有数据时才送 W；wvalid 需保持到 wready
        if (!in_fifo_empty) begin
          if (!m_axi_wvalid_reg) begin
            m_axi_wdata_next  = in_fifo_dout;
            m_axi_wvalid_next = 1'b1;
            m_axi_wlast_next  = (burst_beats_reg == 1);
          end

          if (w_hs) begin
            burst_beats_next = burst_beats_reg - 1;
            if (burst_beats_reg == 1) begin
              state_next = ST_B;
            end
          end
        end
      end

      ST_B: begin
        m_axi_bready_next = 1'b1;
        if (b_hs) begin
          if (m_axi_bresp != 2'b00) begin
            m_axis_write_desc_status_error_next = 4'd1;
          end
          if (burst_last_desc_reg) begin
            m_axis_write_desc_status_valid_next = 1'b1;  // 1T
            state_next = ST_DONE;
          end else begin
            state_next = ST_ISSUE;
          end
        end
      end

      ST_DONE: begin
        state_next = ST_IDLE;
      end

      default: state_next = ST_IDLE;
    endcase
  end

  // regs
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state_reg                          <= ST_IDLE;

      s_axis_write_desc_ready_reg        <= 1'b0;

      m_axis_write_desc_status_error_reg <= DMA_ERROR_NONE;
      m_axis_write_desc_status_valid_reg <= 1'b0;

      m_axi_awaddr_reg                   <= {AXI_ADDR_WIDTH{1'b0}};
      m_axi_awlen_reg                    <= 8'd0;
      m_axi_awvalid_reg                  <= 1'b0;

      m_axi_wdata_reg                    <= {AXI_DATA_WIDTH{1'b0}};
      m_axi_wstrb_reg                    <= {AXI_DATA_WIDTH / 8{1'b1}};
      m_axi_wlast_reg                    <= 1'b0;
      m_axi_wvalid_reg                   <= 1'b0;

      m_axi_bready_reg                   <= 1'b0;

      addr_reg                           <= {AXI_ADDR_WIDTH{1'b0}};
      op_bytes_count_reg                 <= {LEN_WIDTH{1'b0}};
      tr_bytes_count_reg                 <= {LEN_WIDTH{1'b0}};
      burst_beats_reg                    <= 16'd0;
      burst_last_desc_reg                <= 1'b0;

      in_fifo_wr_ptr_reg                 <= 'd0;
      in_fifo_rd_ptr_reg                 <= 'd0;
      in_fifo_half_full_reg              <= 1'b0;

    end else begin
      state_reg                          <= state_next;

      s_axis_write_desc_ready_reg        <= s_axis_write_desc_ready_next;

      m_axis_write_desc_status_error_reg <= m_axis_write_desc_status_error_next;
      m_axis_write_desc_status_valid_reg <= m_axis_write_desc_status_valid_next;

      m_axi_awaddr_reg                   <= m_axi_awaddr_next;
      m_axi_awlen_reg                    <= m_axi_awlen_next;
      m_axi_awvalid_reg                  <= m_axi_awvalid_next;

      m_axi_wdata_reg                    <= m_axi_wdata_next;
      m_axi_wstrb_reg                    <= m_axi_wstrb_next;
      m_axi_wlast_reg                    <= m_axi_wlast_next;
      m_axi_wvalid_reg                   <= m_axi_wvalid_next;

      m_axi_bready_reg                   <= m_axi_bready_next;

      addr_reg                           <= addr_next;
      op_bytes_count_reg                 <= op_bytes_count_next;
      tr_bytes_count_reg                 <= tr_bytes_count_next;
      burst_beats_reg                    <= burst_beats_next;
      burst_last_desc_reg                <= burst_last_desc_next;

      // fifo half-full
      in_fifo_half_full_reg              <= (in_fifo_level >= 2 ** (INPUT_FIFO_ADDR_WIDTH - 1));

      // push
      if (!in_fifo_full && s_axis_write_data_tvalid && s_axis_write_data_tready) begin
        in_fifo_tdata[in_fifo_wr_ptr_reg[INPUT_FIFO_ADDR_WIDTH-1:0]] <= s_axis_write_data_tdata;
        in_fifo_wr_ptr_reg <= in_fifo_wr_ptr_reg + 1;
      end

      // pop on w_hs
      if (!in_fifo_empty && w_hs) begin
        in_fifo_rd_ptr_reg <= in_fifo_rd_ptr_reg + 1;
      end
    end
  end

endmodule
