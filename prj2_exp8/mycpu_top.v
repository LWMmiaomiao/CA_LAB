module mycpu_top(
    input  wire        clk,
    input  wire        resetn,
    // inst sram interface
    output wire [ 3:0] inst_sram_we,
    output wire [31:0] inst_sram_addr,
    output wire [31:0] inst_sram_wdata,
    input  wire [31:0] inst_sram_rdata,
    output wire        inst_sram_en,
    // data sram interface
    output wire [ 3:0] data_sram_we,
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata,
    input  wire [31:0] data_sram_rdata,
    output wire        data_sram_en,
    // trace debug interface
    output wire [31:0] debug_wb_pc,
    output wire [ 3:0] debug_wb_rf_we,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata
);
reg         reset;
always @(posedge clk) reset <= ~resetn;

wire [31:0] rf_rdata1_bypassing;
wire [31:0] rf_rdata2_bypassing;
wire        Load_DataHazard;

reg         valid;
wire        IF_allowin;
wire        br_taken_cancel;
wire [32:0] br_signal;
assign      br_taken_cancel = br_signal[32];
always @(posedge clk) begin
    if (reset)
        valid <= 1'b0;
    else if(IF_allowin) begin
        valid <= 1'b1;
    end
    else if(br_taken_cancel) begin
        valid <= 1'b0;// 位于取指阶段的指令可能因为等待指令取回而停留, 在本实验下用不到
    end
end



wire        ID_allowin;
wire [31:0] pc_ID;
wire        IF_readygo;
wire        IDsignal_valid;
wire [63:0] ID_signal;

if_stage if_stage(
    .clk(clk),
    .reset(reset),
    .valid(valid),
    .inst_sram_rdata(inst_sram_rdata),
    .br_signal(br_signal),
    .ID_allowin(ID_allowin),

    .inst_sram_we(inst_sram_we),
    .inst_sram_en(inst_sram_en),
    .inst_sram_addr(inst_sram_addr),
    .inst_sram_wdata(inst_sram_wdata),
    .IF_readygo(IF_readygo),
    .IF_allowin(IF_allowin),
    .IDsignal_valid(IDsignal_valid),
    .ID_signal(ID_signal)
);



reg [63:0] ID_signal_reg;
reg        IDsignal_valid_reg;
always @(posedge clk) begin
    if (reset) begin
        IDsignal_valid_reg <= 1'b0;
        ID_signal_reg      <= 64'b0;
    end
    else if(br_taken_cancel) begin
        IDsignal_valid_reg <= 1'b0;
    end
    else if (IF_readygo && ID_allowin) begin
        IDsignal_valid_reg <= IDsignal_valid;
        ID_signal_reg      <= ID_signal;
    end
end

wire [ 4:0] rf_raddr1;
wire [31:0] rf_rdata1;
wire [ 4:0] rf_raddr2;
wire [31:0] rf_rdata2;
wire        rf_we;
wire [ 4:0] rf_waddr;
wire [31:0] rf_wdata;
wire [11:0] alu_op;
wire [31:0] alu_src1;
wire [31:0] alu_src2;
wire        EXE_allowin;
wire        ID_readygo;
wire        EXE_signal_valid;
wire [150:0]EXE_signal;

//ID阶段得到的inst是上拍末IF中nextpc对应的指令
id_stage id_stage(
    .clk(clk),
    .reset(reset),
    .Load_DataHazard(Load_DataHazard),
    .valid(IDsignal_valid_reg),
    .signal(ID_signal_reg),
    .rf_rdata1(rf_rdata1_bypassing),
    .rf_rdata2(rf_rdata2_bypassing),
    .EXE_allowin(EXE_allowin),

    .rf_raddr1(rf_raddr1),
    .rf_raddr2(rf_raddr2),
    .br_signal(br_signal),
    .ID_readygo(ID_readygo),
    .ID_allowin(ID_allowin),
    .EXE_signal_valid(EXE_signal_valid),
    .EXE_signal(EXE_signal)
);



reg [150:0]EXE_signal_reg;
reg        EXEsignal_valid_reg;
always @(posedge clk) begin
    if (reset) begin
        EXEsignal_valid_reg <= 1'b0;
        EXE_signal_reg      <= 151'b0;
    end
    else if (ID_readygo && EXE_allowin) begin// 本任务中EXE\MEM\WB的readygo和allowin信号均恒为1，只有IF\ID阶段握手信号受影响
        EXEsignal_valid_reg <= EXE_signal_valid;
        EXE_signal_reg      <= EXE_signal;
    end
    else if (!ID_readygo & EXE_allowin) begin// LOAD_DH引起阻塞
        EXEsignal_valid_reg <= 1'b0;
    end
end
wire        MEM_allowin;
wire        MEM_signal_valid;
wire [70:0] MEM_signal;
wire        ld_EXE;
wire        EXE_readygo;

