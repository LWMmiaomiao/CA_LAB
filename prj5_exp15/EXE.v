`include "mycpu_head.vh"
module exe_stage(
    input  wire        clk,
    input  wire        reset,
    input  wire        valid,
    input  wire [169:0]signal,
    input  wire        MEM_allowin,
    input  wire        data_sram_addr_ok,

    output wire        data_sram_req,
    output wire        data_sram_wr,
    output wire [ 1:0] data_sram_size,
    output wire [ 3:0] data_sram_wstrb,
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata,
    output wire        MEM_signal_valid,
    output wire [76:0] MEM_signal,
    output wire        ld_EXE,
    output wire        EXE_readygo,
    output wire        EXE_allowin,

    input  wire [`ID_TO_EXE_EXCEP_WIDTH-1:0] ID_to_EXE_excep_signal,
    output wire [`EXE_TO_MEM_EXCEP_WIDTH-1:0] EXE_to_MEM_excep_signal,
    input  wire EXE_flush,
    input  wire MEM_to_EXE_excep

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
wire [31:0] exe_result;
wire [31:0] pc_EXE;
wire        complete;
wire inst_st_b, inst_st_h, inst_st_w, inst_ld_b, inst_ld_bu, inst_ld_h, inst_ld_hu, inst_ld_w;
wire [ 1:0] ale_valid;
wire [ 1:0] rdcntv_valid;

assign {rdcntv_valid, ale_valid, pc_EXE, rf_we_EXE, rf_waddr, rkd_value, res_from_mem, mem_we, alu_op, alu_src1, alu_src2,
        inst_st_b, inst_st_h, inst_st_w, inst_ld_b, inst_ld_bu, inst_ld_h, inst_ld_hu, inst_ld_w
} = signal;

//exp12

wire        ex_res_from_csr;
wire [13:0] ex_csr_num;
wire        ex_csr_we;
wire [31:0] ex_csr_wmask;
wire [31:0] ex_csr_wvalue;
wire        ex_ertn_flush;

wire        ex_excp_adef;
wire        ex_excp_syscall;
wire        ex_excp_break;
wire        ex_excp_ale;
wire        ex_excp_ine;

assign {ex_res_from_csr, ex_csr_num, ex_csr_we, ex_csr_wmask, ex_csr_wvalue, 
            ex_ertn_flush, ex_has_int, ex_excp_adef, ex_excp_syscall, ex_excp_break,
            ex_excp_ine
            } = ID_to_EXE_excep_signal;

//exp13 TODO
assign ex_excp_ale     = ((|alu_result[1:0]) & ale_valid[1] |
                            alu_result[0] & ale_valid[0]) & valid;

assign EXE_to_MEM_excep_signal = {ex_res_from_csr, ex_csr_num, ex_csr_we, ex_csr_wmask, ex_csr_wvalue, 
                            ex_ertn_flush, ex_has_int, ex_excp_adef, ex_excp_syscall, ex_excp_break,
                            ex_excp_ale, ex_excp_ine};

/*EXE 内部定时器*/
reg  [63:0] es_timer_cnt;
wire [31:0] rdcntv_value;
always @(posedge clk) begin
    if(reset)
        es_timer_cnt <= 64'b0;
    else   
        es_timer_cnt <= es_timer_cnt + 1'b1;
end
assign rdcntv_value = {32{rdcntv_valid[1]}} & es_timer_cnt[63:32] |  {32{rdcntv_valid[0]}} & es_timer_cnt[31: 0];

alu u_alu(
    .clk        (clk       ),
    .reset      (reset     ),
    .alu_op     (alu_op    ),
    .alu_src1   (alu_src1  ),
    .alu_src2   (alu_src2  ),
    .alu_result (alu_result),
    .complete   (complete  )
    );

wire [3:0] mem_we_mask;
wire       es_mem_req;
assign mem_we_mask = {4{inst_st_b}} & {alu_result[1:0] == 2'b11, alu_result[1:0] == 2'b10, alu_result[1:0] == 2'b01, alu_result[1:0] == 2'b00} | 
                   {4{inst_st_h}} & {alu_result[1:0] == 2'b10, alu_result[1:0] == 2'b10, alu_result[1:0] == 2'b00, alu_result[1:0] == 2'b00} |
                   {4{inst_st_w}};
assign es_mem_req = res_from_mem | (|mem_we_mask);
assign data_sram_req   = es_mem_req && valid && MEM_allowin;
assign data_sram_wr    = (|data_sram_wstrb) && valid && !ex_excp_ale && !EXE_flush && !MEM_to_EXE_excep;
assign data_sram_wstrb = mem_we_mask;
assign data_sram_size  = {2{inst_st_b}} & 2'b0 | {2{inst_st_h}} & 2'b1 | {2{inst_st_w}} & 2'd2;
// assign data_sram_en    = (res_from_mem || (|mem_we)) && valid 
//                     && ~EXE_flush && ~MEM_to_EXE_excep; // MEM或WB流水级是ertn或异常，EXE是store，就得停下
// assign data_sram_we    = mem_we & {4{valid && !ex_excp_ale}} & mem_we_mask;//ALE 拒绝写入
assign data_sram_addr  = alu_result;
assign data_sram_wdata = {32{inst_st_b}} & {4{rkd_value[ 7:0]}} |
                         {32{inst_st_h}} & {2{rkd_value[15:0]}} |
                         {32{inst_st_w}} & rkd_value;

assign rf_we = rf_we_EXE;
assign MEM_signal_valid = valid && !EXE_flush;
assign exe_result = (rdcntv_valid[0] || rdcntv_valid[1]) ? rdcntv_value : alu_result;
assign MEM_signal = {es_mem_req, inst_ld_b, inst_ld_bu, inst_ld_h, inst_ld_hu, inst_ld_w, pc_EXE, res_from_mem, rf_we, rf_waddr, exe_result};
assign ld_EXE = res_from_mem && valid;
//assign EXE_readygo = 1'b1;
assign EXE_readygo = complete && (!data_sram_req || data_sram_req && data_sram_addr_ok);
assign EXE_allowin = !valid || EXE_readygo && MEM_allowin || EXE_flush;

endmodule


