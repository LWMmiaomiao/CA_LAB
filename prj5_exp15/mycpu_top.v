`include "mycpu_head.vh"
module mycpu_top(
    input  wire        aclk,
    input  wire        aresetn,

    // read request interface
    output wire [ 3:0] arid   ,
    output wire [31:0] araddr ,
    output wire [ 7:0] arlen  ,
    output wire [ 2:0] arsize ,
    output wire [ 1:0] arburst,
    output wire [ 1:0] arlock ,
    output wire [ 3:0] arcache,
    output wire [ 2:0] arprot ,
    output wire        arvalid,
    input  wire        arready,

    // read response interface
    input  wire [ 3:0] rid    ,
    input  wire [31:0] rdata  ,
    input  wire [ 1:0] rresp  ,
    input  wire        rlast  ,
    input  wire        rvalid ,
    output wire        rready ,

    // write request interface
    output wire [ 3:0] awid   ,
    output wire [31:0] awaddr ,
    output wire [ 7:0] awlen  ,
    output wire [ 2:0] awsize ,
    output wire [ 1:0] awburst,
    output wire [ 1:0] awlock ,
    output wire [ 3:0] awcache,
    output wire [ 2:0] awprot ,
    output wire        awvalid,
    input  wire        awready,

    // write data interface
    output wire [ 3:0] wid    ,
    output wire [31:0] wdata  ,
    output wire [ 3:0] wstrb  ,
    output wire        wlast  ,
    output wire        wvalid ,
    input  wire        wready ,

    // write response interface
    input  wire [ 3:0] bid    ,
    input  wire [ 1:0] bresp  ,
    input  wire        bvalid ,
    output wire        bready ,

    // trace debug interface
    output wire [31:0] debug_wb_pc,
    output wire [ 3:0] debug_wb_rf_we,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata

    /*
    // inst sram interface
    output wire        inst_sram_req,// 有读写请求时置1
    output wire        inst_sram_wr,// 写请求1 读请求0
    output wire [ 1:0] inst_sram_size,//1byte-0 2byte-1 4byte-2
    output wire [ 3:0] inst_sram_wstrb,
    output wire [31:0] inst_sram_addr,
    output wire [31:0] inst_sram_wdata,
    input  wire [31:0] inst_sram_rdata,
    input  wire        inst_sram_addr_ok,// 该次请求地址传输ok
    input  wire        inst_sram_data_ok,
    // data sram interface
    output wire         data_sram_req,
    output wire         data_sram_wr,
    output wire [ 1:0]  data_sram_size,
    output wire [ 3:0]  data_sram_wstrb,
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata,
    input  wire [31:0] data_sram_rdata,
    input  wire         data_sram_addr_ok,
    input  wire         data_sram_data_ok,
    // trace debug interface
    output wire [31:0] debug_wb_pc,
    output wire [ 3:0] debug_wb_rf_we,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata
    */

);
reg         reset;
always @(posedge aclk) reset <= ~aresetn;





wire [31:0] rf_rdata1_bypassing;
wire [31:0] rf_rdata2_bypassing;
wire        Load_DataHazard, CSR_DataHazard;

wire [`ID_TO_EXE_EXCEP_WIDTH - 1:0] ID_to_EXE_excep_signal;
wire [`EXE_TO_MEM_EXCEP_WIDTH - 1:0] EXE_to_MEM_excep_signal;
wire [`MEM_TO_WB_EXCEP_WIDTH - 1:0] MEM_to_WB_excep_signal;

reg  [`ID_TO_EXE_EXCEP_WIDTH - 1:0] EXE_excep_signal_reg;
reg  [`EXE_TO_MEM_EXCEP_WIDTH - 1:0] MEM_excep_signal_reg;
reg  [`MEM_TO_WB_EXCEP_WIDTH - 1:0] WB_excep_signal_reg;

wire [`WB_TO_IF_CSR_DATA_WIDTH-1:0] WB_to_IF_csr_data;
wire MEM_to_EXE_excep;
wire has_int;
wire WB_flush;


//AXI to SRAM bridge
wire        inst_sram_req;
wire        inst_sram_wr;
wire [ 1:0] inst_sram_size;
wire [ 3:0] inst_sram_wstrb;
wire [31:0] inst_sram_addr;
wire [31:0] inst_sram_wdata;
wire        inst_sram_addr_ok;
wire        inst_sram_data_ok;
wire [31:0] inst_sram_rdata;

wire        data_sram_req;
wire        data_sram_wr;
wire [ 1:0] data_sram_size;
wire [ 3:0] data_sram_wstrb;
wire [31:0] data_sram_addr;
wire [31:0] data_sram_wdata;
wire        data_sram_addr_ok;
wire        data_sram_data_ok;
wire [31:0] data_sram_rdata;

