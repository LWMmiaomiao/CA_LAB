`include "mycpu_head.vh"
module mem_stage(
    input  wire        clk,
    input  wire        reset,
    input  wire        valid,
    input  wire [76:0] signal,
    input  wire        WB_allowin,
    input  wire [31:0] data_sram_rdata,
    input  wire        data_sram_data_ok,

    output wire        WB_signal_valid,
    output wire [69:0] WB_signal,
    output wire        ld_MEM,
    output wire        MEM_readygo,
    output wire        MEM_allowin,

    input  wire [`EXE_TO_MEM_EXCEP_WIDTH-1:0] EXE_to_MEM_excep_signal,
    output wire [`MEM_TO_WB_EXCEP_WIDTH-1:0] MEM_to_WB_excep_signal,
    input wire MEM_flush,
    output wire MEM_to_EXE_excep
);
reg  [76:0] signal_reg;
reg  [`EXE_TO_MEM_EXCEP_WIDTH-1:0] excep_signal_reg;

wire        res_from_mem;
wire [31:0] mem_result;
wire [31:0] alu_result;
wire [31:0] pc_MEM;
wire        rf_we;
wire        rf_we_MEM;
wire [ 4:0] rf_waddr;
wire [31:0] final_result;
wire [31:0] shifted_data;
wire [31:0] extended_data;
wire EXE_to_MEM_data_req;
wire inst_ld_b, inst_ld_bu, inst_ld_h, inst_ld_hu, inst_ld_w;
assign {EXE_to_MEM_data_req, inst_ld_b, inst_ld_bu, inst_ld_h, inst_ld_hu, inst_ld_w, pc_MEM, res_from_mem, rf_we_MEM, rf_waddr, alu_result} = signal;

wire        mem_res_from_csr;
wire [13:0] mem_csr_num;
wire        mem_csr_we;
wire [31:0] mem_csr_wmask;
wire [31:0] mem_csr_wvalue;
wire        mem_ertn_flush;
wire        mem_excep;
wire        mem_has_int;

wire        mem_excp_adef;
wire        mem_excp_syscall;
wire        mem_excp_break;
wire        mem_excp_ale;
wire        mem_excp_ine;
//exp14
wire wait_data_ok;

reg  [31:0] data_buf;
reg  data_buf_valid;
assign wait_data_ok  = EXE_to_MEM_data_req & valid & ~MEM_flush;


always @(posedge clk) begin// data buffer
    if(reset) begin
        data_buf <= 32'b0;
        data_buf_valid <= 1'b0;
    end
    else if(valid && MEM_allowin && MEM_readygo)   // 缓存已经流向下一流水级
        data_buf_valid <= 1'b0;
    else if(~data_buf_valid & data_sram_data_ok & valid) begin
        data_buf <= data_sram_rdata;
        data_buf_valid <= 1'b1;
    end
end

assign {mem_res_from_csr, mem_csr_num, mem_csr_we, mem_csr_wmask, mem_csr_wvalue, 
            mem_ertn_flush, mem_has_int, mem_excp_adef, mem_excp_syscall, mem_excp_break,
            mem_excp_ale, mem_excp_ine
            } = EXE_to_MEM_excep_signal;
assign MEM_to_WB_excep_signal = {mem_res_from_csr, mem_csr_num, mem_csr_we, mem_csr_wmask, mem_csr_wvalue, 
                            mem_ertn_flush, mem_has_int, mem_excp_adef, mem_excp_syscall, mem_excp_break,
                            mem_excp_ale, alu_result, mem_excp_ine};
assign mem_excep = mem_has_int | mem_excp_adef | mem_excp_syscall | mem_excp_break | mem_excp_ale | mem_excp_ine;
assign MEM_to_EXE_excep =  (mem_ertn_flush | mem_excep) & valid;

assign mem_result   = data_buf_valid ? data_buf : data_sram_rdata;
assign shifted_data = mem_result >> {alu_result[1:0], 3'b000};
assign extended_data = {32{inst_ld_w}} & shifted_data |
                       {32{inst_ld_h}} & {{16{shifted_data[15]}}, shifted_data[15:0]} |
                       {32{inst_ld_hu}} & {{16{1'b0}}, shifted_data[15:0]} |
                       {32{inst_ld_b}} & {{24{shifted_data[7]}}, shifted_data[7:0]} |
                       {32{inst_ld_bu}} & {{24{1'b0}}, shifted_data[7:0]};

assign final_result = res_from_mem ? extended_data : alu_result;

assign rf_we = rf_we_MEM;
assign WB_signal_valid = valid && ~MEM_flush && MEM_readygo;
assign WB_signal = {pc_MEM, rf_we, rf_waddr, final_result};
assign ld_MEM = res_from_mem && valid;
//assign MEM_readygo = data_sram_data_ok;
assign MEM_readygo = !wait_data_ok || wait_data_ok && data_sram_data_ok;
assign MEM_allowin = MEM_readygo && WB_allowin || MEM_flush || !valid;

endmodule