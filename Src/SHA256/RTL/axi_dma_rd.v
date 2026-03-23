`define SHA256_SWAP_ENDIAN

module axi_dma_rd #(
    parameter AXI_DATA_WIDTH = 32,
    parameter AXI_ADDR_WIDTH = 32,
    parameter AXI_MAX_BURST_LEN = 16,
    parameter AXIS_DATA_WIDTH = AXI_DATA_WIDTH,
    parameter AXIS_LAST_ENABLE = 1,
    parameter LEN_WIDTH = 20,
    parameter TAG_WIDTH = 8
) (
    input wire clk,
    input wire rst_n,

    input  wire [AXI_ADDR_WIDTH-1:0] s_axis_read_desc_addr,
    input  wire [     LEN_WIDTH-1:0] s_axis_read_desc_len,
    input  wire [     TAG_WIDTH-1:0] s_axis_read_desc_tag,
    input  wire                      s_axis_read_desc_valid,
    output wire                      s_axis_read_desc_ready,

    output wire [TAG_WIDTH-1:0] m_axis_read_desc_status_tag,
    output wire [          3:0] m_axis_read_desc_status_error,
    output wire                 m_axis_read_desc_status_valid,

    output wire [AXIS_DATA_WIDTH-1:0] m_axis_read_data_tdata,
    output wire                       m_axis_read_data_tvalid,
    input  wire                       m_axis_read_data_tready,
    output wire                       m_axis_read_data_tlast,

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

    input wire enable
);

  // ------------------------------------------------------------
  // Endian control (32-bit only)
  // Define SHA256_SWAP_ENDIAN to swap bytes in each 32-bit beat
  // ------------------------------------------------------------
  function automatic [31:0] bswap32(input [31:0] x);
    begin
      bswap32 = {x[7:0], x[15:8], x[23:16], x[31:24]};
    end
  endfunction

  wire [31:0] axi_rdata_endian;
`ifdef SHA256_SWAP_ENDIAN
  assign axi_rdata_endian = bswap32(m_axi_rdata);
