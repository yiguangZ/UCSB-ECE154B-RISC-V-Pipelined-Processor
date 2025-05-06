//==========================================================
// ucsbece154b_controller.v
//==========================================================
// ECE 154B, RISC-V pipelined processor 
// All Rights Reserved
// Copyright (c) 2024 UCSB ECE
// Distribution Prohibited
// Yiguang Zhu
// This module implements the control unit for the pipelined
// processor. It produces the control signals used in the datapath,
// pipelines them through the EX, MEM, and WB stages, and also
// performs hazard detection and forwarding.
//==========================================================

module ucsbece154b_controller (
    input                clk, reset,
    input         [6:0]  op_i, 
    input         [2:0]  funct3_i,
    input                funct7b5_i,
    input 	         ZeroE_i,
    input         [4:0]  Rs1D_i,
    input         [4:0]  Rs2D_i,
    input         [4:0]  Rs1E_i,
    input         [4:0]  Rs2E_i,
    input         [4:0]  RdE_i,
    input         [4:0]  RdM_i,
    input         [4:0]  RdW_i,
    output wire		 StallF_o,  
    output wire          StallD_o,
    output wire          FlushD_o,
    output wire    [2:0] ImmSrcD_o,
    output wire          PCSrcE_o,
    output reg     [2:0] ALUControlE_o,
    output reg           ALUSrcE_o,
    output wire          FlushE_o,
    output reg     [1:0] ForwardAE_o,
    output reg     [1:0] ForwardBE_o,
    output reg           MemWriteM_o,
    output reg          RegWriteW_o,
    output reg    [1:0] ResultSrcW_o, 
    output reg    [1:0] ResultSrcM_o
);


 `include "ucsbece154b_defines.vh"

//Control and PC Generation
  wire        RegWriteD;
  wire        ALUSrcD;
  wire        MemWriteD;
  wire [1:0]  ResultSrcD;
  wire        BranchD;
  wire        JumpD;
  wire [1:0] ALUOp;
  reg JumpE, BranchE;

  assign PCSrcE_o = (ZeroE_i && BranchE) || JumpE;


  // Control logic
  reg [11:0] controls;
  assign {RegWriteD, ImmSrcD_o, ALUSrcD, MemWriteD, ResultSrcD, BranchD, ALUOp, JumpD} = controls;

  // Main Decode: produce 12-bit control word based on opcode.
  always @* begin
    case (op_i)
        instr_lw_op:        controls = {1'b1, imm_Itype, SrcB_imm, 1'b0, MuxResult_mem,    1'b0, ALUop_mem,   1'b0};
        instr_sw_op:        controls = {1'b0, imm_Stype, SrcB_imm, 1'b1, MuxResult_aluout, 1'b0, ALUop_mem,   1'b0};
        instr_Rtype_op:     controls = {1'b1, 3'b000,    SrcB_reg, 1'b0, MuxResult_aluout, 1'b0, ALUop_other, 1'b0};
        instr_beq_op:       controls = {1'b0, imm_Btype, SrcB_reg, 1'b0, MuxResult_aluout, 1'b1, ALUop_beq,   1'b0};
        instr_ItypeALU_op:  controls = {1'b1, imm_Itype, SrcB_imm, 1'b0, MuxResult_aluout, 1'b0, ALUop_other, 1'b0};
        instr_jal_op:       controls = {1'b1, imm_Jtype, SrcB_imm, 1'b0, MuxResult_PCPlus4,1'b0, ALUop_other, 1'b1};
        instr_lui_op:       controls = {1'b1, imm_Utype, SrcB_imm, 1'b0, MuxResult_imm,    1'b0, ALUop_other, 1'b0};
        default: begin
            controls = 12'b0_000_0_0_00_0_00_0;
            `ifdef SIM
                $warning("Unsupported op given: %h", op_i);
            `endif
        end
    endcase
end
  // --- ALU Decoder ---
  reg [2:0] ALUControlD;
  wire RtypeSub;
  assign RtypeSub = funct7b5_i & op_i[5];


  always @(*) begin
    case (ALUOp)
      ALUop_mem:  ALUControlD = ALUcontrol_add;
      ALUop_beq:  ALUControlD = ALUcontrol_sub;
      ALUop_other: begin
         case (funct3_i)
           instr_addsub_funct3: ALUControlD = RtypeSub ? ALUcontrol_sub : ALUcontrol_add;
           instr_slt_funct3:    ALUControlD = ALUcontrol_slt;
           instr_or_funct3:     ALUControlD = ALUcontrol_or;
           instr_and_funct3:    ALUControlD = ALUcontrol_and;
           default:             ALUControlD = 3'bxxx;
         endcase
      end
      default: ALUControlD = 3'bxxx;
    endcase
  end

 //========================================================
  // E-STAGE CONTROL
  //========================================================
reg RegWriteE;
reg MemWriteE; 
reg [1:0] ResultSrcE;
always @(posedge clk or posedge reset) begin
    if (reset) begin
        RegWriteE <= 0;
        JumpE <= 0;
        ResultSrcE <= 2'b0;
        ALUControlE_o <= 3'b0;
        ALUSrcE_o <= 0;
        BranchE <= 0;
        MemWriteE <= 0;
    end else if (FlushE_o) begin
        MemWriteE <= 0;
        BranchE <= 0;
        ALUSrcE_o <= 0;
        RegWriteE <= 0;
        ALUControlE_o <= 3'b0;
        JumpE <= 0;
        ResultSrcE <= 2'b0;
    end else begin
        JumpE <= JumpD;
        ALUControlE_o <= ALUControlD;
        BranchE <= BranchD;
        ResultSrcE <= ResultSrcD;
        RegWriteE <= RegWriteD;
        ALUSrcE_o <= ALUSrcD;
        MemWriteE <= MemWriteD;
    end
end
  // --- M Stage Control ---
  reg RegWriteM; 
  reg [1:0] ResultSrcM;
always @(posedge clk or posedge reset) begin
    if (reset) begin
        ResultSrcM <= 2'b0;
        RegWriteM <= 0;
        MemWriteM_o <= 0;
        ResultSrcM_o <= 0;
    end else begin
        ResultSrcM <= ResultSrcE;
        MemWriteM_o <= MemWriteE;
        RegWriteM <= RegWriteE;
        ResultSrcM_o <= ResultSrcE;
    end
end

// --- W Stage Control ---
always @(posedge clk or posedge reset) begin
    if (reset) begin
        ResultSrcW_o <= 0;
        RegWriteW_o <= 0;
    end else begin
        ResultSrcW_o <= ResultSrcM;
        RegWriteW_o <= RegWriteM;
    end
end

//--- Forwarding Unit ---
always @* begin
    ForwardAE_o = 2'b00;
    if (Rs1E_i != 0) begin
        if ((Rs1E_i == RdM_i) && RegWriteM)
            ForwardAE_o = 2'b10;
        else if ((Rs1E_i == RdW_i) && RegWriteW_o)
            ForwardAE_o = 2'b01;
    end

    ForwardBE_o = 2'b00;
    if (Rs2E_i != 0) begin
        if ((Rs2E_i == RdM_i) && RegWriteM)
            ForwardBE_o = 2'b10;
        else if ((Rs2E_i == RdW_i) && RegWriteW_o)
            ForwardBE_o = 2'b01;
    end
end
  // --- Stall & Flush Logic ---
  wire lwStall = ((Rs1D_i == RdE_i) || (Rs2D_i == RdE_i)) && ResultSrcE[0];
  assign StallF_o = lwStall;
  assign StallD_o = lwStall;
  assign FlushD_o = PCSrcE_o;
  assign FlushE_o = lwStall || PCSrcE_o;

endmodule

