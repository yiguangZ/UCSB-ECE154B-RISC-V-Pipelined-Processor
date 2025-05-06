// ucsbece154b_datapath.v
// ECE 154B, RISC-V pipelined processor 
// All Rights Reserved
// Yiguang Zhu
// Copyright (c) 2024 UCSB ECE
// Distribution Prohibited


module ucsbece154b_datapath (
    input                clk, reset,
    input                PCSrcE_i,
    input                StallF_i,
    output reg    [31:0] PCF_o,
    input                StallD_i,
    input                FlushD_i,
    input         [31:0] InstrF_i,
    output wire    [6:0] op_o,
    output wire    [2:0] funct3_o,
    output wire          funct7b5_o,
    input                RegWriteW_i,
    input          [2:0] ImmSrcD_i,
    output wire    [4:0] Rs1D_o,
    output wire    [4:0] Rs2D_o,
    input  wire          FlushE_i,
    output reg     [4:0] Rs1E_o,
    output reg     [4:0] Rs2E_o, 
    output reg     [4:0] RdE_o, 
    input                ALUSrcE_i,
    input          [2:0] ALUControlE_i,
    input          [1:0] ForwardAE_i,
    input          [1:0] ForwardBE_i,
    output               ZeroE_o,
    output reg     [4:0] RdM_o, 
    output reg    [31:0] ALUResultM_o,
    output reg    [31:0] WriteDataM_o,
    input         [31:0] ReadDataM_i,
    input          [1:0] ResultSrcW_i,
    output reg     [4:0] RdW_o,
    input          [1:0] ResultSrcM_i
);
`include "ucsbece154b_defines.vh"
//================================================
    // Fetch stage signals
    //================================================
    wire [31:0] PCNext;
    wire [31:0] PCPlus4F;

    //================================================
    // Decode stage signals
    //================================================
    reg [31:0] InstrD;
    reg [31:0] PCD, PCPlus4D;
    wire [31:0] RD1D, RD2D;
    reg  [31:0] ImmExtD;
    wire [4:0]  RdD;
    
    //================================================
    // Execute stage signals
    //================================================
    reg [31:0] RD1E, RD2E;
    reg [31:0] PCE, ImmExtE, PCPlus4E;
    wire [31:0] SrcAE, SrcBE,ALUResultE;
    wire [31:0] ForwardAE, ForwardBE;
    wire [31:0] ALUSrcBMux;
    wire [31:0] WriteDataE;
    wire [31:0] PCTargetE;                          
    //================================================
    // Memory stage signals
    //================================================
    reg [31:0] PCPlus4M;
    reg [31:0] ImmExtM;
    
    //================================================
    // Writeback stage signals
    //================================================
    reg [31:0] ALUResultW;
    reg [31:0] ReadDataW;
    reg [31:0] PCPlus4W;
    reg [31:0] ImmExtW;
    reg [31:0] ResultW;
    
   // Instruction
assign op_o = InstrD[6:0];
assign RdD = InstrD[11:7];
assign funct3_o = InstrD[14:12];
assign Rs1D_o = InstrD[19:15];
assign Rs2D_o = InstrD[24:20];
assign funct7b5_o = InstrD[30];

assign PCTargetE = PCE + ImmExtE;
assign PCPlus4F = PCF_o + 4;
assign PCNext = PCSrcE_i ? PCTargetE : PCPlus4F; 
assign WriteDataE = ForwardBE;
// Immediate Extension Unit
always @* begin
    case (ImmSrcD_i)
        imm_Itype: ImmExtD = {{20{InstrD[31]}}, InstrD[31:20]};               // I-type
        imm_Stype: ImmExtD = {{20{InstrD[31]}}, InstrD[31:25], InstrD[11:7]}; // S-type
        imm_Btype: ImmExtD = {{19{InstrD[31]}}, InstrD[31], InstrD[7], InstrD[30:25], InstrD[11:8], 1'b0}; // B-type
        imm_Jtype: ImmExtD = {{11{InstrD[31]}}, InstrD[31], InstrD[19:12], InstrD[20], InstrD[30:21], 1'b0}; // J-type
        imm_Utype: ImmExtD = {InstrD[31:12], 12'b0};                            // U-type
        default:   ImmExtD = 32'b0;
    endcase
end
ucsbece154b_rf rf (
    .clk(~clk),
    .a1_i(Rs1D_o),
    .a2_i(Rs2D_o),
    .a3_i(RdW_o),
    .rd1_o(RD1D),
    .rd2_o(RD2D),
    .we3_i(RegWriteW_i),
    .wd3_i(ResultW)
);

// ALU
ucsbece154b_alu alu (
    .a_i(SrcAE),
    .b_i(SrcBE),
    .alucontrol_i(ALUControlE_i),
    .result_o(ALUResultE),
    .zero_o(ZeroE_o)
);
//================================================
    // Fetch STAGE PIPELINE REGISTER
//================================================
always @(posedge clk or posedge reset) begin
    if (reset) begin
        PCPlus4D <= 32'b0;
        InstrD   <= 32'b0;
        PCD      <= 32'b0;
    end else if (FlushD_i) begin
        PCD      <= 32'b0;
        PCPlus4D <= 32'b0;
        InstrD   <= 32'b0;
    end else if (!StallD_i) begin
        PCPlus4D <= PCPlus4F;
        PCD      <= PCF_o;
        InstrD   <= InstrF_i;
    end
end
//================================================
// Decode STAGE PIPELINE REGISTER
//================================================
 always @(posedge clk or posedge reset) begin
    if (reset) begin
        PCPlus4E <= 32'b0;
        RD2E     <= 32'b0;
        Rs1E_o   <= 5'b0;
        RdE_o    <= 5'b0;
        ImmExtE  <= 32'b0;
        PCE      <= 32'b0;
        Rs2E_o   <= 5'b0;
        RD1E     <= 32'b0;
    end else if (FlushE_i) begin
        Rs2E_o   <= 5'b0;
        PCPlus4E <= 32'b0;
        ImmExtE  <= 32'b0;
        RD1E     <= 32'b0;
        PCE      <= 32'b0;
        Rs1E_o   <= 5'b0;
        RD2E     <= 32'b0;
        RdE_o    <= 5'b0;
    end else begin
        ImmExtE  <= ImmExtD;
        RD1E     <= RD1D;
        PCPlus4E <= PCPlus4D;
        PCE      <= PCD;
        Rs2E_o   <= Rs2D_o;
        RD2E     <= RD2D;
        RdE_o    <= RdD;
        Rs1E_o   <= Rs1D_o;
    end
end
//================================================
// Execute STAGE PIPELINE REGISTER
//================================================
always @(posedge clk or posedge reset) begin
    if (reset) begin
        PCPlus4M <= 32'b0;
        ImmExtM  <= 32'b0;
        RdM_o    <= 5'b0;
        ALUResultM_o <= 32'b0;
        WriteDataM_o <= 32'b0;
    end else begin
        PCPlus4M <= PCPlus4E;
        RdM_o    <= RdE_o;
        ALUResultM_o <= ALUResultE;
        WriteDataM_o <= WriteDataE;
        ImmExtM  <= ImmExtE;
    end
end
//================================================
// Memory STAGE PIPELINE REGISTER
//================================================
always @(posedge clk or posedge reset) begin
    if (reset) begin
        PCPlus4W <= 32'b0;
        RdW_o    <= 5'b0;
        ReadDataW <= 32'b0;
        ImmExtW  <= 32'b0;
        ALUResultW <= 32'b0;
    end else begin
        RdW_o    <= RdM_o;
        ALUResultW <= ALUResultM_o;
        PCPlus4W <= PCPlus4M;
        ImmExtW  <= ImmExtM;
        ReadDataW <= ReadDataM_i;
    end
end

//================================================
// FORWARDING
//================================================
assign ForwardAE = (ForwardAE_i == 2'b00) ? RD1E :
                          (ForwardAE_i == 2'b10) ? ALUResultM_o :
                          (ForwardAE_i == 2'b01) ? ResultW :
                          32'b0;

assign ForwardBE = (ForwardBE_i == 2'b00) ? RD2E :
                          (ForwardBE_i == 2'b10) ? ALUResultM_o :
                          (ForwardBE_i == 2'b01) ? ResultW :
                          32'b0;
// ALU source muxes
assign SrcAE = ForwardAE;
assign ALUSrcBMux = (ALUSrcE_i) ? ImmExtE : ForwardBE;
assign SrcBE = ALUSrcBMux;
        
// Result Source Mux
always @* begin
    case (ResultSrcW_i)
        2'b00: ResultW = ALUResultW;
        2'b01: ResultW = ReadDataW;
        2'b10: ResultW = PCPlus4W;
        2'b11: ResultW = ImmExtW;
        default: ResultW = 32'b0;
    endcase
end

// Update PC
always @(posedge clk or posedge reset) begin
    if (reset)
        PCF_o <= pc_start;
    else if (!StallF_i)
        PCF_o <= PCNext;
end

endmodule

