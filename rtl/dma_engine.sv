// DMA Engine with AXI4 Master Interface
// Supports memory-to-memory transfers
// Date: 2026-05-03

module dma_engine #(
  parameter int ADDR_WIDTH = 64,
  parameter int DATA_WIDTH = 64,
  parameter int ID_WIDTH = 16,
  parameter int MAX_BURST_LEN = 256
) (
  input  logic                        clk,
  input  logic                        rst_n,
  
  // Control Register Interface (APB)
  input  logic [31:0]                 src_addr,
  input  logic [31:0]                 dst_addr,
  input  logic [31:0]                 xfer_len,
  input  logic                        xfer_start,
  output logic                        xfer_busy,
  output logic                        xfer_done,
  output logic [31:0]                 bytes_transferred,
  
  // AXI4 Master - Read Channel
  output logic [ADDR_WIDTH-1:0]       axi_araddr,
  output logic [7:0]                  axi_arlen,
  output logic [2:0]                  axi_arsize,
  output logic [1:0]                  axi_arburst,
  output logic [ID_WIDTH-1:0]         axi_arid,
  output logic                        axi_arvalid,
  input  logic                        axi_arready,
  
  input  logic [DATA_WIDTH-1:0]       axi_rdata,
  input  logic [1:0]                  axi_rresp,
  input  logic [ID_WIDTH-1:0]         axi_rid,
  input  logic                        axi_rlast,
  input  logic                        axi_rvalid,
  output logic                        axi_rready,
  
  // AXI4 Master - Write Channel
  output logic [ADDR_WIDTH-1:0]       axi_awaddr,
  output logic [7:0]                  axi_awlen,
  output logic [2:0]                  axi_awsize,
  output logic [1:0]                  axi_awburst,
  output logic [ID_WIDTH-1:0]         axi_awid,
  output logic                        axi_awvalid,
  input  logic                        axi_awready,
  
  output logic [DATA_WIDTH-1:0]       axi_wdata,
  output logic [(DATA_WIDTH/8)-1:0]   axi_wstrb,
  output logic                        axi_wlast,
  output logic                        axi_wvalid,
  input  logic                        axi_wready,
  
  input  logic [1:0]                  axi_bresp,
  input  logic [ID_WIDTH-1:0]         axi_bid,
  input  logic                        axi_bvalid,
  output logic                        axi_bready
);

  import axi_defines::*;

  // DMA State Machine
  enum logic [3:0] {
    IDLE      = 4'b0000,
    READ_ADDR = 4'b0001,
    READ_DATA = 4'b0010,
    WRITE_ADDR = 4'b0011,
    WRITE_DATA = 4'b0100,
    COMPLETE  = 4'b0101
  } dma_state, dma_next_state;

  // Internal registers
  logic [ADDR_WIDTH-1:0]  src_addr_reg;
  logic [ADDR_WIDTH-1:0]  dst_addr_reg;
  logic [31:0]            xfer_len_reg;
  logic [31:0]            bytes_left;
  logic [7:0]             burst_len;
  logic [DATA_WIDTH-1:0]  fifo_data [0:15]; // Small FIFO buffer
  logic [4:0]             fifo_wr_ptr;
  logic [4:0]             fifo_rd_ptr;
  logic [5:0]             fifo_count;

  // Calculate optimal burst length
  assign burst_len = (bytes_left >= (MAX_BURST_LEN * (DATA_WIDTH/8))) ? 
                     (MAX_BURST_LEN - 1) : ((bytes_left / (DATA_WIDTH/8)) - 1);

  // Assign AXI parameters
  assign axi_arsize = 3'b011;  // 8 bytes per beat
  assign axi_arburst = 2'b01;  // INCR burst type
  assign axi_awsize = 3'b011;  // 8 bytes per beat
  assign axi_awburst = 2'b01;  // INCR burst type
  assign axi_wstrb = {(DATA_WIDTH/8){1'b1}};

  // DMA State Machine
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      dma_state <= IDLE;
      src_addr_reg <= 64'h0;
      dst_addr_reg <= 64'h0;
      xfer_len_reg <= 32'h0;
      bytes_left <= 32'h0;
      bytes_transferred <= 32'h0;
      xfer_busy <= 1'b0;
      xfer_done <= 1'b0;
      axi_arvalid <= 1'b0;
      axi_awvalid <= 1'b0;
      axi_wvalid <= 1'b0;
      axi_rready <= 1'b1;
      axi_bready <= 1'b1;
      fifo_wr_ptr <= 5'h0;
      fifo_rd_ptr <= 5'h0;
      fifo_count <= 6'h0;
    end else begin
      dma_state <= dma_next_state;
      
      case (dma_state)
        IDLE: begin
          xfer_done <= 1'b0;
          if (xfer_start) begin
            src_addr_reg <= {{32{1'b0}}, src_addr};
            dst_addr_reg <= {{32{1'b0}}, dst_addr};
            xfer_len_reg <= xfer_len;
            bytes_left <= xfer_len;
            bytes_transferred <= 32'h0;
            xfer_busy <= 1'b1;
          end
        end
        
        READ_ADDR: begin
          if (axi_arready) begin
            axi_arvalid <= 1'b0;
            src_addr_reg <= src_addr_reg + (burst_len + 1) * (DATA_WIDTH/8);
          end
        end
        
        READ_DATA: begin
          if (axi_rvalid && axi_rready) begin
            fifo_data[fifo_wr_ptr] <= axi_rdata;
            fifo_wr_ptr <= fifo_wr_ptr + 1;
            fifo_count <= fifo_count + 1;
            bytes_transferred <= bytes_transferred + (DATA_WIDTH/8);
            bytes_left <= bytes_left - (DATA_WIDTH/8);
            if (axi_rlast) begin
              axi_rready <= 1'b0;
            end
          end
        end
        
        WRITE_ADDR: begin
          if (axi_awready) begin
            axi_awvalid <= 1'b0;
            dst_addr_reg <= dst_addr_reg + (burst_len + 1) * (DATA_WIDTH/8);
          end
        end
        
        WRITE_DATA: begin
          if (axi_wready && (fifo_count > 0)) begin
            axi_wdata <= fifo_data[fifo_rd_ptr];
            axi_wlast <= (fifo_rd_ptr == fifo_wr_ptr - 1) ? 1'b1 : 1'b0;
            fifo_rd_ptr <= fifo_rd_ptr + 1;
            fifo_count <= fifo_count - 1;
          end
          
          if (axi_bvalid) begin
            axi_bready <= 1'b1;
          end
        end
        
        COMPLETE: begin
          xfer_busy <= 1'b0;
          xfer_done <= 1'b1;
        end
      endcase
    end
  end

  // Next State Logic
  always_comb begin
    dma_next_state = dma_state;
    
    case (dma_state)
      IDLE: begin
        if (xfer_start) begin
          dma_next_state = READ_ADDR;
        end
      end
      
      READ_ADDR: begin
        axi_araddr = src_addr_reg;
        axi_arlen = burst_len;
        axi_arid = 16'h0001;
        axi_arvalid = 1'b1;
        
        if (axi_arready) begin
          dma_next_state = READ_DATA;
        end
      end
      
      READ_DATA: begin
        if (bytes_left == 0) begin
          dma_next_state = WRITE_ADDR;
        end
      end
      
      WRITE_ADDR: begin
        axi_awaddr = dst_addr_reg;
        axi_awlen = burst_len;
        axi_awid = 16'h0002;
        axi_awvalid = 1'b1;
        
        if (axi_awready) begin
          dma_next_state = WRITE_DATA;
        end
      end
      
      WRITE_DATA: begin
        axi_wvalid = (fifo_count > 0) ? 1'b1 : 1'b0;
        
        if (axi_bvalid && (bytes_left == 0)) begin
          dma_next_state = COMPLETE;
        end
      end
      
      COMPLETE: begin
        dma_next_state = IDLE;
      end
    endcase
  end

endmodule : dma_engine
