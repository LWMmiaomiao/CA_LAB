`include "mycpu_head.vh"
module wb_stage(
    input  wire        clk,
    input  wire        reset,
    input  wire        valid,
    input  wire [`WB_SIGNAL_WIDTH - 1:0] signal,
 
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
    output wire [37:0] wb_rf_zip,

    //exp18 csr模块在WB外例化
    output wire [13:0] wb_csr_num,
    output wire        wb_valid_csr_we,
    output wire [31:0] wb_csr_wmask,
    output wire [31:0] wb_csr_wvalue,
    output wire        wb_ertn_flush_valid,
    output wire        wb_excep_valid,
    output wire [5:0]  wb_csr_ecode,
    output wire [8:0]  wb_csr_esubcode,
    output wire [31:0] wb_vaddr,
    output wire [31:0] pc_WB,
    
    input  wire [31:0] csr_rvalue,
    input  wire [31:0] ex_entry,
    input  wire        has_int,
    //注意！ has_int 在my_cpu去作用其他模块去

    input wire [`MEM_TO_WB_TLB_WIDTH-1:0] mem_to_wb_tlb,

    output wire         wb_csr_tlbrd, //to EXE
    input  wire  [ 3:0] csr_tlbidx_index, // from csr
    // tlbrd
    output wire         tlbrd_we, // to csr
    output wire  [ 3:0] r_index,  // to tlb
    // tlbwr and tlbfill, to tlb
    output wire  [ 3:0] w_index,
    output wire         tlb_we,
    // tlbsrch, to csr
    output wire         tlbsrch_we,
    output wire         tlbsrch_hit,
    output wire  [ 3:0] tlbsrch_hit_index,

    output wire [`WB_TO_IF_REFETCH_WIDTH-1:0] wb_to_if_refetch_data,

    input  wire  [ 3:0] ex_to_wb_rand

);
//exp18 tlb signals
wire        wb_inst_tlbsrch;
wire        wb_inst_tlbwr;
wire        wb_inst_tlbfill;
wire        wb_inst_tlbrd;
wire        wb_inst_invtlb;

wire        wb_tlb_refetch; // flush重取指
//除了tlbsrch用wb_inst_tlbsrch,剩下4个inst都用下面的valid信号
wire        wb_tlbwr_valid; 
wire        wb_tlbfill_valid;
wire        wb_tlbrd_valid;
wire        wb_invtlb_valid;

wire        wb_csr_tlbwr;
wire        wb_s1_found;
wire [ 3:0] wb_s1_index;

//csr
wire        wb_res_from_csr;
wire        wb_csr_we;
wire        wb_ertn_flush;
wire        wb_excep;

wire        wb_has_int;
wire        wb_excp_adef;
wire        wb_excp_syscall;
wire        wb_excp_break;
wire        wb_excp_ale;
wire        wb_excp_ine;
wire        wb_excp_inst_pif;
wire        wb_excp_inst_ppi;
wire        wb_excp_inst_tlbr;
wire        wb_excp_data_ppi;
wire        wb_excp_data_tlbr;
wire        wb_excp_data_pil;
wire        wb_excp_data_pis;
wire        wb_excp_data_pme;

assign {wb_excp_inst_pif, wb_excp_inst_ppi, wb_excp_inst_tlbr,
            wb_excp_data_ppi, wb_excp_data_tlbr, wb_excp_data_pil, wb_excp_data_pis, wb_excp_data_pme,
            wb_res_from_csr, wb_csr_num, wb_csr_we, wb_csr_wmask, wb_csr_wvalue, 
            wb_ertn_flush, wb_has_int, wb_excp_adef, wb_excp_syscall, wb_excp_break,
            wb_excp_ale, wb_vaddr, wb_excp_ine
            } = MEM_to_WB_excep_signal;
assign wb_excep = wb_excp_adef | wb_excp_syscall | wb_excp_break | wb_excp_ale | wb_excp_ine | wb_has_int |
                    wb_excp_inst_pif | wb_excp_inst_ppi | wb_excp_inst_tlbr | 
                    wb_excp_data_ppi | wb_excp_data_tlbr | wb_excp_data_pil | wb_excp_data_pis | wb_excp_data_pme;

