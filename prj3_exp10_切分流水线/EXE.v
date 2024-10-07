module exe_stage(
    input  wire        clk,
    input  wire        reset,
    input  wire        valid,
    input  wire [157:0]signal,
    input  wire        MEM_allowin,

    output wire        data_sram_en,
    output wire [ 3:0] data_sram_we,
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata,
    output wire        MEM_signal_valid,
    output wire [70:0] MEM_signal,
    output wire        ld_EXE,
    output wire        EXE_readygo,
    output wire        EXE_allowin,

    output wire [32:0] mul_signals
);
wire        rf_we;
wire        rf_we_EXE;
wire [ 4:0] rf_waddr;
wire [31:0] rkd_value;
wire [ 3:0] mem_we;
wire        res_from_mem;
wire [18:0] alu_op;
wire [31:0] alu_src1;
wire [31:0] alu_src2;
wire [31:0] alu_result;
wire [31:0] pc_EXE;
wire        complete;

assign {pc_EXE, rf_we_EXE, rf_waddr, rkd_value, res_from_mem, mem_we, alu_op, alu_src1, alu_src2} = signal;

alu u_alu(
    .clk        (clk       ),
    .reset      (reset     ),
    .alu_op     (alu_op    ),
    .alu_src1   (alu_src1  ),
    .alu_src2   (alu_src2  ),
    .alu_result (alu_result),
    .complete   (complete  ),
    .mul_valid  (mul_signals[32]),
    .mul_result (mul_signals[31:0])
    );

assign data_sram_en    = (res_from_mem || (|mem_we)) && valid;
assign data_sram_we    = mem_we & {4{valid}};
assign data_sram_addr  = alu_result;// 不可能是mul_result
assign data_sram_wdata = rkd_value;

assign rf_we = rf_we_EXE;
assign MEM_signal_valid = valid;
assign MEM_signal = {pc_EXE, res_from_mem, rf_we, rf_waddr, alu_result};
assign ld_EXE = res_from_mem && valid;
//assign EXE_readygo = 1'b1;
assign EXE_readygo = complete;
assign EXE_allowin = EXE_readygo && MEM_allowin;

endmodule