AXI_bridge my_AXI_bridge(
    .aclk(aclk),
    .areset(reset),
    .arid(arid),
    .araddr(araddr),
    .arlen(arlen),
    .arsize(arsize),
    .arburst(arburst),
    .arlock(arlock),
    .arcache(arcache),
    .arprot(arprot),
    .arvalid(arvalid),
    .arready(arready),

    .rid(rid),
    .rdata(rdata),
    .rresp(rresp),
    .rlast(rlast),
    .rvalid(rvalid),
    .rready(rready),

    .awid(awid),
    .awaddr(awaddr),
    .awlen(awlen),
    .awsize(awsize),
    .awburst(awburst),
    .awlock(awlock),
    .awcache(awcache),
    .awprot(awprot),
    .awvalid(awvalid),
    .awready(awready),

    .wid(wid),
    .wdata(wdata),
    .wstrb(wstrb),
    .wlast(wlast),
    .wvalid(wvalid),
    .wready(wready),

    .bid(bid),
    .bresp(bresp),
    .bvalid(bvalid),
    .bready(bready),

    .inst_sram_req(inst_sram_req),
    .inst_sram_wr(inst_sram_wr),
    .inst_sram_size(inst_sram_size),
    .inst_sram_wstrb(inst_sram_wstrb),
    .inst_sram_addr(inst_sram_addr),
    .inst_sram_wdata(inst_sram_wdata),
    .inst_sram_addr_ok(inst_sram_addr_ok),
    .inst_sram_data_ok(inst_sram_data_ok),
    .inst_sram_rdata(inst_sram_rdata),
    
    .data_sram_req(data_sram_req),
    .data_sram_wr(data_sram_wr),
    .data_sram_size(data_sram_size),
    .data_sram_wstrb(data_sram_wstrb),
    .data_sram_addr(data_sram_addr),
    .data_sram_wdata(data_sram_wdata),
    .data_sram_addr_ok(data_sram_addr_ok),
    .data_sram_data_ok(data_sram_data_ok),
    .data_sram_rdata(data_sram_rdata)
);


reg         valid;
wire        IF_allowin;
wire        br_taken_cancel;
wire [32:0] br_signal;
assign      br_taken_cancel = br_signal[32];
always @(posedge aclk) begin
    if (reset)
        valid <= 1'b0;
    else if(IF_allowin) begin
        valid <= 1'b1;
    end
    else if(br_taken_cancel) begin
        valid <= 1'b0;// 位于取指阶段的指令可能因为等待指令取回而停留
    end
end


wire        br_stall;
wire        ID_allowin;
wire [31:0] pc_ID;
wire        IF_readygo;
wire        IDsignal_valid;
wire [64:0] ID_signal;


if_stage if_stage(
    .clk(aclk),
    .reset(reset),
    //.valid(valid), //IF阶段的valid信号转为内置
    .inst_sram_rdata(inst_sram_rdata),
    
    .br_signal(br_signal),
    .ID_allowin(ID_allowin),

    .inst_sram_req(inst_sram_req),
    .inst_sram_wr(inst_sram_wr),
    .inst_sram_size(inst_sram_size),
    .inst_sram_wstrb(inst_sram_wstrb),
    .inst_sram_addr(inst_sram_addr),
    .inst_sram_wdata(inst_sram_wdata),
    .inst_sram_addr_ok(inst_sram_addr_ok),
    .inst_sram_data_ok(inst_sram_data_ok),

    .IF_readygo(IF_readygo),
    .IF_allowin(IF_allowin),
    .IDsignal_valid(IDsignal_valid),
    .ID_signal(ID_signal),

    .WB_to_IF_csr_data(WB_to_IF_csr_data),
    .IF_flush(WB_flush),
    .br_stall(br_stall),
    .axi_arid(arid)
);

reg [64:0] ID_signal_reg;
reg        IDsignal_valid_reg;



always @(posedge aclk) begin
    if (reset) begin
        IDsignal_valid_reg <= 1'b0;
    end
    else if(br_taken_cancel) begin
        IDsignal_valid_reg <= 1'b0;
    end
    else if (ID_allowin) begin
        IDsignal_valid_reg <= IDsignal_valid;
    end
end
always @(posedge aclk) begin
    if (reset) begin
        ID_signal_reg      <= 65'b0;
    end
    else if (IDsignal_valid && ID_allowin) begin
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
wire [169:0]EXE_signal;

//ID阶段得到的inst是上拍末IF中nextpc对应的指令
id_stage id_stage(
    .clk(aclk),
    .reset(reset),
    .Load_DataHazard(Load_DataHazard),
    .CSR_DataHazard(CSR_DataHazard),
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
    .EXE_signal(EXE_signal),

    .ID_to_EXE_excep_signal(ID_to_EXE_excep_signal),
    .ID_flush(WB_flush),
    .has_int(has_int),
    .br_stall(br_stall)
);

reg [169:0]EXE_signal_reg;
reg        EXEsignal_valid_reg;
always @(posedge aclk) begin
    if (reset) begin
        EXEsignal_valid_reg <= 1'b0;
        EXE_signal_reg      <= 166'b0;
    end
    else if (ID_readygo && EXE_allowin) begin
        EXEsignal_valid_reg <= EXE_signal_valid;
        EXE_signal_reg      <= EXE_signal;
        EXE_excep_signal_reg <= ID_to_EXE_excep_signal;
    end
    else if (!ID_readygo & EXE_allowin) begin// LOAD_DH引起阻塞
        EXEsignal_valid_reg <= 1'b0;
    end
