module if_stage(
    input  wire        clk,
    input  wire        reset,
    input  wire        valid,
    input  wire [31:0] inst_sram_rdata,
    input  wire [32:0] br_signal,//{32：32}br_taken, {31：0}br_target
    input  wire        ID_allowin,//暂时不考虑上一节所说的转移指令在译码阶段等待延迟槽指令取回，所以ID_allowin恒为1

    output wire [ 3:0] inst_sram_we,
    output wire        inst_sram_en,
    output wire [31:0] inst_sram_addr,
    output wire [31:0] inst_sram_wdata,
    output wire        IF_readygo,
    output wire        IDsignal_valid,//IF to ID signals : pc_ID
    output wire [63:0] ID_signal
);
wire [31:0] nextpc;
reg  [31:0] pc;
wire [31:0] seq_pc;
wire br_taken;
wire [31:0] br_target;
wire [31:0] inst;

assign inst_sram_we    = 4'b0;
assign inst_sram_en    = ID_allowin && !reset;
assign inst_sram_addr  = ID_allowin ? nextpc : pc;//提前更新inst_sram_addr, 使得下一拍pc与指令同步更新
assign inst_sram_wdata = 32'b0;
assign inst            = inst_sram_rdata;

assign {br_taken, br_target} = br_signal;
assign seq_pc = pc + 3'h4;

assign nextpc = br_taken ? br_target : seq_pc;

always @(posedge clk) begin
    if (reset) begin
        pc <= 32'h1bfffffc;     //trick: to make nextpc be 0x1c000000 during reset 
    end
    else if (ID_allowin) begin
        pc <= nextpc;
    end
end

assign IF_readygo = 1'b1;
assign IDsignal_valid = valid && !br_taken;
assign ID_signal ={inst, pc};

endmodule
