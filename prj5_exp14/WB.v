`include "mycpu_head.vh"
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
    output wire        WB_allowin,

    input  wire [`MEM_TO_WB_EXCEP_WIDTH-1:0] MEM_to_WB_excep_signal,
    output wire [`WB_TO_IF_CSR_DATA_WIDTH-1:0] WB_to_IF_csr_data,
    output wire WB_flush,
    output wire has_int


);

wire        wb_res_from_csr;
wire [13:0] wb_csr_num;
wire        wb_csr_we;
wire [31:0] wb_csr_wmask;
wire [31:0] wb_csr_wvalue;
wire        wb_ertn_flush;
wire        wb_excep;
wire [ 5:0] wb_csr_ecode;
wire [ 8:0] wb_csr_esubcode;

wire [31:0] csr_rvalue;
wire [31:0] ex_entry;
wire        wb_ertn_flush_valid;
wire        wb_excep_valid;

wire [31:0] wb_vaddr;
wire        wb_has_int;
wire        wb_excp_adef;
wire        wb_excp_syscall;
wire        wb_excp_break;
wire        wb_excp_ale;
wire        wb_excp_ine;

assign {wb_res_from_csr, wb_csr_num, wb_csr_we, wb_csr_wmask, wb_csr_wvalue, 
            wb_ertn_flush, wb_has_int, wb_excp_adef, wb_excp_syscall, wb_excp_break,
            wb_excp_ale, wb_vaddr, wb_excp_ine
            } = MEM_to_WB_excep_signal;
assign wb_excep = wb_excp_adef | wb_excp_syscall | wb_excp_break | wb_excp_ale | wb_excp_ine | wb_has_int;

assign wb_csr_ecode = wb_has_int        ? `ECODE_INT :
                        wb_excp_adef      ? `ECODE_ADEF :
                        wb_excp_ine       ? `ECODE_INE :
                        wb_excp_syscall   ? `ECODE_SYS :
                        wb_excp_break     ? `ECODE_BRK :
                        wb_excp_ale       ? `ECODE_ALE :
                        6'b0;
assign wb_csr_esubcode = 9'b0;

assign wb_ertn_flush_valid  = wb_ertn_flush & valid;
assign wb_excep_valid       = wb_excep & valid;

wire [31:0] pc_WB;

//exp12 订正的bug：
// csr_we要特别注意，由于在mycpu_top.v中即使传进WB来的valid是0，但由于没有限制这个传，
// 之前可能的excep相关的错误信号也会传进MEM_to_WB_excep_signal(但由于WB_valid=0,是无效信号)
// 但若不对csr_we限制（限制valid=1时才有效），这个csr_we可能会在WB_valid=0时（即本级信号无效时）起作用
// 因此专门设计如下信号处理
wire wb_valid_csr_we;
assign wb_valid_csr_we = wb_csr_we & valid;


csr my_csr(
    .clk(clk),
    .reset(reset),
    .csr_num(wb_csr_num),
    .csr_we(wb_valid_csr_we),
    .csr_wmask(wb_csr_wmask),
    .csr_wvalue(wb_csr_wvalue),
    .ertn_flush(wb_ertn_flush_valid),
    .wb_ex(wb_excep_valid),
    .wb_ecode(wb_csr_ecode), 
    .wb_esubcode(wb_csr_esubcode), 
    .wb_vaddr(wb_vaddr),
    .wb_pc(pc_WB),

    .csr_rvalue(csr_rvalue),
    .ex_entry(ex_entry),

    .has_int(has_int)
);

assign WB_flush = wb_ertn_flush_valid | wb_excep_valid;

assign WB_to_IF_csr_data = {wb_ertn_flush_valid, wb_excep_valid, ex_entry, csr_rvalue};

wire [31:0] final_result;

wire        rf_we_WB;
assign {pc_WB, rf_we_WB, rf_waddr, final_result} = signal;
assign rf_we = rf_we_WB && valid && !wb_excep;
assign rf_wdata = wb_res_from_csr ? csr_rvalue : final_result;


assign debug_wb_pc       = pc_WB;
assign debug_wb_rf_we    = {4{rf_we}};
assign debug_wb_rf_wnum  = rf_waddr;
assign debug_wb_rf_wdata = rf_wdata;

assign WB_readygo = 1'b1;
assign WB_allowin = WB_readygo;
endmodule