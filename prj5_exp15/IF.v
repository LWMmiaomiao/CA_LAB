`include "mycpu_head.vh"
module if_stage(
    input  wire        clk,
    input  wire        reset,
    //input  wire        valid,
    input  wire [31:0] inst_sram_rdata,
    input  wire [32:0] br_signal,// br_taken, br_target
    input  wire        ID_allowin,

    output wire        inst_sram_req,
    output wire        inst_sram_wr,
    output wire [ 1:0] inst_sram_size,
    output wire [ 3:0] inst_sram_wstrb,
    output wire [31:0] inst_sram_addr,
    output wire [31:0] inst_sram_wdata,
    input  wire        inst_sram_addr_ok,
    input  wire        inst_sram_data_ok,
    output wire        IF_readygo,
    output wire        IF_allowin,
    output wire        IDsignal_valid,
    output wire [64:0] ID_signal,

    input wire  [`WB_TO_IF_CSR_DATA_WIDTH - 1:0] WB_to_IF_csr_data,
    input wire  IF_flush,
    input wire  br_stall,
    input wire  [3:0] axi_arid
);
reg valid;
wire [31:0] inst;
reg  [31:0] inst_buf;

wire [31:0] nextpc;
reg  [31:0] pc_IF;
wire        excp_adef;
wire [31:0] seq_pc;

reg inst_buf_valid;
wire inst_discard;
reg [3:0] inst_discard_num;
wire IF_cancel;
wire IF_adef_excep;
reg pre_cancel;

//------------------------------pre-IF---------------------------------------//
wire [31:0] csr_rvalue;
reg  [31:0] csr_rvalue_reg;
wire [31:0] ex_entry;
reg  [31:0] ex_entry_reg;
wire        wb_ertn_flush_valid;
reg         ertn_valid_reg;
wire        wb_csr_ex_valid;
reg         csr_valid_reg;
wire        br_taken;
reg         br_taken_reg;
wire [31:0] br_target;
reg  [31:0] br_target_reg;

wire pre_readygo;
//wire pre_allowin;// 暂时没用
wire to_fs_valid;

assign pre_readygo = inst_sram_req & inst_sram_addr_ok; // 地址请求接收
assign to_fs_valid = pre_readygo & IF_allowin & ~pre_cancel & ~IF_flush;
// assign pre_cancel  = 1'b0;
// assign inst_sram_we    = 4'b0;
// assign inst_sram_en    = ID_allowin && !reset;
// assign inst_sram_addr  = ID_allowin ? nextpc : pc_IF;//提前更新inst_sram_addr, 使得下一拍pc与指令同步更新
// assign inst_sram_wdata = 32'b0;
assign inst             = inst_buf_valid ? inst_buf : inst_sram_rdata;
assign inst_sram_req    = IF_allowin && ~reset && ~br_stall && ~pre_cancel;//&& !br_stall;// br_stall
assign inst_sram_wr     = |inst_sram_wstrb;
assign inst_sram_size   = 2'b10;
assign inst_sram_wstrb  = 4'b0;
assign inst_sram_addr   = nextpc;
assign inst_sram_wdata  = 32'b0;

assign {br_taken, br_target} = br_signal;

