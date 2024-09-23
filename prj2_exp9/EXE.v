module exe_stage(
    input  wire        clk,
    input  wire        reset,
    input  wire        valid,
    input  wire [150:0]signal,
    input  wire        MEM_allowin,

    output wire        data_sram_en,
    output wire [ 3:0] data_sram_we,
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata,
    output wire        MEM_signal_valid,
    output wire [70:0] MEM_signal,
    output wire        ld_EXE,
    output wire        EXE_readygo,
    output wire        EXE_allowin
);
wire        rf_we;
wire        rf_we_EXE;
wire [ 4:0] rf_waddr;
wire [31:0] rkd_value;
wire [ 3:0] mem_we;
wire        res_from_mem;
wire [11:0] alu_op;
wire [31:0] alu_src1;
wire [31:0] alu_src2;
wire [31:0] alu_result;
wire [31:0] pc;

//wire [] other_signal;
assign {pc, rf_we_EXE, rf_waddr, rkd_value, res_from_mem, mem_we, alu_op, alu_src1, alu_src2} = signal;

alu u_alu(
    .alu_op     (alu_op    ),
    .alu_src1   (alu_src1  ),
    .alu_src2   (alu_src2  ),
    .alu_result (alu_result)
    );

assign data_sram_en    = (res_from_mem || (|mem_we)) && valid;
assign data_sram_we    = mem_we & {4{valid}};//注意按位与不能写成逻辑与, 否则向内存只写入低8位且不报错, 后续读内存会错误
assign data_sram_addr  = alu_result;
assign data_sram_wdata = rkd_value;

assign rf_we = rf_we_EXE;// && valid;
assign MEM_signal_valid = valid;
assign MEM_signal = {pc, res_from_mem, rf_we, rf_waddr, alu_result};//32+1+1+5+32
assign ld_EXE = res_from_mem && valid;
assign EXE_readygo = 1'b1;
assign EXE_allowin = EXE_readygo && MEM_allowin;

endmodule