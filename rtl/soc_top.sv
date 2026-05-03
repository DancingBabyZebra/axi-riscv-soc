// AXI-based RISC-V SOC Top Module
// Integrates: RISC-V Core, DMA Engine, PCIe Controller
// Date: 2026-05-03

module soc_top #(
  parameter int ADDR_WIDTH = 64,
  parameter int DATA_WIDTH = 64,
  parameter int ID_WIDTH = 16
) (
  input  logic                      clk,
  input  logic                      rst_n,
  
  // PCIe Interfaces
  input  logic [7:0]                pcie_rxp,
  input  logic [7:0]                pcie_rxn,
  output logic [7:0]                pcie_txp,
  output logic [7:0]                pcie_txn,
  input  logic                      pcie_clk,
  
  // External Interrupt
  input  logic                      ext_irq,
  
  // UART Debug Interface
  input  logic                      uart_rxd,
  output logic                      uart_txd,
  
  // Status LEDs
  output logic                      led_ok,
  output logic                      led_error,
  output logic                      pcie_link_up_led
);

  import axi_defines::*;

  // Clock and Reset
  logic sys_clk, sys_rst_n;
  logic pcie_rst_n;

  // RISC-V Core AXI Master Interface
  logic [ADDR_WIDTH-1:0]     core_awaddr;
  logic [7:0]                core_awlen;
  logic [2:0]                core_awsize;
  logic [1:0]                core_awburst;
  logic [ID_WIDTH-1:0]       core_awid;
  logic                      core_awvalid;
  logic                      core_awready;
  
  logic [DATA_WIDTH-1:0]     core_wdata;
  logic [(DATA_WIDTH/8)-1:0] core_wstrb;
  logic                      core_wlast;
  logic                      core_wvalid;
  logic                      core_wready;
  
  logic [1:0]                core_bresp;
  logic [ID_WIDTH-1:0]       core_bid;
  logic                      core_bvalid;
  logic                      core_bready;
  
  logic [ADDR_WIDTH-1:0]     core_araddr;
  logic [7:0]                core_arlen;
  logic [2:0]                core_arsize;
  logic [1:0]                core_arburst;
  logic [ID_WIDTH-1:0]       core_arid;
  logic                      core_arvalid;
  logic                      core_arready;
  
  logic [DATA_WIDTH-1:0]     core_rdata;
  logic [1:0]                core_rresp;
  logic [ID_WIDTH-1:0]       core_rid;
  logic                      core_rlast;
  logic                      core_rvalid;
  logic                      core_rready;

  // DMA Engine AXI Master Interface
  logic [ADDR_WIDTH-1:0]     dma_awaddr;
  logic [7:0]                dma_awlen;
  logic [2:0]                dma_awsize;
  logic [1:0]                dma_awburst;
  logic [ID_WIDTH-1:0]       dma_awid;
  logic                      dma_awvalid;
  logic                      dma_awready;
  
  logic [DATA_WIDTH-1:0]     dma_wdata;
  logic [(DATA_WIDTH/8)-1:0] dma_wstrb;
  logic                      dma_wlast;
  logic                      dma_wvalid;
  logic                      dma_wready;
  
  logic [1:0]                dma_bresp;
  logic [ID_WIDTH-1:0]       dma_bid;
  logic                      dma_bvalid;
  logic                      dma_bready;
  
  logic [ADDR_WIDTH-1:0]     dma_araddr;
  logic [7:0]                dma_arlen;
  logic [2:0]                dma_arsize;
  logic [1:0]                dma_arburst;
  logic [ID_WIDTH-1:0]       dma_arid;
  logic                      dma_arvalid;
  logic                      dma_arready;
  
  logic [DATA_WIDTH-1:0]     dma_rdata;
  logic [1:0]                dma_rresp;
  logic [ID_WIDTH-1:0]       dma_rid;
  logic                      dma_rlast;
  logic                      dma_rvalid;
  logic                      dma_rready;

  // PCIe Controller AXI Master Interface
  logic [ADDR_WIDTH-1:0]     pcie_awaddr;
  logic [7:0]                pcie_awlen;
  logic [2:0]                pcie_awsize;
  logic [1:0]                pcie_awburst;
  logic [ID_WIDTH-1:0]       pcie_awid;
  logic                      pcie_awvalid;
  logic                      pcie_awready;
  
  logic [DATA_WIDTH-1:0]     pcie_wdata;
  logic [(DATA_WIDTH/8)-1:0] pcie_wstrb;
  logic                      pcie_wlast;
  logic                      pcie_wvalid;
  logic                      pcie_wready;
  
  logic [1:0]                pcie_bresp;
  logic [ID_WIDTH-1:0]       pcie_bid;
  logic                      pcie_bvalid;
  logic                      pcie_bready;
  
  logic [ADDR_WIDTH-1:0]     pcie_araddr;
  logic [7:0]                pcie_arlen;
  logic [2:0]                pcie_arsize;
  logic [1:0]                pcie_arburst;
  logic [ID_WIDTH-1:0]       pcie_arid;
  logic                      pcie_arvalid;
  logic                      pcie_arready;
  
  logic [DATA_WIDTH-1:0]     pcie_rdata;
  logic [1:0]                pcie_rresp;
  logic [ID_WIDTH-1:0]       pcie_rid;
  logic                      pcie_rlast;
  logic                      pcie_rvalid;
  logic                      pcie_rready;

  // Interconnect to Slave Interfaces
  logic [3:0][ADDR_WIDTH-1:0]     s_awaddr;
  logic [3:0][7:0]                s_awlen;
  logic [3:0][2:0]                s_awsize;
  logic [3:0][1:0]                s_awburst;
  logic [3:0][ID_WIDTH-1:0]       s_awid;
  logic [3:0]                     s_awvalid;
  logic [3:0]                     s_awready;
  
  logic [3:0][DATA_WIDTH-1:0]     s_wdata;
  logic [3:0][(DATA_WIDTH/8)-1:0] s_wstrb;
  logic [3:0]                     s_wlast;
  logic [3:0]                     s_wvalid;
  logic [3:0]                     s_wready;
  
  logic [3:0][1:0]                s_bresp;
  logic [3:0][ID_WIDTH-1:0]       s_bid;
  logic [3:0]                     s_bvalid;
  logic [3:0]                     s_bready;
  
  logic [3:0][ADDR_WIDTH-1:0]     s_araddr;
  logic [3:0][7:0]                s_arlen;
  logic [3:0][2:0]                s_arsize;
  logic [3:0][1:0]                s_arburst;
  logic [3:0][ID_WIDTH-1:0]       s_arid;
  logic [3:0]                     s_arvalid;
  logic [3:0]                     s_arready;
  
  logic [3:0][DATA_WIDTH-1:0]     s_rdata;
  logic [3:0][1:0]                s_rresp;
  logic [3:0][ID_WIDTH-1:0]       s_rid;
  logic [3:0]                     s_rlast;
  logic [3:0]                     s_rvalid;
  logic [3:0]                     s_rready;

  // DMA Control Signals
  logic [31:0] dma_src_addr;
  logic [31:0] dma_dst_addr;
  logic [31:0] dma_xfer_len;
  logic        dma_xfer_start;
  logic        dma_xfer_busy;
  logic        dma_xfer_done;
  logic [31:0] dma_bytes_transferred;

  // PCIe Status Signals
  logic        pcie_link_up;
  logic [2:0]  pcie_gen;
  logic        pcie_hot_reset;

  // Assign system clock and reset
  assign sys_clk = clk;
  assign sys_rst_n = rst_n;
  assign pcie_rst_n = rst_n;

  // Status LED assignments
  assign led_ok = pcie_link_up;
  assign led_error = pcie_hot_reset;
  assign pcie_link_up_led = pcie_link_up;

  // =====================================================================
  // RISC-V Core Instantiation
  // =====================================================================
  riscv_core #(
    .XLEN(64),
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH)
  ) i_riscv_core (
    .clk(sys_clk),
    .rst_n(sys_rst_n),
    .i_addr(),
    .i_valid(),
    .i_data(32'h0),
    .i_ready(1'b1),
    .d_addr(core_araddr),
    .d_wdata(core_wdata),
    .d_strb(core_wstrb),
    .d_we(core_wvalid),
    .d_valid(core_wvalid),
    .d_rdata(core_rdata),
    .d_ready(core_rready),
    .irq(ext_irq),
    .irq_id(8'h0)
  );

  // =====================================================================
  // DMA Engine Instantiation
  // =====================================================================
  dma_engine #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),
    .ID_WIDTH(ID_WIDTH),
    .MAX_BURST_LEN(256)
  ) i_dma_engine (
    .clk(sys_clk),
    .rst_n(sys_rst_n),
    .src_addr(dma_src_addr),
    .dst_addr(dma_dst_addr),
    .xfer_len(dma_xfer_len),
    .xfer_start(dma_xfer_start),
    .xfer_busy(dma_xfer_busy),
    .xfer_done(dma_xfer_done),
    .bytes_transferred(dma_bytes_transferred),
    .axi_araddr(dma_araddr),
    .axi_arlen(dma_arlen),
    .axi_arsize(dma_arsize),
    .axi_arburst(dma_arburst),
    .axi_arid(dma_arid),
    .axi_arvalid(dma_arvalid),
    .axi_arready(dma_arready),
    .axi_rdata(dma_rdata),
    .axi_rresp(dma_rresp),
    .axi_rid(dma_rid),
    .axi_rlast(dma_rlast),
    .axi_rvalid(dma_rvalid),
    .axi_rready(dma_rready),
    .axi_awaddr(dma_awaddr),
    .axi_awlen(dma_awlen),
    .axi_awsize(dma_awsize),
    .axi_awburst(dma_awburst),
    .axi_awid(dma_awid),
    .axi_awvalid(dma_awvalid),
    .axi_awready(dma_awready),
    .axi_wdata(dma_wdata),
    .axi_wstrb(dma_wstrb),
    .axi_wlast(dma_wlast),
    .axi_wvalid(dma_wvalid),
    .axi_wready(dma_wready),
    .axi_bresp(dma_bresp),
    .axi_bid(dma_bid),
    .axi_bvalid(dma_bvalid),
    .axi_bready(dma_bready)
  );

  // =====================================================================
  // PCIe Controller Instantiation
  // =====================================================================
  pcie_controller #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),
    .ID_WIDTH(ID_WIDTH),
    .NUM_LANES(8)
  ) i_pcie_controller (
    .clk(sys_clk),
    .rst_n(sys_rst_n),
    .pcie_rxp(pcie_rxp),
    .pcie_rxn(pcie_rxn),
    .pcie_txp(pcie_txp),
    .pcie_txn(pcie_txn),
    .pcie_clk(pcie_clk),
    .pcie_rst_n(pcie_rst_n),
    .axi_awaddr(pcie_awaddr),
    .axi_awlen(pcie_awlen),
    .axi_awsize(pcie_awsize),
    .axi_awburst(pcie_awburst),
    .axi_awid(pcie_awid),
    .axi_awvalid(pcie_awvalid),
    .axi_awready(pcie_awready),
    .axi_wdata(pcie_wdata),
    .axi_wstrb(pcie_wstrb),
    .axi_wlast(pcie_wlast),
    .axi_wvalid(pcie_wvalid),
    .axi_wready(pcie_wready),
    .axi_bresp(pcie_bresp),
    .axi_bid(pcie_bid),
    .axi_bvalid(pcie_bvalid),
    .axi_bready(pcie_bready),
    .axi_araddr(pcie_araddr),
    .axi_arlen(pcie_arlen),
    .axi_arsize(pcie_arsize),
    .axi_arburst(pcie_arburst),
    .axi_arid(pcie_arid),
    .axi_arvalid(pcie_arvalid),
    .axi_arready(pcie_arready),
    .axi_rdata(pcie_rdata),
    .axi_rresp(pcie_rresp),
    .axi_rid(pcie_rid),
    .axi_rlast(pcie_rlast),
    .axi_rvalid(pcie_rvalid),
    .axi_rready(pcie_rready),
    .pcie_link_up(pcie_link_up),
    .pcie_gen(pcie_gen),
    .pcie_hot_reset(pcie_hot_reset)
  );

  // =====================================================================
  // AXI4 Interconnect Instantiation
  // =====================================================================
  axi_interconnect #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),
    .ID_WIDTH(ID_WIDTH),
    .NUM_MASTERS(4),
    .NUM_SLAVES(4)
  ) i_axi_interconnect (
    .clk(sys_clk),
    .rst_n(sys_rst_n),
    // Master 0: RISC-V Core
    .m_awaddr({pcie_awaddr, dma_awaddr, core_awaddr, 64'h0}),
    .m_awlen({pcie_awlen, dma_awlen, core_awlen, 8'h0}),
    .m_awsize({pcie_awsize, dma_awsize, core_awsize, 3'h0}),
    .m_awburst({pcie_awburst, dma_awburst, core_awburst, 2'h0}),
    .m_awid({pcie_awid, dma_awid, core_awid, 16'h0}),
    .m_awvalid({pcie_awvalid, dma_awvalid, core_awvalid, 1'b0}),
    .m_awready({pcie_awready, dma_awready, core_awready}),
    .m_wdata({pcie_wdata, dma_wdata, core_wdata, 64'h0}),
    .m_wstrb({pcie_wstrb, dma_wstrb, core_wstrb, 8'h0}),
    .m_wlast({pcie_wlast, dma_wlast, core_wlast, 1'b0}),
    .m_wvalid({pcie_wvalid, dma_wvalid, core_wvalid, 1'b0}),
    .m_wready({pcie_wready, dma_wready, core_wready}),
    .m_bresp({pcie_bresp, dma_bresp, core_bresp}),
    .m_bid({pcie_bid, dma_bid, core_bid}),
    .m_bvalid({pcie_bvalid, dma_bvalid, core_bvalid}),
    .m_bready({pcie_bready, dma_bready, core_bready}),
    .m_araddr({pcie_araddr, dma_araddr, core_araddr, 64'h0}),
    .m_arlen({pcie_arlen, dma_arlen, core_arlen, 8'h0}),
    .m_arsize({pcie_arsize, dma_arsize, core_arsize, 3'h0}),
    .m_arburst({pcie_arburst, dma_arburst, core_arburst, 2'h0}),
    .m_arid({pcie_arid, dma_arid, core_arid, 16'h0}),
    .m_arvalid({pcie_arvalid, dma_arvalid, core_arvalid, 1'b0}),
    .m_arready({pcie_arready, dma_arready, core_arready}),
    .m_rdata({pcie_rdata, dma_rdata, core_rdata}),
    .m_rresp({pcie_rresp, dma_rresp, core_rresp}),
    .m_rid({pcie_rid, dma_rid, core_rid}),
    .m_rlast({pcie_rlast, dma_rlast, core_rlast}),
    .m_rvalid({pcie_rvalid, dma_rvalid, core_rvalid}),
    .m_rready({pcie_rready, dma_rready, core_rready}),
    .s_awaddr(s_awaddr),
    .s_awlen(s_awlen),
    .s_awsize(s_awsize),
    .s_awburst(s_awburst),
    .s_awid(s_awid),
    .s_awvalid(s_awvalid),
    .s_awready(s_awready),
    .s_wdata(s_wdata),
    .s_wstrb(s_wstrb),
    .s_wlast(s_wlast),
    .s_wvalid(s_wvalid),
    .s_wready(s_wready),
    .s_bresp(s_bresp),
    .s_bid(s_bid),
    .s_bvalid(s_bvalid),
    .s_bready(s_bready),
    .s_araddr(s_araddr),
    .s_arlen(s_arlen),
    .s_arsize(s_arsize),
    .s_arburst(s_arburst),
    .s_arid(s_arid),
    .s_arvalid(s_arvalid),
    .s_arready(s_arready),
    .s_rdata(s_rdata),
    .s_rresp(s_rresp),
    .s_rid(s_rid),
    .s_rlast(s_rlast),
    .s_rvalid(s_rvalid),
    .s_rready(s_rready)
  );

  // =====================================================================
  // Slave Memory Stubs (Placeholder)
  // In a real implementation, these would be:
  // - Slave 0: SRAM Controller (256MB)
  // - Slave 1: DDR4 Controller (1.75GB)
  // - Slave 2: Peripheral Controller
  // - Slave 3: Configuration/Register Space
  // =====================================================================

  // Basic ready logic for slaves (all slaves ready to respond)
  assign s_awready = 4'b1111;
  assign s_wready = 4'b1111;
  assign s_bresp = 4'b0000;
  assign s_bvalid = 4'b1111;
  assign s_arready = 4'b1111;
  assign s_rdata = '{default: 64'h0};
  assign s_rresp = 4'b0000;
  assign s_rvalid = 4'b1111;

endmodule : soc_top
