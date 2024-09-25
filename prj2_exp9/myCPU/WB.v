module wb_stage(
    input  wire        clk,
    input  wire        reset,
    input  wire        valid,
    input  wire [69:0] signal,
 
    output wire [31:0] debug_wb_pc,
    output wire [ 3:0] debug_wb_rf_we,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata,
    output wire [ 4:0] rf_waddr,
    output wire [31:0] rf_wdata,
    output wire        rf_we,
    output wire        WB_readygo,
    output wire        WB_allowin
);
wire [31:0] pc_WB;
wire [31:0] final_result;

wire        rf_we_WB;
assign {pc_WB, rf_we_WB, rf_waddr, final_result} = signal;
assign rf_we = rf_we_WB && valid;

assign rf_wdata = final_result;

assign debug_wb_pc       = pc_WB;
assign debug_wb_rf_we    = {4{rf_we}};
assign debug_wb_rf_wnum  = rf_waddr;
assign debug_wb_rf_wdata = final_result;

assign WB_readygo = 1'b1;
assign WB_allowin = WB_readygo;
endmodule