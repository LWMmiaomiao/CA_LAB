module if_stage(
    input  wire        clk,
    input  wire        reset,
    input  wire        valid,
    input  wire [31:0] inst_sram_rdata,
    input  wire [32:0] br_signal,// br_taken, br_target
    input  wire        ID_allowin,

    output wire [ 3:0] inst_sram_we,
    output wire        inst_sram_en,
    output wire [31:0] inst_sram_addr,
    output wire [31:0] inst_sram_wdata,
    output wire        IF_readygo,
    output wire        IF_allowin,
    output wire        IDsignal_valid,
    output wire [63:0] ID_signal
);
wire [31:0] nextpc;
reg  [31:0] pc_IF;
wire [31:0] seq_pc;
wire br_taken;
wire [31:0] br_target;
wire [31:0] inst;

assign inst_sram_we    = 4'b0;
assign inst_sram_en    = ID_allowin && !reset;
assign inst_sram_addr  = ID_allowin ? nextpc : pc_IF;//提前更新inst_sram_addr, 使得下一拍pc与指令同步更新
assign inst_sram_wdata = 32'b0;
assign inst            = inst_sram_rdata;

assign {br_taken, br_target} = br_signal;
assign seq_pc = pc_IF + 3'h4;

assign nextpc = br_taken ? br_target : seq_pc;

always @(posedge clk) begin
    if (reset) begin
        pc_IF <= 32'h1bfffffc;     //trick: to make nextpc be 0x1c000000 during reset 
    end
    else if (ID_allowin) begin// LOAD_DH时pc会被阻塞
        pc_IF <= nextpc;
    end
end

assign IF_readygo = 1'b1;
assign IF_allowin = IF_readygo && ID_allowin;
assign IDsignal_valid = valid && !br_taken;
assign ID_signal ={inst, pc_IF};

endmodule
