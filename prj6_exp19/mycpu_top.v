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

//csr module all signals

wire [`WB_TO_IF_CSR_DATA_WIDTH-1:0] WB_to_IF_csr_data;
wire MEM_to_EXE_excep;
wire WB_flush;


wire [13:0] wb_csr_num;
wire        wb_valid_csr_we;
wire [31:0] wb_csr_wmask;
wire [31:0] wb_csr_wvalue;
wire        wb_ertn_flush_valid; //对照一下
wire        wb_excep_valid;
wire [5:0]  wb_csr_ecode;
wire [8:0]  wb_csr_esubcode;
wire [31:0] wb_vaddr;
wire [31:0] pc_WB;

wire [31:0] csr_rvalue;
wire [31:0] ex_entry;
wire has_int;       

//exp18 tlb signals in pipeline
wire  [`ID_TO_EX_TLB_WIDTH-1:0] id_to_ex_tlb;
reg   [`ID_TO_EX_TLB_WIDTH-1:0] id_to_ex_tlb_reg;
wire [`EX_TO_MEM_TLB_WIDTH-1:0] ex_to_mem_tlb;
reg  [`EX_TO_MEM_TLB_WIDTH-1:0] ex_to_mem_tlb_reg;
wire [`MEM_TO_WB_TLB_WIDTH-1:0] mem_to_wb_tlb;
reg  [`MEM_TO_WB_TLB_WIDTH-1:0] mem_to_wb_tlb_reg;

//exp18 tlb ports
wire [18:0] s0_vppn;
wire        s0_va_bit12;
wire [9:0]  s0_asid;
wire        s0_found;
wire [3:0]  s0_index;
wire [19:0] s0_ppn;
wire [5:0]  s0_ps;
wire [1:0]  s0_plv;
wire [1:0]  s0_mat;
wire        s0_d;
wire        s0_v;

wire [18:0] s1_vppn;
wire        s1_va_bit12;
wire [9:0]  s1_asid;
wire        s1_found;
wire [3:0]  s1_index;
wire [19:0] s1_ppn;
wire [5:0]  s1_ps;
wire [1:0]  s1_plv;
wire [1:0]  s1_mat;
wire        s1_d;
wire        s1_v;

wire [4:0]  invtlb_op;
wire        invtlb_valid;

wire        tlb_we;
wire [3:0]  w_index;
wire        w_e;
wire [18:0] w_vppn;
wire [5:0]  w_ps;
wire [9:0]  w_asid;
wire        w_g;

wire [19:0] w_ppn0;
wire [1:0]  w_plv0;
wire [1:0]  w_mat0;
wire        w_d0;
wire        w_v0;

wire [19:0] w_ppn1;
wire [1:0]  w_plv1;
wire [1:0]  w_mat1;
wire        w_d1;
wire        w_v1;

wire [3:0]  r_index;
wire        r_e;
wire [18:0] r_vppn;
wire [5:0]  r_ps;
wire [9:0]  r_asid;
wire        r_g;

wire [19:0] r_ppn0;
wire [1:0]  r_plv0;
wire [1:0]  r_mat0;
wire        r_d0;
wire        r_v0;

wire [19:0] r_ppn1;
wire [1:0]  r_plv1;
wire [1:0]  r_mat1;
wire        r_d1;
wire        r_v1;

//exp18 EXE added signals
wire [9:0]  csr_asid_asid;
wire [18:0] csr_tlbehi_vppn;
wire [3:0]  csr_tlbidx_index;

wire        mem_csr_tlbrd;
wire        wb_csr_tlbrd;

wire        tlbrd_we;
wire        tlbsrch_we;
wire        tlbsrch_hit;
wire  [3:0] tlbsrch_hit_index;

wire [`WB_TO_IF_REFETCH_WIDTH-1:0] wb_to_if_refetch_data;
wire  [3:0] ex_to_wb_rand;

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
wire [`ID_SIGNAL_WIDTH - 1:0] ID_signal;

wire [31:0] inst_va;    
wire [31:0] inst_pa;
wire        inst_page_invalid;
wire        inst_page_per_denied;
wire        inst_page_fault;

wire [31:0] csr_crmd_rvalue;
wire [31:0] csr_asid_rvalue;
wire [31:0] csr_dmw0_rvalue;
wire [31:0] csr_dmw1_rvalue;

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
    .axi_arid(arid),

    .wb_to_if_refetch_data(wb_to_if_refetch_data),
    .csr_asid_rvalue(csr_asid_rvalue),
    .inst_va(inst_va),
    .inst_pa(inst_pa),
    .inst_page_invalid(inst_page_invalid),
    .inst_page_per_denied(inst_page_per_denied),
    .inst_page_fault(inst_page_fault)
);


reg [`ID_SIGNAL_WIDTH - 1:0] ID_signal_reg;
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
        ID_signal_reg      <= `ID_SIGNAL_WIDTH'b0;
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
    .br_stall(br_stall),
    .id_to_ex_tlb(id_to_ex_tlb)
);

reg [169:0]EXE_signal_reg;
reg        EXEsignal_valid_reg;
always @(posedge aclk) begin
    if (reset) begin
        EXEsignal_valid_reg <= 1'b0;
        EXE_signal_reg      <= 166'b0;
        id_to_ex_tlb_reg  <= 10'd0;
    end
    else if (ID_readygo && EXE_allowin) begin
        EXEsignal_valid_reg <= EXE_signal_valid;
        EXE_signal_reg      <= EXE_signal;
        EXE_excep_signal_reg <= ID_to_EXE_excep_signal;
        id_to_ex_tlb_reg <= id_to_ex_tlb;
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

wire [31:0] data_va;
wire [31:0] data_pa;
wire        data_page_invalid;
wire        data_page_per_denied;
wire        data_page_fault;
wire        data_page_not_dirty;

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
    .MEM_to_EXE_excep(MEM_to_EXE_excep),

    //exp18
    .id_to_ex_tlb(id_to_ex_tlb_reg),
    .ex_to_mem_tlb(ex_to_mem_tlb),

    //exp18 to tlb
    .s1_va_highbits   ({s1_vppn, s1_va_bit12}),
    .s1_asid          (s1_asid),
    .invtlb_valid     (invtlb_valid),
    .invtlb_op        (invtlb_op),
    //exp18 from csr and used for tlbsrch
    .csr_asid_asid    (csr_asid_asid),
    .csr_tlbehi_vppn  (csr_tlbehi_vppn),
    //exp18 from tlb
    .s1_found         (s1_found),
    .s1_index         (s1_index),
    //exp18 to block the tlbsrch
    .mem_csr_tlbrd    (mem_csr_tlbrd),
    .wb_csr_tlbrd     (wb_csr_tlbrd),

    .ex_to_wb_rand    (ex_to_wb_rand),

    // exp19
    .data_va(data_va),
    .data_pa(data_pa),
    .data_page_invalid(data_page_invalid),
    .data_page_per_denied(data_page_per_denied),
    .data_page_fault(data_page_fault),
    .data_page_not_dirty(data_page_not_dirty)

);

reg [76:0] MEM_signal_reg;
reg        MEMsignal_valid_reg;
always @(posedge aclk) begin
    if (reset) begin
        MEMsignal_valid_reg <= 1'b0;
        MEM_signal_reg      <= 77'b0;
        ex_to_mem_tlb_reg  <= 10'd0;
    end
    else if (EXE_readygo && MEM_allowin) begin
        MEMsignal_valid_reg <= MEM_signal_valid;
        MEM_signal_reg      <= MEM_signal;
        MEM_excep_signal_reg <= EXE_to_MEM_excep_signal;
        ex_to_mem_tlb_reg <= ex_to_mem_tlb;
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
    .MEM_to_EXE_excep(MEM_to_EXE_excep),

    //exp18
    .ex_to_mem_tlb(ex_to_mem_tlb_reg),
    .mem_to_wb_tlb(mem_to_wb_tlb),
    .mem_csr_tlbrd(mem_csr_tlbrd)
    
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
        mem_to_wb_tlb_reg  <= 10'd0;
    end
    else if (WB_signal_valid && WB_allowin) begin
        WB_signal_reg      <= WB_signal;
        mem_to_wb_tlb_reg  <= mem_to_wb_tlb;
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

    //original csr
    .wb_csr_num(wb_csr_num),
    .wb_valid_csr_we(wb_valid_csr_we),
    .wb_csr_wmask(wb_csr_wmask),
    .wb_csr_wvalue(wb_csr_wvalue),
    .wb_ertn_flush_valid(wb_ertn_flush_valid),
    .wb_excep_valid(wb_excep_valid),
    .wb_csr_ecode(wb_csr_ecode),
    .wb_csr_esubcode(wb_csr_esubcode),
    .wb_vaddr(wb_vaddr),
    .pc_WB(pc_WB),

    .csr_rvalue(csr_rvalue),
    .ex_entry(ex_entry),
    .has_int(has_int),

    //exp18 added csr,tlb signals
    .mem_to_wb_tlb(mem_to_wb_tlb_reg),

    .wb_csr_tlbrd(wb_csr_tlbrd),
    .csr_tlbidx_index(csr_tlbidx_index),
    //tlbrd
    .tlbrd_we(tlbrd_we), // to write csr
    .r_index(r_index),
    //tlbwr and tlbfill, to tlb
    .w_index(w_index),
    .tlb_we(tlb_we), // to write tlb
    //tlbsrch, to csr
    .tlbsrch_we(tlbsrch_we),
    .tlbsrch_hit(tlbsrch_hit),
    .tlbsrch_hit_index(tlbsrch_hit_index),
    .wb_to_if_refetch_data(wb_to_if_refetch_data),
    .ex_to_wb_rand(ex_to_wb_rand)

);


//csr的例化在exp18修改到WB级之外
csr my_csr(
    .clk(aclk),
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

    .has_int(has_int),

    //exp18
    .csr_asid_asid   (csr_asid_asid),
    .csr_tlbehi_vppn (csr_tlbehi_vppn),
    .csr_tlbidx_index(csr_tlbidx_index),

    .tlbsrch_we        (tlbsrch_we),
    .tlbsrch_hit       (tlbsrch_hit),
    .tlbsrch_hit_index (tlbsrch_hit_index),
    .tlbrd_we          (tlbrd_we),

    .r_tlb_e         (r_e),
    .r_tlb_ps        (r_ps),
    .r_tlb_vppn      (r_vppn),
    .r_tlb_asid      (r_asid),
    .r_tlb_g         (r_g),
    .r_tlb_ppn0      (r_ppn0),
    .r_tlb_plv0      (r_plv0),
    .r_tlb_mat0      (r_mat0),
    .r_tlb_d0        (r_d0),
    .r_tlb_v0        (r_v0),
    .r_tlb_ppn1      (r_ppn1),
    .r_tlb_plv1      (r_plv1),
    .r_tlb_mat1      (r_mat1),
    .r_tlb_d1        (r_d1),
    .r_tlb_v1        (r_v1),

    .w_tlb_e         (w_e),
    .w_tlb_ps        (w_ps),
    .w_tlb_vppn      (w_vppn),
    .w_tlb_asid      (w_asid),
    .w_tlb_g         (w_g),
    .w_tlb_ppn0      (w_ppn0),
    .w_tlb_plv0      (w_plv0),
    .w_tlb_mat0      (w_mat0),
    .w_tlb_d0        (w_d0),
    .w_tlb_v0        (w_v0),
    .w_tlb_ppn1      (w_ppn1),
    .w_tlb_plv1      (w_plv1),
    .w_tlb_mat1      (w_mat1),
    .w_tlb_d1        (w_d1),
    .w_tlb_v1        (w_v1),

    .csr_crmd_rvalue(csr_crmd_rvalue),
    .csr_asid_rvalue(csr_asid_rvalue),
    .csr_dmw0_rvalue(csr_dmw0_rvalue),
    .csr_dmw1_rvalue(csr_dmw1_rvalue)

);


// tlb

tlb my_tlb(
        .clk        (aclk),
        
        .s0_vppn    (s0_vppn),
        .s0_va_bit12(s0_va_bit12),
        .s0_asid    (s0_asid),
        .s0_found   (s0_found),
        .s0_index   (s0_index),
        .s0_ppn     (s0_ppn),
        .s0_ps      (s0_ps),
        .s0_plv     (s0_plv),
        .s0_mat     (s0_mat),
        .s0_d       (s0_d),
        .s0_v       (s0_v),

        .s1_vppn    (s1_vppn),
        .s1_va_bit12(s1_va_bit12),
        .s1_asid    (s1_asid),
        .s1_found   (s1_found),
        .s1_index   (s1_index),
        .s1_ppn     (s1_ppn),
        .s1_ps      (s1_ps),
        .s1_plv     (s1_plv),
        .s1_mat     (s1_mat),
        .s1_d       (s1_d),
        .s1_v       (s1_v),

        .invtlb_op  (invtlb_op),
        .invtlb_valid(invtlb_valid),
        
        .we         (tlb_we),
        .w_index    (w_index),
        .w_e        (w_e),
        .w_vppn     (w_vppn),
        .w_ps       (w_ps),
        .w_asid     (w_asid),
        .w_g        (w_g),
        .w_ppn0     (w_ppn0),
        .w_plv0     (w_plv0),
        .w_mat0     (w_mat0),
        .w_d0       (w_d0),
        .w_v0       (w_v0),
        .w_ppn1     (w_ppn1),
        .w_plv1     (w_plv1),
        .w_mat1     (w_mat1),
        .w_d1       (w_d1),
        .w_v1       (w_v1),

        .r_index    (r_index),
        .r_e        (r_e),
        .r_vppn     (r_vppn),
        .r_ps       (r_ps),
        .r_asid     (r_asid),
        .r_g        (r_g),

        .r_ppn0     (r_ppn0),
        .r_plv0     (r_plv0),
        .r_mat0     (r_mat0),
        .r_d0       (r_d0),
        .r_v0       (r_v0),

        .r_ppn1     (r_ppn1),
        .r_plv1     (r_plv1),
        .r_mat1     (r_mat1),
        .r_d1       (r_d1),
        .r_v1       (r_v1)
    );





regfile u_regfile(
    .clk    (aclk     ),
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

MMU inst_mmu(
    .s_vppn     (s0_vppn),
    .s_va_bit12 (s0_va_bit12),
    .s_asid     (s0_asid),
    .s_found    (s0_found),
    .s_ppn      (s0_ppn),
    .s_ps       (s0_ps),
    .s_plv      (s0_plv),
    .s_mat      (s0_mat),
    .s_d        (s0_d),
    .s_v        (s0_v),

    .va         (inst_va),
    .pa         (inst_pa),
    .req_asid   (csr_asid_asid),

    .csr_crmd_rvalue(csr_crmd_rvalue),
    .csr_dmw0_rvalue(csr_dmw0_rvalue),
    .csr_dmw1_rvalue(csr_dmw1_rvalue),

    .page_invalid   (inst_page_invalid),
    .page_per_denied(inst_page_per_denied),
    .page_fault     (inst_page_fault)
);

MMU data_mmu(
    .s_vppn     (s1_vppn),
    .s_va_bit12 (s1_va_bit12),
    // .s_asid     (s1_asid),
    .s_found    (s1_found),
    .s_ppn      (s1_ppn),
    .s_ps       (s1_ps),
    .s_plv      (s1_plv),
    .s_mat      (s1_mat),
    .s_d        (s1_d),
    .s_v        (s1_v),

    .va         (data_va),
    .pa         (data_pa),
    // .req_asid   (s1_asid),

    .csr_crmd_rvalue(csr_crmd_rvalue),
    .csr_dmw0_rvalue(csr_dmw0_rvalue),
    .csr_dmw1_rvalue(csr_dmw1_rvalue),

    .page_invalid   (data_page_invalid),
    .page_per_denied(data_page_per_denied),
    .page_fault     (data_page_fault),
    .page_not_dirty (data_page_not_dirty)
);


endmodule
