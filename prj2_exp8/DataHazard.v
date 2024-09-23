module DataHazard(
    //input  wire        clk,
    //input  wire        reset,
    input  wire [ 4:0] rf_raddr1,
    input  wire [ 4:0] rf_raddr2,
    input  wire [31:0] rf_rdata1,
    input  wire [31:0] rf_rdata2,
    input  wire [ 2:0] rf_we_signals,
    input  wire [ 2:0] valid_signals,
    input  wire [14:0] rf_waddr_signals,
    input  wire [95:0] rf_wdata_signals,
    input  wire [ 1:0] ld_signals,

    output wire [31:0] rf_rdata1_bypassing,
    output wire [31:0] rf_rdata2_bypassing,
    output wire        Load_DataHazard

);
    wire        rf_we_EXE;
    wire        rf_we_MEM;
    wire        rf_we_WB;
    wire [ 4:0] rf_waddr_EXE;
    wire [ 4:0] rf_waddr_MEM;
    wire [ 4:0] rf_waddr_WB;
    wire [31:0] rf_wdata_EXE;
    wire [31:0] rf_wdata_MEM;
    wire [31:0] rf_wdata_WB;
    wire        ld_EXE;
    wire        ld_MEM;


    assign {rf_we_EXE, rf_we_MEM, rf_we_WB} = {rf_we_signals[2] && valid_signals[2], rf_we_signals[1] && valid_signals[1], rf_we_signals[0] && valid_signals[0]};
    assign {rf_waddr_EXE, rf_waddr_MEM, rf_waddr_WB} = rf_waddr_signals;
    assign {rf_wdata_EXE, rf_wdata_MEM, rf_wdata_WB} = rf_wdata_signals;
    assign {ld_EXE, ld_MEM} = ld_signals;

	wire [2:0] DataHazard_rs1;
	wire [2:0] DataHazard_rs2;

    assign DataHazard_rs1[0] = rf_we_EXE && |rf_raddr1 && rf_raddr1 == rf_waddr_EXE;
    assign DataHazard_rs1[1] = rf_we_MEM && |rf_raddr1 && rf_raddr1 == rf_waddr_MEM;
    assign DataHazard_rs1[2] = rf_we_WB  && |rf_raddr1 && rf_raddr1 == rf_waddr_WB;
    assign DataHazard_rs2[0] = rf_we_EXE && |rf_raddr2 && rf_raddr2 == rf_waddr_EXE;
    assign DataHazard_rs2[1] = rf_we_MEM && |rf_raddr2 && rf_raddr2 == rf_waddr_MEM;
    assign DataHazard_rs2[2] = rf_we_WB  && |rf_raddr2 && rf_raddr2 == rf_waddr_WB;

    assign rf_rdata1_bypassing = DataHazard_rs1[0] ? rf_wdata_EXE : 
                                 DataHazard_rs1[1] ? rf_wdata_MEM : 
                                 DataHazard_rs1[2] ? rf_wdata_WB  : rf_rdata1;
    assign rf_rdata2_bypassing = DataHazard_rs2[0] ? rf_wdata_EXE : 
                                 DataHazard_rs2[1] ? rf_wdata_MEM : 
                                 DataHazard_rs2[2] ? rf_wdata_WB  : rf_rdata2;

    assign Load_DataHazard = ld_EXE && (rf_raddr1 == rf_waddr_EXE && |rf_raddr1 || rf_raddr2 == rf_waddr_EXE && |rf_raddr2)
                          || ld_MEM && (rf_raddr1 == rf_waddr_MEM && |rf_raddr1 || rf_raddr2 == rf_waddr_MEM && |rf_raddr2);

// //cod lab
// 	assign Data_Hazard_rs1 = {rs1 == rd_RDWtoWB && RegWrite_RDWtoWB && |rs1, rs1 == rd_MEMtoRDW && RegWrite_MEMtoRDW && |rs1, 
// 								rs1 == rd_EXtoMEM && RegWrite_EXtoMEM && |rs1, rs1 == rd_IDtoEX && RegWrite_IDtoEX && |rs1};
// 	assign RF_rdata1_bypassing = Data_Hazard_rs1[0] ? Result :
// 								(Data_Hazard_rs1[1] ? ALUOut_EXtoMEM :
// 								(Data_Hazard_rs1[2] ? ALUOut_MEMtoRDW :
// 								(Data_Hazard_rs1[3] ? MDR_RDWtoWB : RF_rdata1)));
// 	assign Data_Hazard_rs2 = {rs2 == rd_RDWtoWB && RegWrite_RDWtoWB && |rs2, rs2 == rd_MEMtoRDW && RegWrite_MEMtoRDW && |rs2, 
// 								rs2 == rd_EXtoMEM && RegWrite_EXtoMEM && |rs2, rs2 == rd_IDtoEX && RegWrite_IDtoEX && |rs2};
// 	assign RF_rdata2_bypassing = Data_Hazard_rs2[0] ? Result :
// 								(Data_Hazard_rs2[1] ? ALUOut_EXtoMEM :
// 								(Data_Hazard_rs2[2] ? ALUOut_MEMtoRDW :
// 								(Data_Hazard_rs2[3] ? MDR_RDWtoWB : RF_rdata2)));
// 	assign LoadUse_Data_Hazard = MemRead_MEMtoRDW && (rd_MEMtoRDW == rs1 && |rs1 || rd_MEMtoRDW == rs2 && |rs2)
// 								|| MemRead_EXtoMEM && (rd_EXtoMEM == rs1 && |rs1 || rd_EXtoMEM == rs2 && |rs2)
// 								|| MemRead_IDtoEX && (rd_IDtoEX == rs1 && |rs1 || rd_IDtoEX == rs2 && |rs2);

endmodule