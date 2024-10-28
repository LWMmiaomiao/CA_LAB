`include "mycpu_head.vh"
module csr(
    input  wire              clk,
    input  wire              reset,
    input  wire [13:0]       csr_num,
    input  wire              csr_we,
    input  wire [31:0]       csr_wmask,
    input  wire [31:0]       csr_wvalue,
    input  wire              ertn_flush,    // 来自WB阶段的ertn指令执行有效信号
    input  wire              wb_ex,         // 来自WB的exception触发信号
    input  wire [5:0]        wb_ecode,      //csr_estate:21-16 异常类型
    input  wire [8:0]        wb_esubcode,   //csr_estate:30-22 异常类型辅助码
    input  wire [31:0]       wb_vaddr,      //来自WB阶段的访存地址
    input  wire [31:0]       wb_pc,

    output wire [31:0]       csr_rvalue,
    output wire [31:0]       ex_entry,//送往pre-IF的异常入口地址
    output wire [31:0]       ertn_entry, //送往pre-IF的返回入口地址
    output wire              has_int//送往ID阶段的中断有效标记信号
);
// CRMD 当前模式信息
reg [1:0]   csr_crmd_plv;
reg         csr_crmd_ie;
wire [31:0] csr_crmd_rvalue; //之后每一块都类似设置一个32位的wire方便读出

wire        csr_crmd_da;
wire        csr_crmd_pg;
wire [1:0]  csr_crmd_datf;
wire [1:0]  csr_crmd_datm; 

// PRMD 例外前模式信息
reg  [1:0]  csr_prmd_pplv;
reg         csr_prmd_pie; 
wire [31:0] csr_prmd_rvalue;

// ESTAT 例外状态
reg  [12:0] csr_estat_is; // 13位的中断状态位
reg  [ 5:0] csr_estat_ecode; // 例外类型1级编码
reg  [ 8:0] csr_estat_esubcode; //例外类型2级编码
wire [31:0] csr_estat_rvalue;

    // 例外控制
    wire [31: 0] csr_ecfg_data;     // 保留位31:13
    reg  [12: 0] csr_ecfg_lie;      //局部中断使能位

// ERA 例外返回地址
reg [31:0]  csr_era_pc;
wire [31:0] csr_era_rvalue;

// EENTRY 例外入口地址
reg [25:0]  csr_eentry_va; // entry address for exception
wire [31:0] csr_eentry_rvalue;

// 定时器
wire [31: 0] csr_tval_data;
reg  [31: 0] timer_cnt;
// 定时中断清除
wire         csr_ticlr_clr;
wire [31: 0] csr_ticlr_data;

// 出错虚地址
wire         wb_ex_addr_err;
reg  [31: 0] csr_badv_vaddr;
wire [31: 0] csr_badv_data;
// 定时器编号 
wire [31: 0] csr_tid_data;
reg  [31: 0] csr_tid_tid;
// 定时器配置
wire [31: 0] csr_tcfg_data;
reg          csr_tcfg_en;
reg          csr_tcfg_periodic;
reg  [29: 0] csr_tcfg_initval;
wire [31: 0] tcfg_next_value;


// SAVE0-3
reg [31:0]  csr_save0_data;
reg [31:0]  csr_save1_data;
reg [31:0]  csr_save2_data;
reg [31:0]  csr_save3_data;
wire [31:0] csr_save0_rvalue;
wire [31:0] csr_save1_rvalue;
wire [31:0] csr_save2_rvalue;
wire [31:0] csr_save3_rvalue;

assign ex_entry = csr_eentry_rvalue;
assign ertn_entry = csr_era_pc;

assign csr_crmd_da = 1'b1;
assign csr_crmd_pg = 1'b0;
assign csr_crmd_datf = 2'b00;
assign csr_crmd_datm = 2'b00;

// TVAL的TimeVal域 返回定时器计数器的值
assign tcfg_next_value = csr_wmask[31:0] & csr_wvalue[31:0]
                       |~csr_wmask[31:0] & csr_tcfg_data;
always @(posedge clk) begin
    if (reset) begin
        timer_cnt <= 32'hffffffff;
    end
    else if (csr_we && csr_num == `CSR_TCFG && tcfg_next_value[`CSR_TCFG_EN]) begin
        timer_cnt <= {tcfg_next_value[`CSR_TCFG_INITV], 2'b0};//当软件开启 timer 的使能时写入的 timer 配置寄存器的定时器初始值更新到timer_cnt
    end
    else if (csr_tcfg_en && timer_cnt != 32'hffffffff) begin //定时器是非周期性的所以如果 0-1=ff..ff,那么停止计数
        if (timer_cnt[31:0] == 32'b0 && csr_tcfg_periodic) begin
            timer_cnt <= {csr_tcfg_initval, 2'b0};
        end
        else begin
            timer_cnt <= timer_cnt - 1'b1;
        end
    end
end


   // ECFG
always @(posedge clk) begin
    if(reset)
        csr_ecfg_lie <= 13'b0;
    else if(csr_we && csr_num == `CSR_ECFG)
        csr_ecfg_lie <= csr_wmask[`CSR_ECFG_LIE] & 13'h1bff & csr_wvalue[`CSR_ECFG_LIE]
                    | ~csr_wmask[`CSR_ECFG_LIE] & 13'h1bff & csr_ecfg_lie;
end

// BADV的VAddr域
//load store在执行级、访存级和写回级增加虚地址通路，采用增加一个vaddr域
assign wb_ex_addr_err = wb_ecode==`ECODE_ALE || wb_ecode==`ECODE_ADEF; 
always @(posedge clk) begin
    if (wb_ex && wb_ex_addr_err) begin
        csr_badv_vaddr <= (wb_ecode==`ECODE_ADEF && wb_esubcode==`ESUBCODE_ADEF) ? wb_pc : wb_vaddr;
    end
end

    // TID
always @(posedge clk) begin
    if (reset) begin
        csr_tid_tid <= 32'b0;
    end
    else if (csr_we && csr_num == `CSR_TID) begin
        csr_tid_tid <= csr_wmask[`CSR_TID_TID] & csr_wvalue[`CSR_TID_TID]
                    | ~csr_wmask[`CSR_TID_TID] & csr_tid_tid;
    end
end

// TCFG的EN、Periodic、InitVal域
always @(posedge clk) begin
    if (reset) 
        csr_tcfg_en <= 1'b0;
    else if (csr_we && csr_num == `CSR_TCFG) begin
        csr_tcfg_en <= csr_wmask[`CSR_TCFG_EN] & csr_wvalue[`CSR_TCFG_EN]
                    | ~csr_wmask[`CSR_TCFG_EN] & csr_tcfg_en;
    end
    if (csr_we && csr_num == `CSR_TCFG) begin
        csr_tcfg_periodic <= csr_wmask[`CSR_TCFG_PERIOD] & csr_wvalue[`CSR_TCFG_PERIOD]
                            | ~csr_wmask[`CSR_TCFG_PERIOD] & csr_tcfg_periodic;
        csr_tcfg_initval  <= csr_wmask[`CSR_TCFG_INITV] & csr_wvalue[`CSR_TCFG_INITV]
                            | ~csr_wmask[`CSR_TCFG_INITV] & csr_tcfg_initval;
    end
end

// TICLR的CLR域
assign csr_ticlr_clr = 1'b0;

// CRMD
always @(posedge clk) begin
    if(reset) begin
        csr_crmd_plv <= 2'b0;
        csr_crmd_ie  <= 1'b0;
    end
    else if(wb_ex) begin
        csr_crmd_plv <= 2'b0;
        csr_crmd_ie  <= 1'b0;
    end
    else if(ertn_flush) begin
        csr_crmd_plv <= csr_prmd_pplv;
        csr_crmd_ie  <= csr_prmd_pie;
    end
    else if(csr_we && csr_num == `CSR_CRMD) begin
        csr_crmd_plv <= csr_wmask[`CSR_CRMD_PLV] & csr_wvalue[`CSR_CRMD_PLV] | ~csr_wmask[`CSR_CRMD_PLV] & csr_crmd_plv;
        csr_crmd_ie <= csr_wmask[`CSR_CRMD_PIE] & csr_wvalue[`CSR_CRMD_PIE] | ~csr_wmask[`CSR_CRMD_PIE] & csr_crmd_ie; 
    end
end

//PRMD
always @(posedge clk) begin
    if (wb_ex) begin
        csr_prmd_pplv <= csr_crmd_plv;
        csr_prmd_pie <= csr_crmd_ie;
    end
    else if (csr_we && csr_num==`CSR_PRMD) begin
        csr_prmd_pplv <= csr_wmask[`CSR_PRMD_PPLV] & csr_wvalue[`CSR_PRMD_PPLV] | ~csr_wmask[`CSR_PRMD_PPLV] & csr_prmd_pplv;
        csr_prmd_pie <= csr_wmask[`CSR_PRMD_PIE] & csr_wvalue[`CSR_PRMD_PIE] | ~csr_wmask[`CSR_PRMD_PIE] & csr_prmd_pie;
    end
end

// ESTAT
always @(posedge clk) begin
    if (reset) begin
        csr_estat_is[1:0] <= 2'b0;
    end
    else if (csr_we && csr_num==`CSR_ESTAT) begin
        csr_estat_is[1:0] <= csr_wmask[`CSR_ESTAT_IS10] & csr_wvalue[`CSR_ESTAT_IS10] | ~csr_wmask[`CSR_ESTAT_IS10] & csr_estat_is[1:0];
    end   


    csr_estat_is[9:2] <= 8'b0;//hw_int_in[7:0];// 硬中断引脚
    csr_estat_is[10]  <= 1'b0;// 未定义

    if (timer_cnt[31:0] == 32'b0) //(csr_tcfg_en && timer_cnt[31:0] == 32'b0)
        csr_estat_is[11] <= 1'b1;
    else if (csr_we && csr_num == `CSR_TICLR && csr_wmask[`CSR_TICLR_CLR] && csr_wvalue[`CSR_TICLR_CLR]) 
        csr_estat_is[11] <= 1'b0;              
    csr_estat_is[12] <= 1'b0;//ipi_int_in;// 核间中断

end

always @(posedge clk) begin
    if (wb_ex) begin
        csr_estat_ecode    <= wb_ecode;
        csr_estat_esubcode <= wb_esubcode;
    end
end

// ERA
always @(posedge clk) begin
    if (wb_ex)
        csr_era_pc <= wb_pc;
    else if (csr_we && csr_num==`CSR_ERA)
        csr_era_pc <= csr_wmask[`CSR_ERA_PC] & csr_wvalue[`CSR_ERA_PC] | ~csr_wmask[`CSR_ERA_PC] & csr_era_pc;
end

// EENTRY
always @(posedge clk) begin
    if (csr_we && csr_num==`CSR_EENTRY)
        csr_eentry_va <= csr_wmask[`CSR_EENTRY_VA] & csr_wvalue[`CSR_EENTRY_VA] | ~csr_wmask[`CSR_EENTRY_VA] & csr_eentry_va;
end

// SAVE0-3
always @(posedge clk) begin
    if (csr_we && csr_num==`CSR_SAVE0)
        csr_save0_data <= csr_wmask[`CSR_SAVE_DATA] & csr_wvalue[`CSR_SAVE_DATA]
                        | ~csr_wmask[`CSR_SAVE_DATA] & csr_save0_data;
    if (csr_we && csr_num==`CSR_SAVE1)
        csr_save1_data <= csr_wmask[`CSR_SAVE_DATA] & csr_wvalue[`CSR_SAVE_DATA]
                        | ~csr_wmask[`CSR_SAVE_DATA] & csr_save1_data;
    if (csr_we && csr_num==`CSR_SAVE2)
        csr_save2_data <= csr_wmask[`CSR_SAVE_DATA] & csr_wvalue[`CSR_SAVE_DATA]
                        | ~csr_wmask[`CSR_SAVE_DATA] & csr_save2_data;
    if (csr_we && csr_num==`CSR_SAVE3)
        csr_save3_data <= csr_wmask[`CSR_SAVE_DATA] & csr_wvalue[`CSR_SAVE_DATA]
                        | ~csr_wmask[`CSR_SAVE_DATA] & csr_save3_data;
end

assign csr_crmd_rvalue = {23'b0, csr_crmd_datm, csr_crmd_datf, csr_crmd_pg, csr_crmd_da, csr_crmd_ie, csr_crmd_plv};
assign csr_prmd_rvalue = {29'b0, csr_prmd_pie, csr_prmd_pplv};
assign csr_estat_rvalue =  {1'b0, csr_estat_esubcode, csr_estat_ecode, 3'b0, csr_estat_is};
assign csr_era_rvalue =  csr_era_pc;
assign csr_eentry_rvalue =  {csr_eentry_va, 6'b0};
assign csr_save0_rvalue  =  csr_save0_data;
assign csr_save1_rvalue  =  csr_save1_data;
assign csr_save2_rvalue  =  csr_save2_data;
assign csr_save3_rvalue  =  csr_save3_data;
assign csr_badv_data  = csr_badv_vaddr;
assign csr_tid_data   = csr_tid_tid;
assign csr_tcfg_data  = {csr_tcfg_initval, csr_tcfg_periodic, csr_tcfg_en};
assign csr_tval_data  = timer_cnt;
assign csr_ecfg_data  = {19'b0, csr_ecfg_lie};
assign csr_ticlr_data = {31'b0, csr_ticlr_clr};

assign csr_rvalue =   {32{csr_num == `CSR_CRMD  }} & csr_crmd_rvalue
                    | {32{csr_num == `CSR_PRMD  }} & csr_prmd_rvalue 
                    | {32{csr_num == `CSR_ESTAT }} & csr_estat_rvalue
                    | {32{csr_num == `CSR_ERA   }} & csr_era_rvalue
                    | {32{csr_num == `CSR_EENTRY}} & csr_eentry_rvalue
                    | {32{csr_num == `CSR_SAVE0 }} & csr_save0_rvalue
                    | {32{csr_num == `CSR_SAVE1 }} & csr_save1_rvalue
                    | {32{csr_num == `CSR_SAVE2 }} & csr_save2_rvalue
                    | {32{csr_num == `CSR_SAVE3 }} & csr_save3_rvalue
                    | {32{csr_num == `CSR_ECFG  }} & csr_ecfg_data
                    | {32{csr_num == `CSR_BADV  }} & csr_badv_data
                    | {32{csr_num == `CSR_TID   }} & csr_tid_data
                    | {32{csr_num == `CSR_TCFG  }} & csr_tcfg_data
                    | {32{csr_num == `CSR_TVAL  }} & csr_tval_data
                    | {32{csr_num == `CSR_TICLR }} & csr_ticlr_data;
                  
assign has_int = (|(csr_estat_is[11:0] & csr_ecfg_lie[11:0])) & csr_crmd_ie;


endmodule