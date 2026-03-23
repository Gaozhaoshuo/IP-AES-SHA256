module flow_ctrl #(
    parameter AXI_ADDR_WIDTH = 32,
    parameter LEN_WIDTH = 32,
    parameter TAG_WIDTH = 8,
    parameter ERR_WIDTH = 4
) (
    input clk,
    input rst_n,

    input                      sha_sof_i,
    input [AXI_ADDR_WIDTH-1:0] blk_base_i,
    input [     LEN_WIDTH-1:0] blk_len_i,
    output                     sha_busy_o,
    // to sha256_core
    output cmd_init_o,
    output cmd_next_o,
    output cmd_last_o,
    input  cmd_ready_i,
    input  digest_valid_i,

    // to axi_dma_rd desc (one block per desc)
    output [AXI_ADDR_WIDTH-1:0] m_axis_read_desc_addr_o,
    output [     LEN_WIDTH-1:0] m_axis_read_desc_len_o,
    output [     TAG_WIDTH-1:0] m_axis_read_desc_tag_o,
    output                      m_axis_read_desc_valid_o,
    input                       m_axis_read_desc_ready_i,

    // from axi_dma_rd status
    input [TAG_WIDTH-1:0] s_axis_read_desc_status_tag_i,
    input [ERR_WIDTH-1:0] s_axis_read_desc_status_error_i,
    input                 s_axis_read_desc_status_valid_i,

    // to axi_dma_rd
    output axi_dma_rd_enable_o
);

  localparam IDLE = 3'd0;
  localparam ISSUE = 3'd1;
  localparam WAIT_STATUS = 3'd2;
  localparam WAIT_DIGEST = 3'd3;
  localparam DONE = 3'd4;
  localparam ERR = 3'd5;

  localparam [LEN_WIDTH-1:0] BLOCK_BYTES = 64;

  //   localparam ERR_PARAM     = 4'd1;
  //   localparam ERR_DMA       = 4'd2;
  //   localparam ERR_TAG       = 4'd3;

  reg [AXI_ADDR_WIDTH-1:0] blk_base_reg, blk_base_next;
  reg [LEN_WIDTH-1:0] blk_len_reg, blk_len_next;

  reg cmd_init_reg, cmd_init_next;
  reg cmd_next_reg, cmd_next_next;
  reg cmd_last_reg, cmd_last_next;
  reg [AXI_ADDR_WIDTH-1:0] m_axis_read_desc_addr_reg, m_axis_read_desc_addr_next;
  reg [LEN_WIDTH-1:0] m_axis_read_desc_len_reg, m_axis_read_desc_len_next;
  reg [TAG_WIDTH-1:0] m_axis_read_desc_tag_reg, m_axis_read_desc_tag_next;
  reg m_axis_read_desc_valid_reg, m_axis_read_desc_valid_next;
  reg axi_dma_rd_enable_reg, axi_dma_rd_enable_next;

  assign cmd_init_o = cmd_init_reg;
  assign cmd_next_o = cmd_next_reg;
  assign cmd_last_o = cmd_last_reg;
  assign m_axis_read_desc_addr_o = m_axis_read_desc_addr_reg;
  assign m_axis_read_desc_len_o = m_axis_read_desc_len_reg;
  assign m_axis_read_desc_tag_o = m_axis_read_desc_tag_reg;
  assign m_axis_read_desc_valid_o = m_axis_read_desc_valid_reg;
  assign axi_dma_rd_enable_o = axi_dma_rd_enable_reg;

  reg [2:0] state_reg, state_next;

  wire [LEN_WIDTH:0] total_bytes;
  wire [31:0] blk_cnt;
  wire last_block;
  wire issue_fire;

  reg [31:0] blk_idx_reg, blk_idx_next;

  assign total_bytes = blk_len_reg;
  assign blk_cnt = total_bytes >> 6;
  assign last_block = (blk_idx_reg == (blk_cnt - 1));
  assign issue_fire = (state_reg == ISSUE) && cmd_ready_i && m_axis_read_desc_ready_i;

  always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      state_reg <= IDLE;
      blk_base_reg <= {AXI_ADDR_WIDTH{1'b0}};
      blk_len_reg <= {LEN_WIDTH{1'b0}};
      blk_idx_reg <= 32'd0;
      m_axis_read_desc_addr_reg <= {AXI_ADDR_WIDTH{1'b0}};
      m_axis_read_desc_len_reg <= {LEN_WIDTH{1'b0}};
      m_axis_read_desc_tag_reg <= {TAG_WIDTH{1'b0}};
      m_axis_read_desc_valid_reg <= 1'b0;
      axi_dma_rd_enable_reg <= 1'b0;
      cmd_init_reg <= 1'b0;
      cmd_next_reg <= 1'b0;
      cmd_last_reg <= 1'b0;
    end else begin
      state_reg <= state_next;
      blk_base_reg <= blk_base_next;
      blk_len_reg <= blk_len_next;
      blk_idx_reg <= blk_idx_next;
      m_axis_read_desc_addr_reg <= m_axis_read_desc_addr_next;
      m_axis_read_desc_len_reg <= m_axis_read_desc_len_next;
      m_axis_read_desc_tag_reg <= m_axis_read_desc_tag_next;
      m_axis_read_desc_valid_reg <= m_axis_read_desc_valid_next;
      axi_dma_rd_enable_reg <= axi_dma_rd_enable_next;
      cmd_init_reg <= cmd_init_next;
      cmd_next_reg <= cmd_next_next;
      cmd_last_reg <= cmd_last_next;
    end
  end

  always @(*) begin
    state_next = state_reg;
    blk_base_next = blk_base_reg;
    blk_len_next = blk_len_reg;
    blk_idx_next = blk_idx_reg;
    m_axis_read_desc_addr_next = m_axis_read_desc_addr_reg;
    m_axis_read_desc_len_next = m_axis_read_desc_len_reg;
    m_axis_read_desc_tag_next = m_axis_read_desc_tag_reg;
    m_axis_read_desc_valid_next = m_axis_read_desc_valid_reg && !m_axis_read_desc_ready_i;
    axi_dma_rd_enable_next = axi_dma_rd_enable_reg;
    cmd_init_next = cmd_init_reg && !cmd_ready_i;
    cmd_next_next = cmd_next_reg && !cmd_ready_i;
    cmd_last_next = cmd_last_reg && !cmd_ready_i;

    case (state_reg)
      IDLE: begin
        blk_idx_next = 0;
        axi_dma_rd_enable_next = 1'b0;
        state_next = sha_sof_i ? ISSUE : IDLE;
        blk_base_next = blk_base_i;
        blk_len_next = blk_len_i;
      end

      ISSUE: begin
        m_axis_read_desc_addr_next = blk_base_reg + (blk_idx_reg << 6);
        m_axis_read_desc_len_next = BLOCK_BYTES;  // one block = 64 bytes
        m_axis_read_desc_tag_next = blk_idx_reg;
        m_axis_read_desc_valid_next = 1'b1;
        axi_dma_rd_enable_next = 1'b1;

        cmd_init_next = (blk_idx_reg == 0);
        cmd_next_next = (blk_idx_reg != 0);
        cmd_last_next = last_block;

        state_next = WAIT_STATUS;
      end

      WAIT_STATUS: begin
        if (s_axis_read_desc_status_valid_i) begin
          if (s_axis_read_desc_status_error_i != 'd0) begin
            state_next = ERR;
          end else if (s_axis_read_desc_status_tag_i != m_axis_read_desc_tag_reg) begin
            state_next = ERR;
          end else begin
            state_next = WAIT_DIGEST;
          end
        end
      end

      WAIT_DIGEST: begin
        if (digest_valid_i && last_block) begin
          state_next = DONE;
        end else if (cmd_ready_i) begin
          blk_idx_next = blk_idx_reg + 1;
          state_next   = ISSUE;
        end
      end

      ERR: begin
        state_next = IDLE;
      end

      DONE: begin
        state_next = IDLE;
      end
    endcase
  end

endmodule