exe_stage exe_stage(
    .clk(clk),
    .reset(reset),
    .valid(EXEsignal_valid_reg),
    .signal(EXE_signal_reg),
    .MEM_allowin(MEM_allowin),

    .data_sram_en(data_sram_en),
    .data_sram_we(data_sram_we),
    .data_sram_addr(data_sram_addr),
    .data_sram_wdata(data_sram_wdata),
    .MEM_signal_valid(MEM_signal_valid),
    .MEM_signal(MEM_signal),
    .ld_EXE(ld_EXE),
    .EXE_readygo(EXE_readygo),
    .EXE_allowin(EXE_allowin)
);



reg [70:0] MEM_signal_reg;
reg        MEMsignal_valid_reg;
always @(posedge clk) begin
    if (reset) begin
        MEMsignal_valid_reg <= 1'b0;
        MEM_signal_reg      <= 71'b0;
    end
    else if (EXE_readygo && MEM_allowin) begin
        MEMsignal_valid_reg <= MEM_signal_valid;
        MEM_signal_reg      <= MEM_signal;
    end
end
wire        WB_allowin;
wire        WB_signal_valid;
wire [69:0] WB_signal;
wire        ld_MEM;
wire        MEM_readygo;

mem_stage mem_stage(
    .clk(clk),
    .reset(reset),
    .valid(MEMsignal_valid_reg),
    .signal(MEM_signal_reg),
    .WB_allowin(WB_allowin),
    .data_sram_rdata(data_sram_rdata),

    .WB_signal_valid(WB_signal_valid),
    .WB_signal(WB_signal),
    .ld_MEM(ld_MEM),
    .MEM_readygo(MEM_readygo),
    .MEM_allowin(MEM_allowin)
);



reg [69:0] WB_signal_reg;
reg        WBsignal_valid_reg;
always @(posedge clk) begin
    if (reset) begin
        WBsignal_valid_reg <= 1'b0;
        WB_signal_reg      <= 70'b0;
    end
    else if (MEM_readygo && WB_allowin) begin
        WBsignal_valid_reg <= WB_signal_valid;
        WB_signal_reg      <= WB_signal;
    end
end
wire WB_readygo;

wb_stage wb_stage(
    .clk(clk),
    .reset(reset),
    .valid(WBsignal_valid_reg),
    .signal(WB_signal_reg),

    .debug_wb_pc(debug_wb_pc),
    .debug_wb_rf_we(debug_wb_rf_we),
    .debug_wb_rf_wnum(debug_wb_rf_wnum),
    .debug_wb_rf_wdata(debug_wb_rf_wdata),
    .rf_waddr(rf_waddr),
    .rf_wdata(rf_wdata),
    .rf_we(rf_we),
    .WB_readygo(WB_readygo),
    .WB_allowin(WB_allowin)
);

regfile u_regfile(
    .clk    (clk      ),
    .raddr1 (rf_raddr1),
    .rdata1 (rf_rdata1),
    .raddr2 (rf_raddr2),
    .rdata2 (rf_rdata2),
    .we     (rf_we    ),
    .waddr  (rf_waddr ),
    .wdata  (rf_wdata )
    );



wire [ 2:0] rf_we_signals = {MEM_signal[37], WB_signal[37], rf_we};// {rf_we_EXE, rf_we_MEM, rf_we_WB}
wire [ 2:0] valid_signals = {EXEsignal_valid_reg, MEMsignal_valid_reg, WBsignal_valid_reg};
wire [14:0] rf_waddr_signals = {MEM_signal[36:32], WB_signal[36:32], rf_waddr};// {rf_waddr_EXE, rf_waddr_MEM, rf_waddr_WB}
wire [95:0] rf_wdata_signals = {MEM_signal[31:0], WB_signal[31:0], rf_wdata};// {rf_wdata_EXE, rf_wdata_MEM, rf_wdata_WB}
wire [ 1:0] ld_signals = {ld_EXE, ld_MEM};// {ld_EXE, ld_MEM}

DataHazard DataHazard(
    //.clk(clk),
    //.reset(reset),
    .rf_raddr1(rf_raddr1),
    .rf_raddr2(rf_raddr2),
    .rf_rdata1(rf_rdata1),
    .rf_rdata2(rf_rdata2),
    .rf_we_signals(rf_we_signals),
    .valid_signals(valid_signals),
    .rf_waddr_signals(rf_waddr_signals),
    .rf_wdata_signals(rf_wdata_signals),
    .ld_signals(ld_signals),

    .rf_rdata1_bypassing(rf_rdata1_bypassing),
    .rf_rdata2_bypassing(rf_rdata2_bypassing),
    .Load_DataHazard(Load_DataHazard)
);

endmodule
