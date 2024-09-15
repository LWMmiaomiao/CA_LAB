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
    output wire        data_sram_en,//接收内存数据
    // trace debug interface
    output wire [31:0] debug_wb_pc,
    output wire [ 3:0] debug_wb_rf_we,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata
);
reg         reset;
always @(posedge clk) reset <= ~resetn;

reg         valid;
always @(posedge clk) begin
    if (reset)
        valid <= 1'b0;
    else
        valid <= 1'b1;
end


wire [32:0] br_signal;
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
    else if (IF_readygo && ID_allowin) begin
        IDsignal_valid_reg <= IDsignal_valid;
        ID_signal_reg      <= ID_signal;
    end
    // else if (!IF_readygo & ID_allowin) begin
    //     IDsignal_valid_reg <= 1'b0;
    // end
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
wire        blocking;
wire        EXE_signal_valid;
wire [150:0]EXE_signal;
assign blocking = 1'b0;

//ID阶段得到的inst是上拍末IF中nextpc对应的指令
id_stage id_stage(
    .clk(clk),
    .reset(reset),
    .blocking(blocking),
    .valid(IDsignal_valid_reg),
    .signal(ID_signal_reg),
    .rf_rdata1(rf_rdata1),
    .rf_rdata2(rf_rdata2),
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
    else if (ID_readygo && EXE_allowin) begin
        EXEsignal_valid_reg <= EXE_signal_valid;
        EXE_signal_reg      <= EXE_signal;
    end
    // else if (!ID_readygo & EXE_allowin) begin
    //     EXEsignal_valid_reg <= 1'b0;
    // end
end
wire        MEM_allowin;
wire        MEM_signal_valid;
wire [70:0] MEM_signal;
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
    // else if (!EXE_readygo && MEM_allowin) begin
    //     MEMsignal_valid_reg <= 1'b0;
    // end
end
wire        WB_allowin;
wire        WB_signal_valid;
wire [69:0] WB_signal;
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
    // else if (!EXE_readygo && MEM_allowin) begin
    //     MEMsignal_valid_reg <= 1'b0;
    // end
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



endmodule
