// RISC-V 5-Stage Pipeline Core
// Supports RV64I Base Instruction Set
// Date: 2026-05-03

module riscv_core #(
  parameter int XLEN = 64,
  parameter int ADDR_WIDTH = 64,
  parameter int DATA_WIDTH = 64
) (
  input  logic                     clk,
  input  logic                     rst_n,
  
  // Instruction Memory Interface (AXI Master)
  output logic [ADDR_WIDTH-1:0]    i_addr,
  output logic                     i_valid,
  input  logic [31:0]              i_data,
  input  logic                     i_ready,
  
  // Data Memory Interface (AXI Master)
  output logic [ADDR_WIDTH-1:0]    d_addr,
  output logic [DATA_WIDTH-1:0]    d_wdata,
  output logic [(DATA_WIDTH/8)-1:0] d_strb,
  output logic                     d_we,
  output logic                     d_valid,
  input  logic [DATA_WIDTH-1:0]    d_rdata,
  input  logic                     d_ready,
  
  // Interrupt Interface
  input  logic                     irq,
  input  logic [7:0]               irq_id
);

  import axi_defines::*;

  // RISC-V Register File
  logic [DATA_WIDTH-1:0] regfile [0:31];
  
  // Pipeline Registers
  logic [31:0] pc, pc_next;
  logic [31:0] instr;
  logic [6:0]  opcode;
  logic [4:0]  rd, rs1, rs2;
  logic [11:0] imm12;
  logic [19:0] imm20;
  logic [XLEN-1:0] alu_result;
  
  // Pipeline Stages
  enum logic [2:0] {
    FETCH  = 3'b000,
    DECODE = 3'b001,
    EXEC   = 3'b010,
    MEM    = 3'b011,
    WB     = 3'b100
  } pipeline_stage;

  // Control Signals
  logic [5:0]  alu_op;
  logic [2:0]  mem_op;
  logic        reg_write;
  logic        mem_write;
  logic        mem_read;

  // ALU Operations
  localparam ADD  = 6'b000000;
  localparam SUB  = 6'b000001;
  localparam AND  = 6'b000010;
  localparam OR   = 6'b000011;
  localparam XOR  = 6'b000100;
  localparam SLL  = 6'b000101;
  localparam SRL  = 6'b000110;
  localparam SRA  = 6'b000111;
  localparam ADDI = 6'b001000;
  localparam BEQ  = 6'b001001;

  // Instruction Decode
  assign opcode = instr[6:0];
  assign rd     = instr[11:7];
  assign rs1    = instr[19:15];
  assign rs2    = instr[24:20];
  assign imm12  = instr[31:20];
  assign imm20  = instr[31:12];

  // Main Control FSM
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      pc <= 64'h0;
      pipeline_stage <= FETCH;
      i_valid <= 1'b0;
      d_valid <= 1'b0;
      reg_write <= 1'b0;
    end else begin
      case (pipeline_stage)
        FETCH: begin
          i_valid <= 1'b1;
          i_addr <= pc;
          if (i_ready) begin
            pipeline_stage <= DECODE;
          end
        end
        
        DECODE: begin
          i_valid <= 1'b0;
          instr <= i_data;
          
          case (opcode)
            7'b0110011: alu_op <= ADD;  // R-type
            7'b0010011: alu_op <= ADDI; // I-type
            7'b1100011: alu_op <= BEQ;  // B-type
            7'b0000011: mem_op <= 3'b000; // Load
            7'b0100011: mem_op <= 3'b001; // Store
            default: alu_op <= ADD;
          endcase
          
          pipeline_stage <= EXEC;
        end
        
        EXEC: begin
          alu_result <= regfile[rs1] + {{52{imm12[11]}}, imm12};
          pipeline_stage <= MEM;
        end
        
        MEM: begin
          if (mem_read) begin
            d_valid <= 1'b1;
            d_addr <= alu_result;
            if (d_ready) begin
              pipeline_stage <= WB;
            end
          end else if (mem_write) begin
            d_valid <= 1'b1;
            d_addr <= alu_result;
            d_wdata <= regfile[rs2];
            d_strb <= {(DATA_WIDTH/8){1'b1}};
            d_we <= 1'b1;
            if (d_ready) begin
              pipeline_stage <= WB;
            end
          end else begin
            pipeline_stage <= WB;
          end
        end
        
        WB: begin
          d_valid <= 1'b0;
          d_we <= 1'b0;
          if (reg_write && rd != 5'b00000) begin
            regfile[rd] <= (mem_read) ? d_rdata : alu_result;
          end
          pc <= pc + 4;
          pipeline_stage <= FETCH;
        end
      endcase
    end
  end

  // ALU Implementation
  always_comb begin
    case (alu_op)
      ADD: alu_result = regfile[rs1] + regfile[rs2];
      SUB: alu_result = regfile[rs1] - regfile[rs2];
      AND: alu_result = regfile[rs1] & regfile[rs2];
      OR:  alu_result = regfile[rs1] | regfile[rs2];
      XOR: alu_result = regfile[rs1] ^ regfile[rs2];
      SLL: alu_result = regfile[rs1] << regfile[rs2][5:0];
      SRL: alu_result = regfile[rs1] >> regfile[rs2][5:0];
      SRA: alu_result = $signed(regfile[rs1]) >>> regfile[rs2][5:0];
      ADDI: alu_result = regfile[rs1] + {{52{imm12[11]}}, imm12};
      default: alu_result = 64'h0;
    endcase
  end

endmodule : riscv_core
