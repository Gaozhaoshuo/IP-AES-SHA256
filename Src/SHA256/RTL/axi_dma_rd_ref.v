`resetall `timescale 1ns / 1ps `default_nettype none

/*
 * AXI4 DMA
 */
module axi_dma_rd #(
    // Width of AXI data bus in bits
    parameter AXI_DATA_WIDTH = 32,
    // Width of AXI address bus in bits
    parameter AXI_ADDR_WIDTH = 16,
    // Width of AXI wstrb (width of data bus in words)
    parameter AXI_STRB_WIDTH = (AXI_DATA_WIDTH / 8),

    // // Width of AXI ID signal
    // parameter AXI_ID_WIDTH = 8,

    // Maximum AXI burst length to generate
    parameter AXI_MAX_BURST_LEN = 16,

    // Width of AXI stream interfaces in bits
    parameter AXIS_DATA_WIDTH = AXI_DATA_WIDTH,
    // Use AXI stream tkeep signal
    parameter AXIS_KEEP_ENABLE = (AXIS_DATA_WIDTH > 8),
    // AXI stream tkeep signal width (words per cycle)
    parameter AXIS_KEEP_WIDTH = (AXIS_DATA_WIDTH / 8),
    // Use AXI stream tlast signal
    parameter AXIS_LAST_ENABLE = 1,
    // Propagate AXI stream tid signal
    parameter AXIS_ID_ENABLE = 0,
    // AXI stream tid signal width
    parameter AXIS_ID_WIDTH = 8,
    // Propagate AXI stream tdest signal
    parameter AXIS_DEST_ENABLE = 0,
    // AXI stream tdest signal width
    parameter AXIS_DEST_WIDTH = 8,
    // Propagate AXI stream tuser signal
    parameter AXIS_USER_ENABLE = 1,
    // AXI stream tuser signal width
    parameter AXIS_USER_WIDTH = 1,

    // Width of length field
    parameter LEN_WIDTH = 20,
    // Width of tag field
    parameter TAG_WIDTH = 8,
    // Enable support for scatter/gather DMA
    // (multiple descriptors per AXI stream frame)
    parameter ENABLE_UNALIGNED = 0
) (
    input wire clk,
    input wire rst_n,

    /*
     * AXI read descriptor input
     */
    input  wire [AXI_ADDR_WIDTH-1:0] s_axis_read_desc_addr,
    input  wire [     LEN_WIDTH-1:0] s_axis_read_desc_len,
    input  wire [     TAG_WIDTH-1:0] s_axis_read_desc_tag,
    // input  wire [AXIS_ID_WIDTH-1:0]   s_axis_read_desc_id,
    // input  wire [AXIS_DEST_WIDTH-1:0] s_axis_read_desc_dest,
    // input  wire [AXIS_USER_WIDTH-1:0] s_axis_read_desc_user,
    input  wire                      s_axis_read_desc_valid,
    output wire                      s_axis_read_desc_ready,

    /*
     * AXI read descriptor status output
     */
    output wire [TAG_WIDTH-1:0] m_axis_read_desc_status_tag,
    output wire [          3:0] m_axis_read_desc_status_error,
    output wire                 m_axis_read_desc_status_valid,

    /*
     * AXI stream read data output
     */
    output wire [AXIS_DATA_WIDTH-1:0] m_axis_read_data_tdata,
    output wire [AXIS_KEEP_WIDTH-1:0] m_axis_read_data_tkeep,
    output wire                       m_axis_read_data_tvalid,
    input  wire                       m_axis_read_data_tready,
    output wire                       m_axis_read_data_tlast,
    // output wire [AXIS_ID_WIDTH-1:0]   m_axis_read_data_tid,
    // output wire [AXIS_DEST_WIDTH-1:0] m_axis_read_data_tdest,
    // output wire [AXIS_USER_WIDTH-1:0] m_axis_read_data_tuser,

    /*
     * AXI master interface
     */
    // output wire [AXI_ID_WIDTH-1:0]    m_axi_arid,
    output wire [AXI_ADDR_WIDTH-1:0] m_axi_araddr,
    output wire [               7:0] m_axi_arlen,
    output wire [               2:0] m_axi_arsize,
    output wire [               1:0] m_axi_arburst,
    // output wire                       m_axi_arlock,
    // output wire [3:0]                 m_axi_arcache,
    // output wire [2:0]                 m_axi_arprot,
    output wire                      m_axi_arvalid,
    input  wire                      m_axi_arready,
    // input  wire [AXI_ID_WIDTH-1:0]    m_axi_rid,
    input  wire [AXI_DATA_WIDTH-1:0] m_axi_rdata,
    input  wire [               1:0] m_axi_rresp,
    input  wire                      m_axi_rlast,
    input  wire                      m_axi_rvalid,
    // RVALID 由 slave 发
    // RREADY 由 master 发
    // 只有 RVALID && RREADY 才代表“这一拍的读数据被 master 接收”
    output wire                      m_axi_rready,

    /*
     * 简单的“停机/复位”控制,在 enable=1 时才会接受新的描述符、进行传输。
     */
    input wire enable
);

  // AXI 一拍有多少 word（个人理解：一个 word 在这里就是一个 byte_lane）
  parameter AXI_WORD_WIDTH = AXI_STRB_WIDTH;
  // 每个 word 的 bit 数
  parameter AXI_WORD_SIZE = AXI_DATA_WIDTH / AXI_WORD_WIDTH;
  // AXI 协议里的 arsize 是“每个 beat 的字节数”的 log2
  parameter AXI_BURST_SIZE = $clog2(AXI_STRB_WIDTH);
  // 最大突发能覆盖的总字节数
  parameter AXI_MAX_BURST_SIZE = AXI_MAX_BURST_LEN << AXI_BURST_SIZE;

  // 如果启用了 tkeep，AXIS_KEEP_WIDTH 就是字节数；否则是1
  parameter AXIS_KEEP_WIDTH_INT = AXIS_KEEP_ENABLE ? AXIS_KEEP_WIDTH : 1;
  // AXIS 一拍有多少 word（通常就是多少字节）
  parameter AXIS_WORD_WIDTH = AXIS_KEEP_WIDTH_INT;
  // 每个 word 的 bit 数
  parameter AXIS_WORD_SIZE = AXIS_DATA_WIDTH / AXIS_WORD_WIDTH;

  // OFFSET_WIDTH = 用多少位来表示 “这个 beat 里第几个 byte”
  parameter OFFSET_WIDTH = AXI_STRB_WIDTH > 1 ? $clog2(AXI_STRB_WIDTH) : 1;
  // OFFSET_MASK = 一个全 1 的掩码，用来把 offset 保持在合法范围内（0~STRB_WIDTH-1）
  parameter OFFSET_MASK = AXI_STRB_WIDTH > 1 ? {OFFSET_WIDTH{1'b1}} : 0;
  // ADDR_MASK 用来屏蔽掉 AXI 地址低位，使地址永远保持 beat 对齐。例如 32bit AXI 需要对齐到 4 字节
  parameter ADDR_MASK = {AXI_ADDR_WIDTH{1'b1}} << $clog2(AXI_STRB_WIDTH);
  // CYCLE_COUNT_WIDTH 是 “一次 burst 需要读多少 beat（拍）” 的位宽。
  // LEN 通常表示需要读取的总字节数，位宽 = LEN_WIDTH，且每拍能读 AXI_STRB_WIDTH 个 byte，
  // 因此，burst 要读 cycle_count = LEN / AXI_STRB_WIDTH 个拍，
  // LEN 最大约等于 2^LEN_WIDTH，除以 AXI_STRB_WIDTH(=2^AXI_BURST_SIZE)
  // 则整数部分的最大值大约为：2^LEN_WIDTH / 2^AXI_BURST_SIZE = 2^(LEN_WIDTH - AXI_BURST_SIZE)
  // 为了计满，还需要多 1 位，因此最终 CYCLE_COUNT_WIDTH = LEN_WIDTH - AXI_BURST_SIZE + 1
  parameter CYCLE_COUNT_WIDTH = LEN_WIDTH - AXI_BURST_SIZE + 1;
  // 输出缓冲深度，地址 5 位 => 深度 2^5 =` 32
  parameter OUTPUT_FIFO_ADDR_WIDTH = 5;

  // bus width assertions
  initial begin
    if (AXI_WORD_SIZE * AXI_STRB_WIDTH != AXI_DATA_WIDTH) begin
      $error("Error: AXI data width not evenly divisble (instance %m)");
      $finish;
    end

    if (AXIS_WORD_SIZE * AXIS_KEEP_WIDTH_INT != AXIS_DATA_WIDTH) begin
      $error("Error: AXI stream data width not evenly divisble (instance %m)");
      $finish;
    end

    if (AXI_WORD_SIZE != AXIS_WORD_SIZE) begin
      $error("Error: word size mismatch (instance %m)");
      $finish;
    end

    // 要求 AXI_WORD_WIDTH（字节数）必须是 2 的幂
    if (2 ** $clog2(AXI_WORD_WIDTH) != AXI_WORD_WIDTH) begin
      $error("Error: AXI word width must be even power of two (instance %m)");
      $finish;
    end

    if (AXI_DATA_WIDTH != AXIS_DATA_WIDTH) begin
      $error("Error: AXI interface width must match AXI stream interface width (instance %m)");
      $finish;
    end

    if (AXI_MAX_BURST_LEN < 1 || AXI_MAX_BURST_LEN > 256) begin
      $error("Error: AXI_MAX_BURST_LEN must be between 1 and 256 (instance %m)");
      $finish;
    end
  end

  localparam [1:0] AXI_RESP_OKAY = 2'b00, AXI_RESP_EXOKAY = 2'b01, AXI_RESP_SLVERR = 2'b10, AXI_RESP_DECERR = 2'b11;

  localparam [3:0]
        DMA_ERROR_NONE              = 4'd0,
        DMA_ERROR_TIMEOUT           = 4'd1,
        DMA_ERROR_PARITY            = 4'd2,
        DMA_ERROR_AXI_RD_SLVERR     = 4'd4,
        DMA_ERROR_AXI_RD_DECERR     = 4'd5,
        DMA_ERROR_AXI_WR_SLVERR     = 4'd6,
        DMA_ERROR_AXI_WR_DECERR     = 4'd7,
        DMA_ERROR_PCIE_FLR          = 4'd8,
        DMA_ERROR_PCIE_CPL_POISONED = 4'd9,
        DMA_ERROR_PCIE_CPL_STATUS_UR= 4'd10,
        DMA_ERROR_PCIE_CPL_STATUS_CA= 4'd11;

  // AXI 状态机：负责“从内存拉数据”（发 AR）
  localparam [0:0] AXI_STATE_IDLE = 1'd0, AXI_STATE_START = 1'd1;

  reg [0:0] axi_state_reg = AXI_STATE_IDLE, axi_state_next;

  // AXIS 状态机：负责“往外面吐数据”（发 tdata/tlast）
  localparam [0:0] AXIS_STATE_IDLE = 1'd0, AXIS_STATE_READ = 1'd1;

  reg [0:0] axis_state_reg = AXIS_STATE_IDLE, axis_state_next;

  // datapath control signals

  // 表示本次传输需要把一拍 R 数据“存起来”以便下次拼接（用于非对齐场景）
  reg transfer_in_save;
  // 内部告诉 AXIS 命令队列“现在可以接受下一条命令”
  reg axis_cmd_ready;

  reg [AXI_ADDR_WIDTH-1:0] addr_reg = {AXI_ADDR_WIDTH{1'b0}}, addr_next;
  // 这条 descriptor 剩余要传的字节数（按 word 计数）
  reg [LEN_WIDTH-1:0] op_word_count_reg = {LEN_WIDTH{1'b0}}, op_word_count_next;
  // 表示本次 AXI AR 请求（一个 burst）所读取的字节数。
  reg [LEN_WIDTH-1:0] tr_word_count_reg = {LEN_WIDTH{1'b0}}, tr_word_count_next;

  /*
     * 可以把 axis_cmd_* 这一整坨看成 “AXIS 输出 state machine 的命令队列项”，
     * 描述一次完整 DMA 读操作在 AXIS 侧应如何输出：
     */

  // 操作开始时的地址字节偏移（地址低几位），用于决定第一拍的数据要从 R 数据的哪一个字节开始
  reg [OFFSET_WIDTH-1:0] axis_cmd_offset_reg = {OFFSET_WIDTH{1'b0}}, axis_cmd_offset_next;
  // 最后一拍结束时的偏移，用于决定最后一拍 tkeep 哪些字节有效。
  reg [OFFSET_WIDTH-1:0] axis_cmd_last_cycle_offset_reg = {OFFSET_WIDTH{1'b0}}, axis_cmd_last_cycle_offset_next;
  // 输入侧（R 通道）和输出侧（AXIS）各自需要多少个“cycle”（拍）来完成这次操作。
  // 两者可能不同：非对齐时会多出一个“bubble cycle”。
  // input_cycle_count：需要多少拍 AXI RDATA 进来（包括 bubble 那拍）。
  // output_cycle_count：AXIS 最终要吐出多少拍。
  reg [CYCLE_COUNT_WIDTH-1:0]
      axis_cmd_input_cycle_count_reg = {CYCLE_COUNT_WIDTH{1'b0}}, axis_cmd_input_cycle_count_next;
  reg [CYCLE_COUNT_WIDTH-1:0]
      axis_cmd_output_cycle_count_reg = {CYCLE_COUNT_WIDTH{1'b0}}, axis_cmd_output_cycle_count_next;
  // 是否存在一个 “bubble cycle”
  reg axis_cmd_bubble_cycle_reg = 1'b0, axis_cmd_bubble_cycle_next;
  // 把输入 descriptor 里的 tag / id / dest / user 存下来
  reg [TAG_WIDTH-1:0] axis_cmd_tag_reg = {TAG_WIDTH{1'b0}}, axis_cmd_tag_next;
  // reg [AXIS_ID_WIDTH-1:0] axis_cmd_axis_id_reg = {AXIS_ID_WIDTH{1'b0}}, axis_cmd_axis_id_next;
  // reg [AXIS_DEST_WIDTH-1:0] axis_cmd_axis_dest_reg = {AXIS_DEST_WIDTH{1'b0}}, axis_cmd_axis_dest_next;
  // reg [AXIS_USER_WIDTH-1:0] axis_cmd_axis_user_reg = {AXIS_USER_WIDTH{1'b0}}, axis_cmd_axis_user_next;
  // 表示当前是否有一条有效的 axis 命令在等着执行
  reg axis_cmd_valid_reg = 1'b0, axis_cmd_valid_next;

  // 当 AXIS 状态机 真正开始干活 时，会把 axis_cmd_* 里的信息搬到这些寄存器中：
  reg [OFFSET_WIDTH-1:0] offset_reg = {OFFSET_WIDTH{1'b0}}, offset_next;
  reg [OFFSET_WIDTH-1:0] last_cycle_offset_reg = {OFFSET_WIDTH{1'b0}}, last_cycle_offset_next;
  reg [CYCLE_COUNT_WIDTH-1:0] input_cycle_count_reg = {CYCLE_COUNT_WIDTH{1'b0}}, input_cycle_count_next;
  reg [CYCLE_COUNT_WIDTH-1:0] output_cycle_count_reg = {CYCLE_COUNT_WIDTH{1'b0}}, output_cycle_count_next;
  reg input_active_reg = 1'b0, input_active_next;
  reg output_active_reg = 1'b0, output_active_next;
  reg bubble_cycle_reg = 1'b0, bubble_cycle_next;
  reg first_cycle_reg = 1'b0, first_cycle_next;
  reg output_last_cycle_reg = 1'b0, output_last_cycle_next;
  reg [1:0] rresp_reg = AXI_RESP_OKAY, rresp_next;
  // 当前 descriptor 的 tag / id / dest / user
  reg [TAG_WIDTH-1:0] tag_reg = {TAG_WIDTH{1'b0}}, tag_next;
  // reg [AXIS_ID_WIDTH-1:0] axis_id_reg = {AXIS_ID_WIDTH{1'b0}}, axis_id_next;
  // reg [AXIS_DEST_WIDTH-1:0] axis_dest_reg = {AXIS_DEST_WIDTH{1'b0}}, axis_dest_next;
  // reg [AXIS_USER_WIDTH-1:0] axis_user_reg = {AXIS_USER_WIDTH{1'b0}}, axis_user_next;

  reg s_axis_read_desc_ready_reg = 1'b0, s_axis_read_desc_ready_next;

  // descriptor 状态输出寄存器
  reg [TAG_WIDTH-1:0] m_axis_read_desc_status_tag_reg = {TAG_WIDTH{1'b0}}, m_axis_read_desc_status_tag_next;
  reg [3:0] m_axis_read_desc_status_error_reg = 4'd0, m_axis_read_desc_status_error_next;
  reg m_axis_read_desc_status_valid_reg = 1'b0, m_axis_read_desc_status_valid_next;

  // AXI AR/R 通道相关寄存器
  reg [AXI_ADDR_WIDTH-1:0] m_axi_araddr_reg = {AXI_ADDR_WIDTH{1'b0}}, m_axi_araddr_next;
  reg [7:0] m_axi_arlen_reg = 8'd0, m_axi_arlen_next;
  reg m_axi_arvalid_reg = 1'b0, m_axi_arvalid_next;
  reg m_axi_rready_reg = 1'b0, m_axi_rready_next;

  // 保存“上一拍 R 通道数据”的寄存器
  // 非对齐时，一部分有效数据可能在前一拍尾部，
  // 另一部分在后一拍头部，这时需要拼接这两拍，所以要存一份
  reg [AXI_DATA_WIDTH-1:0] save_axi_rdata_reg = {AXI_DATA_WIDTH{1'b0}};

  // {m_axi_rdata, save_axi_rdata_reg}：高位是当前拍数据，低位是上一拍数据。
  // 右移 ((AXI_STRB_WIDTH-offset_reg)*AXI_WORD_SIZE) bit：
  // AXI_STRB_WIDTH = 一拍多少字节；
  // offset_reg = 我们希望的“从第几个字节开始对齐输出”；
  // 所以 (AXI_STRB_WIDTH - offset_reg) = 要跳过的字节数；
  // 再乘上 AXI_WORD_SIZE（每字节的 bit 数）=> 要跳过这么多 bit。
  // 移完之后的 shift_axi_rdata：已经把“跨拍的数据”对齐到低位，后面可以直接切片给 AXIS 输出。
  // 相当于把两拍 R 数据拼成一长串 → 向右挪对齐 → 低位开始就是我们要的有效流
  wire [AXI_DATA_WIDTH-1:0] shift_axi_rdata =
        {m_axi_rdata, save_axi_rdata_reg} >> ((AXI_STRB_WIDTH-offset_reg)*AXI_WORD_SIZE);

  // AXIS 内部数据通路（接到 FIFO 适配器前）
  // 后面会有一个 axis_fifo_adapter 把它接到真正的输出端口 m_axis_read_data_*，
  // 中间插一个 FIFO 做缓冲。
  reg [AXIS_DATA_WIDTH-1:0] m_axis_read_data_tdata_int;
  reg [AXIS_KEEP_WIDTH-1:0] m_axis_read_data_tkeep_int;
  reg m_axis_read_data_tvalid_int;
  // tready_int 是 FIFO 反馈回来的 ready
  wire m_axis_read_data_tready_int;
  reg m_axis_read_data_tlast_int;
  // reg  [AXIS_ID_WIDTH-1:0]   m_axis_read_data_tid_int;
  // reg  [AXIS_DEST_WIDTH-1:0] m_axis_read_data_tdest_int;
  // reg  [AXIS_USER_WIDTH-1:0] m_axis_read_data_tuser_int;

  // 一些输出端口的 assign 连接：
  // 把前面那个 ready 寄存器接到外部端口
  assign s_axis_read_desc_ready        = s_axis_read_desc_ready_reg;
  // 状态输出三个信号的直接连接
  assign m_axis_read_desc_status_tag   = m_axis_read_desc_status_tag_reg;
  assign m_axis_read_desc_status_error = m_axis_read_desc_status_error_reg;
  assign m_axis_read_desc_status_valid = m_axis_read_desc_status_valid_reg;
  // AXI AR 端口输出：
  // assign m_axi_arid = {AXI_ID_WIDTH{1'b0}};
  assign m_axi_araddr                  = m_axi_araddr_reg;
  assign m_axi_arlen                   = m_axi_arlen_reg;
  assign m_axi_arsize                  = AXI_BURST_SIZE;
  assign m_axi_arburst                 = 2'b01;
  // assign m_axi_arlock = 1'b0;
  // assign m_axi_arcache = 4'b0011;
  // assign m_axi_arprot = 3'b010;
  assign m_axi_arvalid                 = m_axi_arvalid_reg;
  assign m_axi_rready                  = m_axi_rready_reg;

  /*
     * 这个 axi_state 状态机只干一件事：
     * 根据 desc(addr,len)，把一次大读请求拆成若干个不跨 4KB、长度不超过 AXI_MAX_BURST_LEN 的 AXI AR burst，
     * 同时在 支持 / 不支持非对齐 的情况下把地址和长度算对。
     * 跟 AXIS 对齐（bubble、shift）相关的参数（axis_cmd_offset/input_cycle_count/...）在 IDLE 态一起算好，
     * 后面 AXIS 那个状态机再按这些参数“把读出来的 beat 拼成对齐的 stream”
     */
  always @* begin
    axi_state_next                   = AXI_STATE_IDLE;

    s_axis_read_desc_ready_next      = 1'b0;

    m_axi_araddr_next                = m_axi_araddr_reg;
    m_axi_arlen_next                 = m_axi_arlen_reg;
    // 只要 AR 还没被对方接收，就一直保持 valid 为 1
    m_axi_arvalid_next               = m_axi_arvalid_reg && !m_axi_arready;

    addr_next                        = addr_reg;
    op_word_count_next               = op_word_count_reg;
    tr_word_count_next               = tr_word_count_reg;

    axis_cmd_offset_next             = axis_cmd_offset_reg;
    axis_cmd_last_cycle_offset_next  = axis_cmd_last_cycle_offset_reg;
    axis_cmd_input_cycle_count_next  = axis_cmd_input_cycle_count_reg;
    axis_cmd_output_cycle_count_next = axis_cmd_output_cycle_count_reg;
    axis_cmd_bubble_cycle_next       = axis_cmd_bubble_cycle_reg;
    axis_cmd_tag_next                = axis_cmd_tag_reg;
    // axis_cmd_axis_id_next = axis_cmd_axis_id_reg;
    // axis_cmd_axis_dest_next = axis_cmd_axis_dest_reg;
    // axis_cmd_axis_user_next = axis_cmd_axis_user_reg;
    // 把当前算好的 axis 命令保存住，等 AXIS 那边 ready 才清 0
    axis_cmd_valid_next              = axis_cmd_valid_reg && !axis_cmd_ready;

    case (axi_state_reg)
      // IDLE 状态：接收描述符、生成 axis_cmd_*
      AXI_STATE_IDLE: begin
        // 只有在 当前 axis_cmd 没在被 AXIS 使用（axis_cmd_valid_reg == 0）
        // 并且 enable=1 时才接新 descriptor。
        s_axis_read_desc_ready_next = !axis_cmd_valid_reg && enable;
        // 空闲时，AXI 端等着新描述符 (ready && valid)：
        if (s_axis_read_desc_ready && s_axis_read_desc_valid) begin
          if (ENABLE_UNALIGNED) begin
            addr_next = s_axis_read_desc_addr;
            axis_cmd_offset_next = AXI_STRB_WIDTH > 1 ? AXI_STRB_WIDTH - (s_axis_read_desc_addr & OFFSET_MASK) : 0;
            axis_cmd_bubble_cycle_next = axis_cmd_offset_next > 0;
            axis_cmd_last_cycle_offset_next = s_axis_read_desc_len & OFFSET_MASK;
          end else begin
            // ADDR_MASK 会把地址低几位清零 → 强制 AXI ARADDR 按 beat 对齐。
            addr_next                       = s_axis_read_desc_addr & ADDR_MASK;
            // AXI 读出来的每拍都是“纯净的连续数据”，不需要 bubble，不需要丢字节
            axis_cmd_offset_next            = 0;
            axis_cmd_bubble_cycle_next      = 1'b0;
            // 只有最后一拍可能尾巴不满，用 last_cycle_offset 控 tkeep 就够了
            axis_cmd_last_cycle_offset_next = s_axis_read_desc_len & OFFSET_MASK;
          end
          axis_cmd_tag_next  = s_axis_read_desc_tag;

          // op_word_count 初始值，它代表整个 DMA 读操作还剩多少“字节”没读
          op_word_count_next = s_axis_read_desc_len;

          // axis_cmd_axis_id_next = s_axis_read_desc_id;
          // axis_cmd_axis_dest_next = s_axis_read_desc_dest;
          // axis_cmd_axis_user_next = s_axis_read_desc_user;

          if (ENABLE_UNALIGNED) begin
            axis_cmd_input_cycle_count_next =
                            (op_word_count_next + (s_axis_read_desc_addr & OFFSET_MASK) - 1) >> AXI_BURST_SIZE;
          end else begin
            axis_cmd_input_cycle_count_next = (op_word_count_next - 1) >> AXI_BURST_SIZE;
          end
          axis_cmd_output_cycle_count_next = (op_word_count_next - 1) >> AXI_BURST_SIZE;

          axis_cmd_valid_next              = 1'b1;

          s_axis_read_desc_ready_next      = 1'b0;
          axi_state_next                   = AXI_STATE_START;
        end else begin
          axi_state_next = AXI_STATE_IDLE;
        end
      end

      AXI_STATE_START: begin
        // start state - initiate new AXI transfer
        if (!m_axi_arvalid) begin
          /*
                     *  op_word_count_reg <= AXI_MAX_BURST_SIZE - (addr_reg & OFFSET_MASK)
                     *  可以理解成：
                     *   在考虑了“起始地址不对齐多占用的一部分”之后，
                     *   整个剩余包能否塞进“max burst” 里。
                     *   如果能塞进去，就走“packet smaller than max burst size” 分支；
                     *   如果塞不进去，就走“packet larger than max burst size” 分支，把这个大包拆成多个 burst。
                     *  || AXI_MAX_BURST_SIZE >= 4096
                     *  相当于一个“特例兜底”：
                     *   如果 AXI_MAX_BURST_SIZE >= 4096（非常大的 burst），那不用看第一项了，
                     *   直接当作“包小于最大 burst size”处理。
                     *   因为 4KB 是 AXI 的一条硬约束（不能跨 4KB），当你允许的 burst 自己比 4KB 还大时，
                     *   实际生效的上限就是 4KB 边界，不需要再用 AXI_MAX_BURST_SIZE - offset 去约束。
                     */
          if (op_word_count_reg <= AXI_MAX_BURST_SIZE - (addr_reg & OFFSET_MASK) || AXI_MAX_BURST_SIZE >= 4096) begin
            // packet smaller than max burst size
            // 这次剩余数据整体可以在一个 burst 里搞定，但是要再看一下 4KB 边界。
            // 如果页内偏移 + 长度低 12bit 超过 4095，就会“冲出当前页” → 跨 4KB 边界。
            // 如果长度本身 >= 4096，那肯定跨不止一页。
            if (((addr_reg & 12'hfff) + (op_word_count_reg & 12'hfff)) >> 12 != 0 || op_word_count_reg >> 12 != 0) begin
              // crosses 4k boundary
              // 计算本页还能容纳的最大字节数
              tr_word_count_next = 13'h1000 - (addr_reg & 12'hfff);
            end else begin
              // does not cross 4k boundary
              tr_word_count_next = op_word_count_reg;
            end
          end else begin
            // packet larger than max burst size
            // 先假设想用满 AXI_MAX_BURST_SIZE，看看会不会跨 4KB
            if (((addr_reg & 12'hfff) + AXI_MAX_BURST_SIZE) >> 12 != 0) begin
              // crosses 4k boundary
              tr_word_count_next = 13'h1000 - (addr_reg & 12'hfff);
            end else begin
              // does not cross 4k boundary
              tr_word_count_next = AXI_MAX_BURST_SIZE - (addr_reg & OFFSET_MASK);
            end
          end

          m_axi_araddr_next = addr_reg;
          if (ENABLE_UNALIGNED) begin
            m_axi_arlen_next = (tr_word_count_next + (addr_reg & OFFSET_MASK) - 1) >> AXI_BURST_SIZE;
          end else begin
            m_axi_arlen_next = (tr_word_count_next - 1) >> AXI_BURST_SIZE;
          end
          m_axi_arvalid_next = 1'b1;

          // tr_word_count_next 直接决定 addr_next（下一个 burst 起始地址）
          addr_next = addr_reg + tr_word_count_next;

          // 每发一个 AR burst，就从剩余总字节里扣除“本次 burst 字节数”
          op_word_count_next = op_word_count_reg - tr_word_count_next;

          // 当 op_word_count_reg 变成 0 → DMA 整个读操作结束
          if (op_word_count_next > 0) begin
            axi_state_next = AXI_STATE_START;
          end else begin
            s_axis_read_desc_ready_next = !axis_cmd_valid_reg && enable;
            axi_state_next              = AXI_STATE_IDLE;
          end
        end else begin
          axi_state_next = AXI_STATE_START;
        end
      end
    endcase
  end

  /*
     * 下面的状态机可以理解成：
     * 把 AXI 读出来的一拍一拍 rdata，按照 axis_cmd 给出的对齐/长度要求，
     * 整理成一条连续的 AXI-Stream 数据，最后给一个“这次读完成”的 status。
     * 前面那个 axi_state 是“发 AR、算 burst 的 AXI 地址侧”，
     * 现在这个 axis_state 是“收 RDATA、变成 AXIS tdata 的数据侧”。
     * 从 axis_cmd_* 接收一次传输的“计划”（偏移、长度、需要多少拍、是否 bubble）。
     * 通过 shift_axi_rdata + offset + bubble_cycle 实现任意字节对齐：
     * 首拍（bubble）：只接收不输出，用来填充对齐缓冲。
     * 正常拍：从 {上一拍,当前拍} 里抽出正确的“连续字节”输出。
     * 通过 input_cycle_count / output_cycle_count 灵活处理：
     * 非对齐导致“输入/输出拍数不同”的情况。
     * 通过 last_cycle_offset + output_last_cycle 控制尾拍的 tkeep 和 tlast。
     * 累积 RRESP，把 AXI 错误信息转成 DMA status。
     */
  always @* begin
    axis_state_next                    = AXIS_STATE_IDLE;

    m_axis_read_desc_status_tag_next   = m_axis_read_desc_status_tag_reg;
    m_axis_read_desc_status_error_next = m_axis_read_desc_status_error_reg;
    m_axis_read_desc_status_valid_next = 1'b0;

    m_axis_read_data_tdata_int         = shift_axi_rdata;
    m_axis_read_data_tkeep_int         = {AXIS_KEEP_WIDTH{1'b1}};
    m_axis_read_data_tlast_int         = 1'b0;
    m_axis_read_data_tvalid_int        = 1'b0;
    // m_axis_read_data_tid_int = axis_id_reg;
    // m_axis_read_data_tdest_int = axis_dest_reg;
    // m_axis_read_data_tuser_int = axis_user_reg;

    m_axi_rready_next                  = 1'b0;

    transfer_in_save                   = 1'b0;
    axis_cmd_ready                     = 1'b0;

    offset_next                        = offset_reg;
    last_cycle_offset_next             = last_cycle_offset_reg;
    input_cycle_count_next             = input_cycle_count_reg;
    output_cycle_count_next            = output_cycle_count_reg;
    input_active_next                  = input_active_reg;
    output_active_next                 = output_active_reg;
    bubble_cycle_next                  = bubble_cycle_reg;
    first_cycle_next                   = first_cycle_reg;
    output_last_cycle_next             = output_last_cycle_reg;

    tag_next                           = tag_reg;
    // axis_id_next = axis_id_reg;
    // axis_dest_next = axis_dest_reg;
    // axis_user_next = axis_user_reg;

    if (m_axi_rready && m_axi_rvalid && (m_axi_rresp == AXI_RESP_SLVERR || m_axi_rresp == AXI_RESP_DECERR)) begin
      rresp_next = m_axi_rresp;
    end else begin
      rresp_next = rresp_reg;
    end

    case (axis_state_reg)
      AXIS_STATE_IDLE: begin
        // idle state - load new descriptor to start operation
        m_axi_rready_next = 1'b0;

        // store transfer parameters
        // 从 axis_cmd 寄存器里“装弹”
        if (ENABLE_UNALIGNED) begin
          offset_next = axis_cmd_offset_reg;
        end else begin
          offset_next = 0;
        end
        last_cycle_offset_next  = axis_cmd_last_cycle_offset_reg;
        input_cycle_count_next  = axis_cmd_input_cycle_count_reg;
        output_cycle_count_next = axis_cmd_output_cycle_count_reg;
        bubble_cycle_next       = axis_cmd_bubble_cycle_reg;
        tag_next                = axis_cmd_tag_reg;
        // axis_id_next = axis_cmd_axis_id_reg;
        // axis_dest_next = axis_cmd_axis_dest_reg;
        // axis_user_next = axis_cmd_axis_user_reg;

        output_last_cycle_next  = output_cycle_count_next == 0;

        // input_active：还需要从 AXI R 口接数据
        // output_active：还需要往 AXIS 口吐数据
        // first_cycle：标记“这是这次传输的第一个 cycle”，用来配合 bubble 判断。
        input_active_next       = 1'b1;
        output_active_next      = 1'b1;
        first_cycle_next        = 1'b1;

        if (axis_cmd_valid_reg) begin
          axis_cmd_ready = 1'b1;
          // 只有下游 AXIS 肯接（TREADY=1），才对上游 AXI 表示我准备好了（RREADY=1）
          m_axi_rready_next = m_axis_read_data_tready_int;
          axis_state_next = AXIS_STATE_READ;
        end
      end

      AXIS_STATE_READ: begin
        // handle AXI read data
        m_axi_rready_next = m_axis_read_data_tready_int && input_active_reg;

        // 情况一：RREADY && RVALID
        // → 真正收到一拍 RDATA，要处理（可能存入 save 寄存器）。
        // 情况二：!input_active_reg
        // → 即使上游不再给数据，输出那边可能还没吐完（例如非对齐情况下可能多一拍输出）。这时也需要更新输出计数等内部状态。
        if ((m_axi_rready && m_axi_rvalid) || !input_active_reg) begin
          // transfer in AXI read data
          // transfer_in_save 会在时序块里用来控制 save_axi_rdata_reg 是否更新
          transfer_in_save = m_axi_rready && m_axi_rvalid;

          if (ENABLE_UNALIGNED && first_cycle_reg && bubble_cycle_reg) begin
            if (input_active_reg) begin
              input_cycle_count_next = input_cycle_count_reg - 1;
              input_active_next      = input_cycle_count_reg > 0;
            end
            bubble_cycle_next = 1'b0;
            first_cycle_next  = 1'b0;

            m_axi_rready_next = m_axis_read_data_tready_int && input_active_next;
            axis_state_next   = AXIS_STATE_READ;
          end else begin
            // update counters
            if (input_active_reg) begin
              input_cycle_count_next = input_cycle_count_reg - 1;
              input_active_next      = input_cycle_count_reg > 0;
            end
            if (output_active_reg) begin
              output_cycle_count_next = output_cycle_count_reg - 1;
              output_active_next      = output_cycle_count_reg > 0;
            end
            output_last_cycle_next      = output_cycle_count_next == 0;
            bubble_cycle_next           = 1'b0;
            first_cycle_next            = 1'b0;

            // pass through read data
            m_axis_read_data_tdata_int  = shift_axi_rdata;
            m_axis_read_data_tkeep_int  = {AXIS_KEEP_WIDTH_INT{1'b1}};
            m_axis_read_data_tvalid_int = 1'b1;

            // 这拍是最后一个要输出的 AXIS beat
            if (output_last_cycle_reg) begin
              // no more data to transfer, finish operation
              // last_cycle_offset_reg 控制最后一拍有效的字节数
              if (last_cycle_offset_reg > 0) begin
                // 把全 1 的 tkeep 右移 (WIDTH - last_cycle_offset)
                m_axis_read_data_tkeep_int =
                                    {AXIS_KEEP_WIDTH_INT{1'b1}} >>
                                    (AXIS_KEEP_WIDTH_INT - last_cycle_offset_reg);
              end
              // 标识 AXIS 流尾
              m_axis_read_data_tlast_int = 1'b1;

              m_axis_read_desc_status_tag_next = tag_reg;
              if (rresp_next == AXI_RESP_SLVERR) begin
                m_axis_read_desc_status_error_next = DMA_ERROR_AXI_RD_SLVERR;
              end else if (rresp_next == AXI_RESP_DECERR) begin
                m_axis_read_desc_status_error_next = DMA_ERROR_AXI_RD_DECERR;
              end else begin
                m_axis_read_desc_status_error_next = DMA_ERROR_NONE;
              end
              m_axis_read_desc_status_valid_next = 1'b1;

              rresp_next = AXI_RESP_OKAY;

              // 不再要 RDATA：m_axi_rready_next = 0，状态回 IDLE，等待下一个 axis_cmd
              m_axi_rready_next = 1'b0;
              axis_state_next = AXIS_STATE_IDLE;
            end else begin
              // more cycles in AXI transfer
              m_axi_rready_next = m_axis_read_data_tready_int && input_active_next;
              axis_state_next   = AXIS_STATE_READ;
            end
          end
        end else begin
          axis_state_next = AXIS_STATE_READ;
        end
      end
    endcase
  end

  // 整个模块的“时序心脏”
  always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      axi_state_reg                     <= AXI_STATE_IDLE;
      axis_state_reg                    <= AXIS_STATE_IDLE;

      axis_cmd_valid_reg                <= 1'b0;

      s_axis_read_desc_ready_reg        <= 1'b0;

      m_axis_read_desc_status_valid_reg <= 1'b0;
      m_axi_arvalid_reg                 <= 1'b0;
      m_axi_rready_reg                  <= 1'b0;

      rresp_reg                         <= AXI_RESP_OKAY;
    end else begin
      axi_state_reg                     <= axi_state_next;
      axis_state_reg                    <= axis_state_next;

      // 输入 / 输出握手相关寄存器
      s_axis_read_desc_ready_reg        <= s_axis_read_desc_ready_next;

      m_axis_read_desc_status_tag_reg   <= m_axis_read_desc_status_tag_next;
      m_axis_read_desc_status_error_reg <= m_axis_read_desc_status_error_next;
      m_axis_read_desc_status_valid_reg <= m_axis_read_desc_status_valid_next;

      m_axi_araddr_reg                  <= m_axi_araddr_next;
      m_axi_arlen_reg                   <= m_axi_arlen_next;
      m_axi_arvalid_reg                 <= m_axi_arvalid_next;
      m_axi_rready_reg                  <= m_axi_rready_next;

      // 描述一次传输过程的“工作寄存器”
      addr_reg                          <= addr_next;
      op_word_count_reg                 <= op_word_count_next;
      tr_word_count_reg                 <= tr_word_count_next;

      // axis_cmd_*：从 AXI 地址侧 FSM 传给 AXIS 数据侧 FSM 的“命令”
      axis_cmd_offset_reg               <= axis_cmd_offset_next;
      axis_cmd_last_cycle_offset_reg    <= axis_cmd_last_cycle_offset_next;
      axis_cmd_input_cycle_count_reg    <= axis_cmd_input_cycle_count_next;
      axis_cmd_output_cycle_count_reg   <= axis_cmd_output_cycle_count_next;
      axis_cmd_bubble_cycle_reg         <= axis_cmd_bubble_cycle_next;
      axis_cmd_tag_reg                  <= axis_cmd_tag_next;
      // axis_cmd_axis_id_reg <= axis_cmd_axis_id_next;
      // axis_cmd_axis_dest_reg <= axis_cmd_axis_dest_next;
      // axis_cmd_axis_user_reg <= axis_cmd_axis_user_next;
      axis_cmd_valid_reg                <= axis_cmd_valid_next;

      // AXIS 状态机里的“运行时寄存器”
      offset_reg                        <= offset_next;
      last_cycle_offset_reg             <= last_cycle_offset_next;
      input_cycle_count_reg             <= input_cycle_count_next;
      output_cycle_count_reg            <= output_cycle_count_next;
      input_active_reg                  <= input_active_next;
      output_active_reg                 <= output_active_next;
      bubble_cycle_reg                  <= bubble_cycle_next;
      first_cycle_reg                   <= first_cycle_next;
      output_last_cycle_reg             <= output_last_cycle_next;
      rresp_reg                         <= rresp_next;

      tag_reg                           <= tag_next;
      // axis_id_reg <= axis_id_next;
      // axis_dest_reg <= axis_dest_next;
      // axis_user_reg <= axis_user_next;

      // RDATA 保存寄存器：save_axi_rdata_reg
      if (transfer_in_save) begin
        save_axi_rdata_reg <= m_axi_rdata;
      end
    end
  end

  // output datapath logic
  // 真正对外 AXIS master 的输出寄存器
  reg [AXIS_DATA_WIDTH-1:0] m_axis_read_data_tdata_reg = {AXIS_DATA_WIDTH{1'b0}};
  reg [AXIS_KEEP_WIDTH-1:0] m_axis_read_data_tkeep_reg = {AXIS_KEEP_WIDTH{1'b0}};
  reg m_axis_read_data_tvalid_reg = 1'b0;
  reg m_axis_read_data_tlast_reg = 1'b0;
  // reg [AXIS_ID_WIDTH-1:0]   m_axis_read_data_tid_reg    = {AXIS_ID_WIDTH{1'b0}};
  // reg [AXIS_DEST_WIDTH-1:0] m_axis_read_data_tdest_reg  = {AXIS_DEST_WIDTH{1'b0}};
  // reg [AXIS_USER_WIDTH-1:0] m_axis_read_data_tuser_reg  = {AXIS_USER_WIDTH{1'b0}};

  // 输出 FIFO 的结构：指针 & RAM
  // 写指针 & 读指针，位宽多 1 bit（OUTPUT_FIFO_ADDR_WIDTH+1）
  // 低 OUTPUT_FIFO_ADDR_WIDTH 位：索引 FIFO 深度（2^ADDR_WIDTH）
  // 最高位：用于区分“环绕”次数，方便判断 full/empty（“指针翻转”技巧）
  reg [OUTPUT_FIFO_ADDR_WIDTH+1-1:0] out_fifo_wr_ptr_reg = 0;
  reg [OUTPUT_FIFO_ADDR_WIDTH+1-1:0] out_fifo_rd_ptr_reg = 0;
  reg out_fifo_half_full_reg = 1'b0;

  // out_fifo_empty：读写指针完全相等 → 空。
  // out_fifo_full：写指针 == 读指针 高位取反、低位相等
  // → 典型环形 FIFO 判满方式：
  // 写指针比读指针正好“绕了一圈”。
  wire out_fifo_full = out_fifo_wr_ptr_reg == (out_fifo_rd_ptr_reg ^ {1'b1, {OUTPUT_FIFO_ADDR_WIDTH{1'b0}}});
  wire out_fifo_empty = out_fifo_wr_ptr_reg == out_fifo_rd_ptr_reg;

  // FIFO 存储体：
  (* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
  reg [AXIS_DATA_WIDTH-1:0] out_fifo_tdata[2**OUTPUT_FIFO_ADDR_WIDTH-1:0];
  (* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
  reg [AXIS_KEEP_WIDTH-1:0] out_fifo_tkeep[2**OUTPUT_FIFO_ADDR_WIDTH-1:0];
  (* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
  reg out_fifo_tlast[2**OUTPUT_FIFO_ADDR_WIDTH-1:0];
  // (* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
  // reg [AXIS_ID_WIDTH-1:0]   out_fifo_tid[2**OUTPUT_FIFO_ADDR_WIDTH-1:0];
  // (* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
  // reg [AXIS_DEST_WIDTH-1:0] out_fifo_tdest[2**OUTPUT_FIFO_ADDR_WIDTH-1:0];
  // (* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
  // reg [AXIS_USER_WIDTH-1:0] out_fifo_tuser[2**OUTPUT_FIFO_ADDR_WIDTH-1:0];

  // FIFO 填充阈值 & 给内部状态机的 tready_int
  // 这个 m_axis_read_data_tready_int 是给 内部 AXIS 状态机 用的 “tready 信号”：
  // 当 FIFO 没有“半满” → tready_int=1，内部 FSM 可以继续往 FIFO 写数据。
  assign m_axis_read_data_tready_int = !out_fifo_half_full_reg;

  assign m_axis_read_data_tdata = m_axis_read_data_tdata_reg;
  assign m_axis_read_data_tkeep = AXIS_KEEP_ENABLE ? m_axis_read_data_tkeep_reg : {AXIS_KEEP_WIDTH{1'b1}};
  assign m_axis_read_data_tvalid = m_axis_read_data_tvalid_reg;
  assign m_axis_read_data_tlast = AXIS_LAST_ENABLE ? m_axis_read_data_tlast_reg : 1'b1;
  // assign m_axis_read_data_tid    = AXIS_ID_ENABLE   ? m_axis_read_data_tid_reg   : {AXIS_ID_WIDTH{1'b0}};
  // assign m_axis_read_data_tdest  = AXIS_DEST_ENABLE ? m_axis_read_data_tdest_reg : {AXIS_DEST_WIDTH{1'b0}};
  // assign m_axis_read_data_tuser  = AXIS_USER_ENABLE ? m_axis_read_data_tuser_reg : {AXIS_USER_WIDTH{1'b0}};

  always @(posedge clk) begin
    // 先处理输出 valid 的自保持：如果当前有效数据还没被对方接走（tvalid=1 且 tready=0） → 保持 valid=1。
    // 一旦 tready=1，这一条会让 tvalid_reg 在下一拍变 0（除非下面又重新赋值为 1）。
    // 注意因为用的是非阻塞赋值，下面读 FIFO 那段如果也把 tvalid_reg 设为 1，就会“覆盖”掉这个值（同一个时钟沿，同一个寄存器，最后一次赋值起作用）。
    // 所以实际行为是：
    // 若本拍没从 FIFO 读新数据：tvalid_next = old_valid && !tready
    // 若本拍从 FIFO 读了新数据：tvalid_next = 1（见下文）
    m_axis_read_data_tvalid_reg <= m_axis_read_data_tvalid_reg && !m_axis_read_data_tready;

    // 更新 half_full：
    // wr_ptr - rd_ptr = FIFO 当前使用的深度。
    // 和 2^(ADDR_WIDTH-1) 比较 → 即“深度一半”的阈值。
    // 所以：超过半满就置位 half_full，向内部回传“快顶了别再塞”。
    out_fifo_half_full_reg <= $unsigned(out_fifo_wr_ptr_reg - out_fifo_rd_ptr_reg) >= 2 ** (OUTPUT_FIFO_ADDR_WIDTH - 1);

    // 写入 FIFO（来自 “内部 AXIS 流” m_axis_read_data_*_int）
    // 条件：FIFO 没满 + 内部给了一拍有效数据（tvalid_int=1）。
    // 行为：把这拍数据写入 FIFO 对应地址，写指针+1。
    // 这里使用的是内部 FSM 组合生成的 *_int 信号（axis_state 那里），
    // 所以可以理解为：内部 AXIS 流 → 写入小 FIFO。
    if (!out_fifo_full && m_axis_read_data_tvalid_int) begin
      out_fifo_tdata[out_fifo_wr_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]] <= m_axis_read_data_tdata_int;
      out_fifo_tkeep[out_fifo_wr_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]] <= m_axis_read_data_tkeep_int;
      out_fifo_tlast[out_fifo_wr_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]] <= m_axis_read_data_tlast_int;
      // out_fifo_tid[out_fifo_wr_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]] <= m_axis_read_data_tid_int;
      // out_fifo_tdest[out_fifo_wr_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]] <= m_axis_read_data_tdest_int;
      // out_fifo_tuser[out_fifo_wr_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]] <= m_axis_read_data_tuser_int;
      out_fifo_wr_ptr_reg <= out_fifo_wr_ptr_reg + 1;
    end

    // 从 FIFO 读数据到“对外输出寄存器”
    // !out_fifo_empty：FIFO 里有数据。
    // (!m_axis_read_data_tvalid_reg || m_axis_read_data_tready)：
    // 如果当前对外口 tvalid=0 → 可以直接装新数据。
    // 如果 tvalid=1 且对方 tready=1 → 当前这一拍数据被“接收”，下一拍可以装新数据。
    // 如果 tvalid=1 且对方 tready=0 → 不可以覆盖，还要保持这拍数据给对方，不能读新的。
    // 行为：把 FIFO 的当前读地址那一拍数据装进 输出寄存器。置 tvalid_reg=1，tlast_reg 取对应值。读指针 +1。
    if (!out_fifo_empty && (!m_axis_read_data_tvalid_reg || m_axis_read_data_tready)) begin
      m_axis_read_data_tdata_reg <= out_fifo_tdata[out_fifo_rd_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]];
      m_axis_read_data_tkeep_reg <= out_fifo_tkeep[out_fifo_rd_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]];
      m_axis_read_data_tvalid_reg <= 1'b1;
      m_axis_read_data_tlast_reg <= out_fifo_tlast[out_fifo_rd_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]];
      // m_axis_read_data_tid_reg <= out_fifo_tid[out_fifo_rd_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]];
      // m_axis_read_data_tdest_reg <= out_fifo_tdest[out_fifo_rd_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]];
      // m_axis_read_data_tuser_reg <= out_fifo_tuser[out_fifo_rd_ptr_reg[OUTPUT_FIFO_ADDR_WIDTH-1:0]];
      out_fifo_rd_ptr_reg <= out_fifo_rd_ptr_reg + 1;
    end

    // 清空 FIFO 指针。
    // 清空对外有效标志。
    if (rst_n) begin
      out_fifo_wr_ptr_reg         <= 0;
      out_fifo_rd_ptr_reg         <= 0;
      m_axis_read_data_tvalid_reg <= 1'b0;
    end
  end

endmodule

`resetall
