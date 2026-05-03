// AXI4 Interconnect/Crossbar
// 4 Masters x 4 Slaves with full crossbar connectivity
// Date: 2026-05-03

module axi_interconnect #(
  parameter int ADDR_WIDTH = 64,
  parameter int DATA_WIDTH = 64,
  parameter int ID_WIDTH = 16,
  parameter int NUM_MASTERS = 4,
  parameter int NUM_SLAVES = 4
) (
  input  logic clk,
  input  logic rst_n,
  
  // Master 0: RISC-V Core
  // Master 1: DMA Engine
  // Master 2: PCIe Controller
  // Master 3: (Future expansion)
  
  // Master Write Address Channels
  input  logic [NUM_MASTERS-1:0][ADDR_WIDTH-1:0]   m_awaddr,
  input  logic [NUM_MASTERS-1:0][7:0]              m_awlen,
  input  logic [NUM_MASTERS-1:0][2:0]              m_awsize,
  input  logic [NUM_MASTERS-1:0][1:0]              m_awburst,
  input  logic [NUM_MASTERS-1:0][ID_WIDTH-1:0]    m_awid,
  input  logic [NUM_MASTERS-1:0]                   m_awvalid,
  output logic [NUM_MASTERS-1:0]                   m_awready,
  
  // Master Write Data Channels
  input  logic [NUM_MASTERS-1:0][DATA_WIDTH-1:0]  m_wdata,
  input  logic [NUM_MASTERS-1:0][(DATA_WIDTH/8)-1:0] m_wstrb,
  input  logic [NUM_MASTERS-1:0]                   m_wlast,
  input  logic [NUM_MASTERS-1:0]                   m_wvalid,
  output logic [NUM_MASTERS-1:0]                   m_wready,
  
  // Master Write Response Channels
  output logic [NUM_MASTERS-1:0][1:0]              m_bresp,
  output logic [NUM_MASTERS-1:0][ID_WIDTH-1:0]    m_bid,
  output logic [NUM_MASTERS-1:0]                   m_bvalid,
  input  logic [NUM_MASTERS-1:0]                   m_bready,
  
  // Master Read Address Channels
  input  logic [NUM_MASTERS-1:0][ADDR_WIDTH-1:0]   m_araddr,
  input  logic [NUM_MASTERS-1:0][7:0]              m_arlen,
  input  logic [NUM_MASTERS-1:0][2:0]              m_arsize,
  input  logic [NUM_MASTERS-1:0][1:0]              m_arburst,
  input  logic [NUM_MASTERS-1:0][ID_WIDTH-1:0]    m_arid,
  input  logic [NUM_MASTERS-1:0]                   m_arvalid,
  output logic [NUM_MASTERS-1:0]                   m_arready,
  
  // Master Read Data Channels
  output logic [NUM_MASTERS-1:0][DATA_WIDTH-1:0]  m_rdata,
  output logic [NUM_MASTERS-1:0][1:0]              m_rresp,
  output logic [NUM_MASTERS-1:0][ID_WIDTH-1:0]    m_rid,
  output logic [NUM_MASTERS-1:0]                   m_rlast,
  output logic [NUM_MASTERS-1:0]                   m_rvalid,
  input  logic [NUM_MASTERS-1:0]                   m_rready,
  
  // Slave Write Address Channels
  // Slave 0: SRAM (0x0000_0000 - 0x0FFF_FFFF, 256MB)
  // Slave 1: DDR4 (0x1000_0000 - 0x7FFF_FFFF, 1.75GB)
  // Slave 2: Peripherals (0x8000_0000 - 0x8FFF_FFFF, 256MB)
  // Slave 3: Configuration (0x9000_0000 - 0x9FFF_FFFF, 256MB)
  
  output logic [NUM_SLAVES-1:0][ADDR_WIDTH-1:0]   s_awaddr,
  output logic [NUM_SLAVES-1:0][7:0]              s_awlen,
  output logic [NUM_SLAVES-1:0][2:0]              s_awsize,
  output logic [NUM_SLAVES-1:0][1:0]              s_awburst,
  output logic [NUM_SLAVES-1:0][ID_WIDTH-1:0]    s_awid,
  output logic [NUM_SLAVES-1:0]                   s_awvalid,
  input  logic [NUM_SLAVES-1:0]                   s_awready,
  
  // Slave Write Data Channels
  output logic [NUM_SLAVES-1:0][DATA_WIDTH-1:0]  s_wdata,
  output logic [NUM_SLAVES-1:0][(DATA_WIDTH/8)-1:0] s_wstrb,
  output logic [NUM_SLAVES-1:0]                   s_wlast,
  output logic [NUM_SLAVES-1:0]                   s_wvalid,
  input  logic [NUM_SLAVES-1:0]                   s_wready,
  
  // Slave Write Response Channels
  input  logic [NUM_SLAVES-1:0][1:0]              s_bresp,
  input  logic [NUM_SLAVES-1:0][ID_WIDTH-1:0]    s_bid,
  input  logic [NUM_SLAVES-1:0]                   s_bvalid,
  output logic [NUM_SLAVES-1:0]                   s_bready,
  
  // Slave Read Address Channels
  output logic [NUM_SLAVES-1:0][ADDR_WIDTH-1:0]   s_araddr,
  output logic [NUM_SLAVES-1:0][7:0]              s_arlen,
  output logic [NUM_SLAVES-1:0][2:0]              s_arsize,
  output logic [NUM_SLAVES-1:0][1:0]              s_arburst,
  output logic [NUM_SLAVES-1:0][ID_WIDTH-1:0]    s_arid,
  output logic [NUM_SLAVES-1:0]                   s_arvalid,
  input  logic [NUM_SLAVES-1:0]                   s_arready,
  
  // Slave Read Data Channels
  input  logic [NUM_SLAVES-1:0][DATA_WIDTH-1:0]  s_rdata,
  input  logic [NUM_SLAVES-1:0][1:0]              s_rresp,
  input  logic [NUM_SLAVES-1:0][ID_WIDTH-1:0]    s_rid,
  input  logic [NUM_SLAVES-1:0]                   s_rlast,
  input  logic [NUM_SLAVES-1:0]                   s_rvalid,
  output logic [NUM_SLAVES-1:0]                   s_rready
);

  import axi_defines::*;

  // Address decode for each master request
  logic [NUM_MASTERS-1:0][3:0] write_slave_select;
  logic [NUM_MASTERS-1:0][3:0] read_slave_select;
  
  // Address decoding logic
  // Maps address ranges to slave indices
  function logic [3:0] decode_slave_write(logic [ADDR_WIDTH-1:0] addr);
    case (addr[31:28])
      4'h0: return 4'b0001; // Slave 0: SRAM
      4'h1,4'h2,4'h3,4'h4,4'h5,4'h6,4'h7: return 4'b0010; // Slave 1: DDR4
      4'h8: return 4'b0100; // Slave 2: Peripherals
      4'h9: return 4'b1000; // Slave 3: Configuration
      default: return 4'b1000; // Default to Config
    endcase
  endfunction

  function logic [3:0] decode_slave_read(logic [ADDR_WIDTH-1:0] addr);
    case (addr[31:28])
      4'h0: return 4'b0001; // Slave 0: SRAM
      4'h1,4'h2,4'h3,4'h4,4'h5,4'h6,4'h7: return 4'b0010; // Slave 1: DDR4
      4'h8: return 4'b0100; // Slave 2: Peripherals
      4'h9: return 4'b1000; // Slave 3: Configuration
      default: return 4'b1000; // Default to Config
    endcase
  endfunction

  // Generate slave select signals
  generate
    for (genvar i = 0; i < NUM_MASTERS; i++) begin
      always_comb begin
        write_slave_select[i] = decode_slave_write(m_awaddr[i]);
        read_slave_select[i] = decode_slave_read(m_araddr[i]);
      end
    end
  endgenerate

  // Write Address Channel Routing
  always_comb begin
    for (int s = 0; s < NUM_SLAVES; s++) begin
      s_awvalid[s] = 1'b0;
      s_awaddr[s] = 64'h0;
      s_awlen[s] = 8'h0;
      s_awsize[s] = 3'b0;
      s_awburst[s] = 2'b0;
      s_awid[s] = 16'h0;
    end
    
    for (int m = 0; m < NUM_MASTERS; m++) begin
      m_awready[m] = 1'b0;
      if (m_awvalid[m]) begin
        for (int s = 0; s < NUM_SLAVES; s++) begin
          if (write_slave_select[m][s]) begin
            s_awvalid[s] = 1'b1;
            s_awaddr[s] = m_awaddr[m];
            s_awlen[s] = m_awlen[m];
            s_awsize[s] = m_awsize[m];
            s_awburst[s] = m_awburst[m];
            s_awid[s] = {m[3:0], m_awid[m][11:0]}; // Prepend master ID
            m_awready[m] = s_awready[s];
          end
        end
      end
    end
  end

  // Write Data Channel Routing
  always_comb begin
    for (int s = 0; s < NUM_SLAVES; s++) begin
      s_wvalid[s] = 1'b0;
      s_wdata[s] = 64'h0;
      s_wstrb[s] = 8'h0;
      s_wlast[s] = 1'b0;
    end
    
    for (int m = 0; m < NUM_MASTERS; m++) begin
      m_wready[m] = 1'b0;
      if (m_wvalid[m]) begin
        for (int s = 0; s < NUM_SLAVES; s++) begin
          if (write_slave_select[m][s]) begin
            s_wvalid[s] = 1'b1;
            s_wdata[s] = m_wdata[m];
            s_wstrb[s] = m_wstrb[m];
            s_wlast[s] = m_wlast[m];
            m_wready[m] = s_wready[s];
          end
        end
      end
    end
  end

  // Write Response Channel Routing
  always_comb begin
    for (int m = 0; m < NUM_MASTERS; m++) begin
      m_bvalid[m] = 1'b0;
      m_bresp[m] = 2'b0;
      m_bid[m] = 16'h0;
    end
    
    for (int s = 0; s < NUM_SLAVES; s++) begin
      s_bready[s] = 1'b0;
      if (s_bvalid[s]) begin
        for (int m = 0; m < NUM_MASTERS; m++) begin
          if (s_bid[s][15:12] == m[3:0]) begin
            m_bvalid[m] = 1'b1;
            m_bresp[m] = s_bresp[s];
            m_bid[m] = s_bid[s][11:0];
            s_bready[s] = m_bready[m];
          end
        end
      end
    end
  end

  // Read Address Channel Routing
  always_comb begin
    for (int s = 0; s < NUM_SLAVES; s++) begin
      s_arvalid[s] = 1'b0;
      s_araddr[s] = 64'h0;
      s_arlen[s] = 8'h0;
      s_arsize[s] = 3'b0;
      s_arburst[s] = 2'b0;
      s_arid[s] = 16'h0;
    end
    
    for (int m = 0; m < NUM_MASTERS; m++) begin
      m_arready[m] = 1'b0;
      if (m_arvalid[m]) begin
        for (int s = 0; s < NUM_SLAVES; s++) begin
          if (read_slave_select[m][s]) begin
            s_arvalid[s] = 1'b1;
            s_araddr[s] = m_araddr[m];
            s_arlen[s] = m_arlen[m];
            s_arsize[s] = m_arsize[m];
            s_arburst[s] = m_arburst[m];
            s_arid[s] = {m[3:0], m_arid[m][11:0]};
            m_arready[m] = s_arready[s];
          end
        end
      end
    end
  end

  // Read Data Channel Routing
  always_comb begin
    for (int m = 0; m < NUM_MASTERS; m++) begin
      m_rvalid[m] = 1'b0;
      m_rdata[m] = 64'h0;
      m_rresp[m] = 2'b0;
      m_rid[m] = 16'h0;
      m_rlast[m] = 1'b0;
    end
    
    for (int s = 0; s < NUM_SLAVES; s++) begin
      s_rready[s] = 1'b0;
      if (s_rvalid[s]) begin
        for (int m = 0; m < NUM_MASTERS; m++) begin
          if (s_rid[s][15:12] == m[3:0]) begin
            m_rvalid[m] = 1'b1;
            m_rdata[m] = s_rdata[s];
            m_rresp[m] = s_rresp[s];
            m_rid[m] = s_rid[s][11:0];
            m_rlast[m] = s_rlast[s];
            s_rready[s] = m_rready[m];
          end
        end
      end
    end
  end

endmodule : axi_interconnect
