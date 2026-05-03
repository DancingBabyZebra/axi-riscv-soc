// AXI4 Protocol Definitions and Constants
// Version: 1.0
// Date: 2026-05-03

package axi_defines;

  // AXI4 Specification Parameters
  parameter int AXI_ADDR_WIDTH = 64;
  parameter int AXI_DATA_WIDTH = 64;
  parameter int AXI_ID_WIDTH = 16;
  parameter int AXI_LEN_WIDTH = 8;
  parameter int AXI_SIZE_WIDTH = 3;
  parameter int AXI_BURST_WIDTH = 2;
  parameter int AXI_RESP_WIDTH = 2;
  parameter int AXI_STRB_WIDTH = AXI_DATA_WIDTH / 8;

  // AXI Response Types
  typedef enum logic [AXI_RESP_WIDTH-1:0] {
    OKAY   = 2'b00,
    EXOKAY = 2'b01,
    SLVERR = 2'b10,
    DECERR = 2'b11
  } axi_resp_t;

  // Burst Types
  typedef enum logic [AXI_BURST_WIDTH-1:0] {
    FIXED = 2'b00,
    INCR  = 2'b01,
    WRAP  = 2'b10
  } axi_burst_t;

  // Write Channel Structure
  typedef struct packed {
    logic [AXI_ADDR_WIDTH-1:0]   awaddr;
    logic [AXI_LEN_WIDTH-1:0]    awlen;
    logic [AXI_SIZE_WIDTH-1:0]   awsize;
    logic [AXI_BURST_WIDTH-1:0]  awburst;
    logic [AXI_ID_WIDTH-1:0]     awid;
    logic                        awvalid;
  } axi_write_addr_t;

  typedef struct packed {
    logic [AXI_DATA_WIDTH-1:0]   wdata;
    logic [AXI_STRB_WIDTH-1:0]   wstrb;
    logic                        wlast;
    logic                        wvalid;
  } axi_write_data_t;

  typedef struct packed {
    logic [AXI_RESP_WIDTH-1:0]   bresp;
    logic [AXI_ID_WIDTH-1:0]     bid;
    logic                        bvalid;
  } axi_write_resp_t;

  // Read Channel Structure
  typedef struct packed {
    logic [AXI_ADDR_WIDTH-1:0]   araddr;
    logic [AXI_LEN_WIDTH-1:0]    arlen;
    logic [AXI_SIZE_WIDTH-1:0]   arsize;
    logic [AXI_BURST_WIDTH-1:0]  arburst;
    logic [AXI_ID_WIDTH-1:0]     arid;
    logic                        arvalid;
  } axi_read_addr_t;

  typedef struct packed {
    logic [AXI_DATA_WIDTH-1:0]   rdata;
    logic [AXI_RESP_WIDTH-1:0]   rresp;
    logic [AXI_ID_WIDTH-1:0]     rid;
    logic                        rlast;
    logic                        rvalid;
  } axi_read_data_t;

endpackage : axi_defines
