module mem_stage(
    input  wire        clk,
    input  wire        reset,
    input  wire        valid,
    input  wire [70:0] signal,
    input  wire        WB_allowin,
    input  wire [31:0] data_sram_rdata,

    //output wire [31:0] final_result,
    output wire        WB_signal_valid,
    output wire [69:0] WB_signal,
    output wire        ld_MEM,
    output wire        MEM_readygo,
    output wire        MEM_allowin
);

wire        res_from_mem;
wire [31:0] mem_result;
wire [31:0] alu_result;
wire [31:0] pc;
wire        rf_we;
wire        rf_we_MEM;
wire [ 4:0] rf_waddr;
wire [31:0] final_result;
assign {pc, res_from_mem, rf_we_MEM, rf_waddr, alu_result} = signal;
assign mem_result   = data_sram_rdata;
assign final_result = res_from_mem ? mem_result : alu_result;

assign rf_we = rf_we_MEM;// && valid;
assign WB_signal_valid = valid;
assign WB_signal = {pc, rf_we, rf_waddr, final_result};//32+1+5+32
assign ld_MEM = res_from_mem && valid;
assign MEM_readygo = 1'b1;
assign MEM_allowin = MEM_readygo && WB_allowin;

endmodule