`else
  assign axi_rdata_endian = m_axi_rdata;
`endif

  parameter AXI_WORD_WIDTH = 4;
  parameter AXI_WORD_SIZE = 8;
  parameter AXIS_WORD_WIDTH = 8;
  parameter AXIS_WORD_SIZE = AXIS_DATA_WIDTH / 8;

  parameter AXI_BURST_SIZE = $clog2(AXI_DATA_WIDTH / 8);
  parameter AXI_MAX_BURST_SIZE = AXI_MAX_BURST_LEN << AXI_BURST_SIZE;

  parameter CYCLE_COUNT_WIDTH = LEN_WIDTH - AXI_BURST_SIZE + 1;
  parameter OUTPUT_FIFO_ADDR_WIDTH = 5;

  localparam [3:0] DMA_ERROR_NONE = 4'd0;

  localparam [0:0] AXI_STATE_IDLE = 1'd0, AXI_STATE_START = 1'd1;
  reg [0:0] axi_state_reg = AXI_STATE_IDLE, axi_state_next;

  localparam [0:0] AXIS_STATE_IDLE = 1'd0, AXIS_STATE_READ = 1'd1;
  reg [0:0] axis_state_reg = AXIS_STATE_IDLE, axis_state_next;


  reg axis_cmd_ready;

  reg [AXI_ADDR_WIDTH-1:0] addr_reg = {AXI_ADDR_WIDTH{1'b0}}, addr_next;
  // 该 descriptor 剩余要传的字节数
  reg [LEN_WIDTH-1:0] op_bytes_count_reg = {LEN_WIDTH{1'b0}}, op_bytes_count_next;
  // 本次 burst 所读取的字节数。
  reg [LEN_WIDTH-1:0] tr_bytes_count_reg = {LEN_WIDTH{1'b0}}, tr_bytes_count_next;

  // 需要多少拍 AXI RDATA 进来
  reg [CYCLE_COUNT_WIDTH-1:0]
      axis_cmd_input_cycle_count_reg = {CYCLE_COUNT_WIDTH{1'b0}}, axis_cmd_input_cycle_count_next;
  // AXIS 最终要吐出多少拍
  reg [CYCLE_COUNT_WIDTH-1:0]
      axis_cmd_output_cycle_count_reg = {CYCLE_COUNT_WIDTH{1'b0}}, axis_cmd_output_cycle_count_next;

  reg [TAG_WIDTH-1:0] axis_cmd_tag_reg = {TAG_WIDTH{1'b0}}, axis_cmd_tag_next;
  // 表示当前是否有一条有效的 axis 命令在等着执行
  reg axis_cmd_valid_reg = 1'b0, axis_cmd_valid_next;

  reg [CYCLE_COUNT_WIDTH-1:0] input_cycle_count_reg = {CYCLE_COUNT_WIDTH{1'b0}}, input_cycle_count_next;
  reg [CYCLE_COUNT_WIDTH-1:0] output_cycle_count_reg = {CYCLE_COUNT_WIDTH{1'b0}}, output_cycle_count_next;
  reg input_active_reg = 1'b0, input_active_next;
  reg output_active_reg = 1'b0, output_active_next;
  reg first_cycle_reg = 1'b0, first_cycle_next;
  reg output_last_cycle_reg = 1'b0, output_last_cycle_next;

  reg [TAG_WIDTH-1:0] tag_reg = {TAG_WIDTH{1'b0}}, tag_next;

  reg s_axis_read_desc_ready_reg = 1'b0, s_axis_read_desc_ready_next;
  reg [TAG_WIDTH-1:0] m_axis_read_desc_status_tag_reg = {TAG_WIDTH{1'b0}}, m_axis_read_desc_status_tag_next;
  reg [3:0] m_axis_read_desc_status_error_reg = 4'd0, m_axis_read_desc_status_error_next;
  reg m_axis_read_desc_status_valid_reg = 1'b0, m_axis_read_desc_status_valid_next;
  reg [AXI_ADDR_WIDTH-1:0] m_axi_araddr_reg = {AXI_ADDR_WIDTH{1'b0}}, m_axi_araddr_next;
  reg [7:0] m_axi_arlen_reg = 8'd0, m_axi_arlen_next;
  reg m_axi_arvalid_reg = 1'b0, m_axi_arvalid_next;
  reg m_axi_rready_reg = 1'b0, m_axi_rready_next;

  reg [AXIS_DATA_WIDTH-1:0] m_axis_read_data_tdata_int;
  reg m_axis_read_data_tvalid_int;
  wire m_axis_read_data_tready_int;
  reg m_axis_read_data_tlast_int;


  assign s_axis_read_desc_ready        = s_axis_read_desc_ready_reg;
  assign m_axis_read_desc_status_tag   = m_axis_read_desc_status_tag_reg;
  assign m_axis_read_desc_status_error = m_axis_read_desc_status_error_reg;
  assign m_axis_read_desc_status_valid = m_axis_read_desc_status_valid_reg;
  assign m_axi_araddr                  = m_axi_araddr_reg;
  assign m_axi_arlen                   = m_axi_arlen_reg;
  assign m_axi_arsize                  = AXI_BURST_SIZE[2:0];
  assign m_axi_arburst                 = 2'b01;
  assign m_axi_arvalid                 = m_axi_arvalid_reg;
  assign m_axi_rready                  = m_axi_rready_reg;

  // 将 descriptor 信息拆成 AXI 读请求
  always @(*) begin
    axi_state_next = AXI_STATE_IDLE;
    s_axis_read_desc_ready_next = 1'b0;
    m_axi_araddr_next = m_axi_araddr_reg;
    m_axi_arlen_next = m_axi_arlen_reg;

    // 只要 AR 还没被对方接收，就一直保持 valid 为 1
    m_axi_arvalid_next = m_axi_arvalid_reg && !m_axi_arready;

    addr_next = addr_reg;
    op_bytes_count_next = op_bytes_count_reg;
    tr_bytes_count_next = tr_bytes_count_reg;

    axis_cmd_input_cycle_count_next = axis_cmd_input_cycle_count_reg;
    axis_cmd_output_cycle_count_next = axis_cmd_output_cycle_count_reg;
    axis_cmd_tag_next = axis_cmd_tag_reg;
    axis_cmd_valid_next = axis_cmd_valid_reg && !axis_cmd_ready;

    case (axi_state_reg)
      AXI_STATE_IDLE: begin
        s_axis_read_desc_ready_next = !axis_cmd_valid_reg && enable;
        if (s_axis_read_desc_valid && s_axis_read_desc_ready) begin
          addr_next = s_axis_read_desc_addr;
          axis_cmd_tag_next = s_axis_read_desc_tag;
          op_bytes_count_next = s_axis_read_desc_len;
          axis_cmd_input_cycle_count_next = (op_bytes_count_next - 1) >> AXI_BURST_SIZE;
          axis_cmd_output_cycle_count_next = (op_bytes_count_next - 1) >> AXI_BURST_SIZE;
          axis_cmd_valid_next = 1'b1;
          s_axis_read_desc_ready_next = 1'b0;
          axi_state_next = AXI_STATE_START;
        end else begin
          axi_state_next = AXI_STATE_IDLE;
        end
      end

      AXI_STATE_START: begin
        if (!m_axi_arvalid_reg) begin
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

          m_axi_araddr_next = addr_reg;
          m_axi_arlen_next = (tr_bytes_count_next - 1) >> AXI_BURST_SIZE;
          m_axi_arvalid_next = 1'b1;

          addr_next = addr_reg + tr_bytes_count_next;
          op_bytes_count_next = op_bytes_count_reg - tr_bytes_count_next;

          if (op_bytes_count_next > 0) begin
            axi_state_next = AXI_STATE_START;
          end else begin
            s_axis_read_desc_ready_next = !axis_cmd_valid_reg && enable;
            axi_state_next = AXI_STATE_IDLE;
          end
        end else begin
          axi_state_next = AXI_STATE_START;
        end
      end
    endcase
  end

  // 接收 AXI 读数据，输出到 AXIS
  always @(*) begin
    axis_state_next                    = AXIS_STATE_IDLE;

    m_axis_read_desc_status_tag_next   = m_axis_read_desc_status_tag_reg;
    m_axis_read_desc_status_error_next = m_axis_read_desc_status_error_reg;
    m_axis_read_desc_status_valid_next = 1'b0;

    m_axis_read_data_tdata_int         = axi_rdata_endian;
    m_axis_read_data_tlast_int         = 1'b0;
    m_axis_read_data_tvalid_int        = 1'b0;

    m_axi_rready_next                  = 1'b0;

    axis_cmd_ready                     = 1'b0;

    input_cycle_count_next             = input_cycle_count_reg;
    output_cycle_count_next            = output_cycle_count_reg;
    input_active_next                  = input_active_reg;
    output_active_next                 = output_active_reg;
    first_cycle_next                   = first_cycle_reg;
    output_last_cycle_next             = output_last_cycle_reg;

    tag_next                           = tag_reg;

    case (axis_state_reg)
      AXIS_STATE_IDLE: begin
        m_axi_rready_next = 1'b0;
        input_cycle_count_next = axis_cmd_input_cycle_count_reg;
        output_cycle_count_next = axis_cmd_output_cycle_count_reg;
        tag_next = axis_cmd_tag_reg;
        output_last_cycle_next = 0;

        input_active_next = 1'b1;
        output_active_next = 1'b1;
        first_cycle_next = 1'b1;
        if (axis_cmd_valid_reg) begin
          axis_cmd_ready = 1'b1;
          m_axi_rready_next = m_axis_read_data_tready_int;
          axis_state_next = AXIS_STATE_READ;
        end
      end
      AXIS_STATE_READ: begin
        m_axi_rready_next = m_axis_read_data_tready_int && input_active_reg;
        if (m_axi_rready && m_axi_rvalid) begin
          if (input_active_reg) begin
            if (input_cycle_count_reg == 0) begin
              input_active_next = 1'b0;
            end else begin
              input_cycle_count_next = input_cycle_count_reg - 1;
              input_active_next      = 1'b1;
            end
          end
          if (output_active_reg) begin
            if (output_cycle_count_reg == 0) begin
              output_active_next = 1'b0;
            end else begin
              output_cycle_count_next = output_cycle_count_reg - 1;
              output_active_next      = 1'b1;
            end
          end
          output_last_cycle_next      = output_cycle_count_next == 0;

          m_axis_read_data_tdata_int  = axi_rdata_endian;
          m_axis_read_data_tvalid_int = 1'b1;

          if (output_last_cycle_reg) begin
            m_axis_read_data_tlast_int = 1'b1;
            m_axis_read_desc_status_tag_next = tag_reg;
            m_axis_read_desc_status_error_next = DMA_ERROR_NONE;
            m_axis_read_desc_status_valid_next = 1'b1;
            m_axi_rready_next = 1'b0;
            axis_state_next = AXIS_STATE_IDLE;
          end else begin
            m_axi_rready_next = m_axis_read_data_tready_int && input_active_next;
            axis_state_next   = AXIS_STATE_READ;
          end
        end else begin
          axis_state_next = AXIS_STATE_READ;
        end
      end
    endcase
  end

  // 时序逻辑
  always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      axi_state_reg                     <= AXI_STATE_IDLE;
      axis_state_reg                    <= AXIS_STATE_IDLE;
      axis_cmd_valid_reg                <= 1'b0;
      s_axis_read_desc_ready_reg        <= 1'b0;
      m_axis_read_desc_status_valid_reg <= 1'b0;
      m_axi_arvalid_reg                 <= 1'b0;
      m_axi_rready_reg                  <= 1'b0;
    end else begin
      axi_state_reg                     <= axi_state_next;
      axis_state_reg                    <= axis_state_next;

      s_axis_read_desc_ready_reg        <= s_axis_read_desc_ready_next;

      m_axis_read_desc_status_tag_reg   <= m_axis_read_desc_status_tag_next;
      m_axis_read_desc_status_error_reg <= m_axis_read_desc_status_error_next;
      m_axis_read_desc_status_valid_reg <= m_axis_read_desc_status_valid_next;

      m_axi_araddr_reg                  <= m_axi_araddr_next;
      m_axi_arlen_reg                   <= m_axi_arlen_next;
      m_axi_arvalid_reg                 <= m_axi_arvalid_next;
      m_axi_rready_reg                  <= m_axi_rready_next;

      addr_reg                          <= addr_next;
      op_bytes_count_reg                <= op_bytes_count_next;
      tr_bytes_count_reg                <= tr_bytes_count_next;

      axis_cmd_input_cycle_count_reg    <= axis_cmd_input_cycle_count_next;
      axis_cmd_output_cycle_count_reg   <= axis_cmd_output_cycle_count_next;
      axis_cmd_tag_reg                  <= axis_cmd_tag_next;
      axis_cmd_valid_reg                <= axis_cmd_valid_next;

      input_cycle_count_reg             <= input_cycle_count_next;
      output_cycle_count_reg            <= output_cycle_count_next;
      input_active_reg                  <= input_active_next;
      output_active_reg                 <= output_active_next;
      first_cycle_reg                   <= first_cycle_next;
      output_last_cycle_reg             <= output_last_cycle_next;

      tag_reg                           <= tag_next;
    end
  end

  // 对外 AXIS master 的输出寄存器和输出 FIFO
  reg [AXIS_DATA_WIDTH-1:0] m_axis_read_data_tdata_reg = {AXIS_DATA_WIDTH{1'b0}};
  reg m_axis_read_data_tvalid_reg = 1'b0;
  reg m_axis_read_data_tlast_reg = 1'b0;

  reg [OUTPUT_FIFO_ADDR_WIDTH+1-1:0] out_fifo_wr_ptr_reg = 0;
  reg [OUTPUT_FIFO_ADDR_WIDTH+1-1:0] out_fifo_rd_ptr_reg = 0;
  reg out_fifo_half_full_reg = 1'b0;

  wire out_fifo_full = out_fifo_wr_ptr_reg == (out_fifo_rd_ptr_reg ^ {1'b1, {OUTPUT_FIFO_ADDR_WIDTH{1'b0}}});
  wire out_fifo_empty = out_fifo_wr_ptr_reg == out_fifo_rd_ptr_reg;

  (* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
  reg [AXIS_DATA_WIDTH-1:0] out_fifo_tdata[2**OUTPUT_FIFO_ADDR_WIDTH-1:0];

  (* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
  reg out_fifo_tlast[2**OUTPUT_FIFO_ADDR_WIDTH-1:0];

  assign m_axis_read_data_tready_int = !out_fifo_half_full_reg;
  assign m_axis_read_data_tdata = m_axis_read_data_tdata_reg;
  assign m_axis_read_data_tvalid = m_axis_read_data_tvalid_reg;
  assign m_axis_read_data_tlast = AXIS_LAST_ENABLE ? m_axis_read_data_tlast_reg : 1'b1;

  always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      out_fifo_wr_ptr_reg         <= 0;
      out_fifo_rd_ptr_reg         <= 0;
      m_axis_read_data_tvalid_reg <= 1'b0;
    end else begin
      m_axis_read_data_tvalid_reg <= m_axis_read_data_tvalid_reg && !m_axis_read_data_tready;

      out_fifo_half_full_reg <= $unsigned(
          out_fifo_wr_ptr_reg - out_fifo_rd_ptr_reg
      ) >= 2 ** (OUTPUT_FIFO_ADDR_WIDTH - 1);

      if (!out_fifo_full && m_axis_read_data_tvalid_int) begin
        out_fifo_tdata[out_fifo_wr_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]] <= m_axis_read_data_tdata_int;
        out_fifo_tlast[out_fifo_wr_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]] <= m_axis_read_data_tlast_int;
        out_fifo_wr_ptr_reg <= out_fifo_wr_ptr_reg + 1;
      end

      if (!out_fifo_empty && (!m_axis_read_data_tvalid_reg || m_axis_read_data_tready)) begin
        m_axis_read_data_tvalid_reg <= 1'b1;
        m_axis_read_data_tdata_reg <= out_fifo_tdata[out_fifo_rd_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]];
        m_axis_read_data_tlast_reg <= out_fifo_tlast[out_fifo_rd_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]];
        out_fifo_rd_ptr_reg <= out_fifo_rd_ptr_reg + 1;
      end
    end
  end
endmodule