always @(posedge clk) begin
    if(reset) begin
        {ertn_valid_reg, csr_valid_reg, br_taken_reg} <= 3'b0;
        {csr_rvalue_reg, ex_entry_reg, br_target_reg} <= {3{32'b0}};
    end
    // 当前仅当遇到if_cancel时未等到pre_readygo，需要将cancel相关信号存储在寄存器
    
    //wqq:对上述这条注释提出质疑：为何与pre_readygo有关？准备flush的前一周期也可能pre_readygo,
    // 进而让本该存入寄存器的ex信号没存进去
    // 故以下去掉！pre_readygo
    else if(wb_csr_ex_valid) begin
        ex_entry_reg <= ex_entry;
        csr_valid_reg <= 1'b1;
    end
    else if(wb_ertn_flush_valid) begin
        csr_rvalue_reg <= csr_rvalue;
        ertn_valid_reg <= 1'b1;
    end    
    else if(br_taken) begin
        br_target_reg <= br_target;
        br_taken_reg <= 1'b1;
    end
    // 若对应地址已经获得了来自指令SRAM的ok，后续nextpc不再从寄存器中取
    else if(pre_readygo) begin
        {ertn_valid_reg, csr_valid_reg, br_taken_reg} <= 3'b0;
    end
end
assign seq_pc = pc_IF + 3'h4;
assign nextpc = ertn_valid_reg ? csr_rvalue_reg 
            : wb_ertn_flush_valid ? csr_rvalue 
            : csr_valid_reg ? ex_entry_reg 
            : wb_csr_ex_valid ? ex_entry 
            : br_taken_reg ? br_target_reg 
            : br_taken ? br_target 
            : seq_pc;

//-------------------------------IF------------------------------------------//

always @(posedge clk) begin
    if (reset)
        valid <= 1'b0;
    else if(IF_allowin) begin
        valid <= to_fs_valid;
    end
    else if(IF_cancel) begin
        valid <= 1'b0;// 位于取指阶段的指令可能因为等待指令取回而停留
    end
end

//br_stall_reg暂存br_stall_reg
reg br_stall_reg;
always @(posedge clk) begin
    if(reset) begin
        br_stall_reg <= 1'b0;
    end
    else if(br_stall) begin
        br_stall_reg <= br_stall;
    end
    else if(to_fs_valid && IF_allowin) begin //阻塞结束？
        br_stall_reg <= 1'b0;
    end
end

//pre_cancel 发了请求还没握手，这时候cancel
//inst_discard 请求地址一握手，这时候cancel
//两个cancel信号

always @(posedge clk) begin
    if (reset)
        pre_cancel <= 1'b0;
    else if ((inst_sram_req | br_stall) // 正常情况下addr握手之前，inst_sram_req本来是一直拉高
     & (IF_cancel | ( (br_stall | br_stall_reg) & inst_sram_addr_ok) ) & ~axi_arid[0])
        pre_cancel <= 1'b1;
    else if (inst_sram_data_ok & ~inst_discard) //为了不与inst_discard冲突
        pre_cancel <= 1'b0;
end

always @(posedge clk) begin
    if(reset) begin
        inst_discard_num <= 4'b0;
    end
    else if(IF_cancel & (valid & ~IF_readygo))
        inst_discard_num <= inst_discard_num + 4'b1;
    else if(inst_discard & inst_sram_data_ok)
        inst_discard_num <= inst_discard_num - 4'b1;

end
assign inst_discard = |inst_discard_num;

/*
always @(posedge clk) begin
    if(reset)
        inst_discard <= 1'b0;
    // 流水级取消：当pre-IF阶段发送错误地址请求已被指令SRAM接受 or IF内有有效指令且正在等待数据返回时，需要丢弃一条指令
    else if(IF_cancel & ~IF_allowin & ~IF_readygo | pre_cancel & to_fs_valid) //TODO： 待修改
        inst_discard <= 1'b1;
    else if(inst_sram_data_ok)
        inst_discard <= 1'b0;
end
*/



always @(posedge clk) begin
    if(reset) begin
        inst_buf <= 32'b0;
        inst_buf_valid <= 1'b0;
    end
    else if(IF_readygo && valid && ID_allowin)   // 缓存已经流向下一流水级
        inst_buf_valid <= 1'b0;
    else if(IF_cancel)                  // IF取消后需要清空当前buffer
        inst_buf_valid <= 1'b0;
    else if(~inst_buf_valid & inst_sram_data_ok & ~inst_discard & ~pre_cancel) begin
        inst_buf <= inst;
        inst_buf_valid <= 1'b1;
    end
end

assign IF_cancel = wb_csr_ex_valid || wb_ertn_flush_valid || br_taken;

always @(posedge clk) begin
    if (reset) begin
        pc_IF <= 32'h1bfffffc;     //trick: to make nextpc be 0x1c000000 during reset 
    end
    else if (to_fs_valid && pre_readygo && IF_allowin) begin// LOAD_DH时pc会被阻塞
        //如果逻辑只有pre_readygo && IF_allowin,那么还没拿到inst，就传给pc_if对应的pc了，这很显然不对
        //得加上to_fs_valid（不valid的信号最好就别传！或者写成不valid就传0！）
        pc_IF <= nextpc;
    end
end

assign IF_readygo = (inst_sram_data_ok || inst_buf_valid) && ~inst_discard;// && valid
assign IF_allowin = (IF_readygo && ID_allowin) || !valid; //|| IF_flush || !valid;
assign IDsignal_valid = valid && !br_taken && ~IF_flush && IF_readygo;
assign excp_adef = (|pc_IF[1:0]) & valid;
assign ID_signal ={excp_adef, inst, pc_IF};

// WB to IF csr data
assign {wb_ertn_flush_valid, wb_csr_ex_valid, ex_entry, csr_rvalue} = WB_to_IF_csr_data;

endmodule