end
wire        MEM_allowin;
wire        MEM_signal_valid;
wire [76:0] MEM_signal;
wire        ld_EXE;
wire        EXE_readygo;


exe_stage exe_stage(
    .clk(aclk),
    .reset(reset),
    .valid(EXEsignal_valid_reg),
    .signal(EXE_signal_reg),
    .MEM_allowin(MEM_allowin),

    //.data_sram_en(data_sram_en),
    //.data_sram_we(data_sram_we),
    .data_sram_req(data_sram_req),
    .data_sram_wr(data_sram_wr),
    .data_sram_size(data_sram_size),
    .data_sram_wstrb(data_sram_wstrb),
    .data_sram_wdata(data_sram_wdata),
    .data_sram_addr(data_sram_addr),
    .data_sram_addr_ok(data_sram_addr_ok),
    .MEM_signal_valid(MEM_signal_valid),
    .MEM_signal(MEM_signal),
    .ld_EXE(ld_EXE),
    .EXE_readygo(EXE_readygo),
    .EXE_allowin(EXE_allowin),

    //exp12
    .ID_to_EXE_excep_signal(EXE_excep_signal_reg),
    .EXE_to_MEM_excep_signal(EXE_to_MEM_excep_signal),
    .EXE_flush(WB_flush),
    .MEM_to_EXE_excep(MEM_to_EXE_excep)

);

reg [76:0] MEM_signal_reg;
reg        MEMsignal_valid_reg;
always @(posedge aclk) begin
    if (reset) begin
        MEMsignal_valid_reg <= 1'b0;
        MEM_signal_reg      <= 77'b0;
    end
    else if (EXE_readygo && MEM_allowin) begin
        MEMsignal_valid_reg <= MEM_signal_valid;
        MEM_signal_reg      <= MEM_signal;
        MEM_excep_signal_reg <= EXE_to_MEM_excep_signal;
    end
    else if (!EXE_readygo && MEM_allowin)begin
        MEMsignal_valid_reg <= 1'b0;// mul/div引起阻塞
    end
end
wire        WB_allowin;
wire        WB_signal_valid;
wire [69:0] WB_signal;
wire        ld_MEM;
wire        MEM_readygo;

mem_stage mem_stage(
    .clk(aclk),
    .reset(reset),
    .valid(MEMsignal_valid_reg),
    .signal(MEM_signal_reg),
    .WB_allowin(WB_allowin),
    .data_sram_rdata(data_sram_rdata),
    .data_sram_data_ok(data_sram_data_ok),

    .WB_signal_valid(WB_signal_valid),
    .WB_signal(WB_signal),
    .ld_MEM(ld_MEM),
    .MEM_readygo(MEM_readygo),
    .MEM_allowin(MEM_allowin),

    //exp12
    .EXE_to_MEM_excep_signal(MEM_excep_signal_reg),
    .MEM_to_WB_excep_signal(MEM_to_WB_excep_signal),
    .MEM_flush(WB_flush),
    .MEM_to_EXE_excep(MEM_to_EXE_excep)


);

reg [69:0] WB_signal_reg;
reg        WBsignal_valid_reg;
always @(posedge aclk) begin
    if (reset) begin
        WBsignal_valid_reg <= 1'b0;
    end
    else if (WB_allowin) begin
        WBsignal_valid_reg <= WB_signal_valid;
        WB_excep_signal_reg <= MEM_to_WB_excep_signal;
    end
end
always @(posedge aclk) begin
    if (reset) begin
        WB_signal_reg      <= 70'b0;
    end
    else if (WB_signal_valid && WB_allowin) begin
        WB_signal_reg      <= WB_signal;
    end
end
wire WB_readygo;

wb_stage wb_stage(
    .clk(aclk),
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
    .WB_allowin(WB_allowin),

    //exp12
    .MEM_to_WB_excep_signal(WB_excep_signal_reg),
    .WB_to_IF_csr_data(WB_to_IF_csr_data),
    .WB_flush(WB_flush),
    .has_int(has_int)
);




regfile u_regfile(
    .clk    (aclk      ),
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
wire [ 1:0] ld_signals = {ld_EXE, ld_MEM};

wire EXE_res_from_csr = EXE_excep_signal_reg[`ID_TO_EXE_EXCEP_WIDTH - 1] & EXEsignal_valid_reg; 
wire MEM_res_from_csr = MEM_excep_signal_reg[`EXE_TO_MEM_EXCEP_WIDTH - 1] & MEMsignal_valid_reg;

DataHazard DataHazard(
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
    .Load_DataHazard(Load_DataHazard),
    .CSR_DataHazard(CSR_DataHazard),
    .EXE_res_from_csr(EXE_res_from_csr),
    .MEM_res_from_csr(MEM_res_from_csr)
);

endmodule