assign wb_csr_ecode =   wb_has_int        ? `ECODE_INT :
                        wb_excp_adef      ? `ECODE_ADEF:
                        wb_excp_inst_tlbr ? `ECODE_TLBR:
                        wb_excp_inst_pif  ? `ECODE_PIF :
                        wb_excp_inst_ppi  ? `ECODE_PPI :
                        wb_excp_ine       ? `ECODE_INE :
                        wb_excp_syscall   ? `ECODE_SYS :
                        wb_excp_break     ? `ECODE_BRK :
                        wb_excp_ale       ? `ECODE_ALE :
                        wb_excp_data_tlbr ? `ECODE_TLBR:
                        wb_excp_data_pil  ? `ECODE_PIL :
                        wb_excp_data_pis  ? `ECODE_PIS :
                        wb_excp_data_ppi  ? `ECODE_PPI :
                        wb_excp_data_pme  ? `ECODE_PME :
                        6'b0;
assign wb_csr_esubcode = 9'b0;

assign wb_ertn_flush_valid  = wb_ertn_flush & valid;
assign wb_excep_valid       = wb_excep & valid;

//exp12 订正的bug：
// csr_we要特别注意，由于在mycpu_top.v中即使传进WB来的valid是0，但由于没有限制这个传，
// 之前可能的excep相关的错误信号也会传进MEM_to_WB_excep_signal(但由于WB_valid=0,是无效信号)
// 但若不对csr_we限制（限制valid=1时才有效），这个csr_we可能会在WB_valid=0时（即本级信号无效时）起作用
// 因此专门设计如下信号处理
assign wb_valid_csr_we = wb_csr_we & valid;

assign WB_flush = wb_ertn_flush_valid | wb_excep_valid | wb_tlb_refetch;

assign WB_to_IF_csr_data = {wb_ertn_flush_valid, wb_excep_valid, ex_entry, csr_rvalue};
assign wb_to_if_refetch_data = {wb_tlb_refetch, pc_WB};

wire [31:0] final_result;

wire        rf_we_WB;
wire inst_cacop;
assign {inst_cacop, pc_WB, rf_we_WB, rf_waddr, final_result} = signal;
assign rf_we = rf_we_WB && valid && !wb_excep;
assign rf_wdata = wb_res_from_csr ? csr_rvalue : final_result;
assign wb_rf_zip = {rf_we, rf_waddr, rf_wdata};
// ----------------- TLB signals ---------------------

assign {wb_s1_found, wb_s1_index, wb_inst_tlbsrch, wb_inst_tlbwr, 
        wb_inst_tlbfill, wb_inst_tlbrd, wb_inst_invtlb} = mem_to_wb_tlb;

assign wb_tlbwr_valid       = wb_inst_tlbwr & valid;
assign wb_tlbfill_valid     = wb_inst_tlbfill & valid;
assign wb_tlbrd_valid       = wb_inst_tlbrd & valid;
assign wb_invtlb_valid      = wb_inst_invtlb & valid;
assign wb_csr_tlbwr         = ((wb_csr_num == `CSR_ASID || wb_csr_num == `CSR_CRMD) 
                                && wb_csr_we) && valid;
//疑惑：感觉不需要这个wb_csr_tlbwr信号??
assign wb_csr_tlbrd = ((wb_csr_num == `CSR_ASID || wb_csr_num == `CSR_TLBEHI) && wb_csr_we
                            || wb_inst_tlbrd) && valid;
assign wb_tlb_refetch = wb_tlbwr_valid | wb_tlbfill_valid 
            | wb_tlbrd_valid | wb_invtlb_valid | wb_csr_tlbwr | (inst_cacop & valid);//这里有疑惑

// tlbrd
assign tlbrd_we = wb_inst_tlbrd;
assign r_index = csr_tlbidx_index;
// tlbwr and tlbfill
assign w_index = wb_inst_tlbwr ? csr_tlbidx_index : ex_to_wb_rand;
// tlbwr命令是用index；tlbfill按指令手册是硬件随机选择
assign tlb_we = wb_inst_tlbwr | wb_inst_tlbfill;
// tlbsrch (to csr)
assign tlbsrch_we = wb_inst_tlbsrch & valid;
assign tlbsrch_hit = wb_s1_found;
assign tlbsrch_hit_index = wb_s1_index;



assign debug_wb_pc       = pc_WB;
assign debug_wb_rf_we    = {4{rf_we}};
assign debug_wb_rf_wnum  = rf_waddr;
assign debug_wb_rf_wdata = rf_wdata;

assign WB_readygo = 1'b1;
assign WB_allowin = WB_readygo;
endmodule