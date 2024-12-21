`include "mycpu_head.vh"
module id_stage(
    input  wire        clk,
    input  wire        reset,
    input  wire        Load_DataHazard,
    input  wire        CSR_DataHazard,
    input  wire        valid,
    input  wire [`ID_SIGNAL_WIDTH - 1:0] signal,
    input  wire [31:0] rf_rdata1,
    input  wire [31:0] rf_rdata2,
    input  wire        EXE_allowin,
    input  wire [37:0] wb_rf_zip, // {wb_rf_we, wb_rf_waddr, wb_rf_wdata}
    input  wire [39:0] mem_rf_zip,
    input  wire [39:0] ex_rf_zip,
    
    output wire [ 4:0] rf_raddr1,
    output wire [ 4:0] rf_raddr2,
    output wire [32:0] br_signal,// br_taken[32:32] br_target[31:0]
    output wire        ID_readygo,
    output wire        ID_allowin,
    output wire        EXE_signal_valid,
    output wire [169:0]EXE_signal,

    output wire [`ID_TO_EXE_EXCEP_WIDTH - 1:0] ID_to_EXE_excep_signal,
    input  wire ID_flush,
    input  wire has_int,
    output wire br_stall,

    output wire [  `ID_TO_EX_TLB_WIDTH-1:0] id_to_ex_tlb

);
wire [31:0] pc_ID;
wire [31:0] inst;
wire        br_taken;
wire [31:0] br_target;
wire [ 5:0] op_31_26;
wire [ 3:0] op_25_22;
wire [ 1:0] op_21_20;
wire [ 4:0] op_19_15;
wire [ 2:0] op_12_10;
wire [ 4:0] op_09_05;
wire [ 1:0] op_14_13;


wire [ 4:0] rd;
wire [ 4:0] rj;
wire [ 4:0] rk;
wire [11:0] i12;
wire [19:0] i20;
wire [15:0] i16;
wire [25:0] i26;
wire        id_excp_adef;
wire        id_excp_pif;
wire        id_excp_ppi;
wire        id_excp_tlbr;
wire [ 1:0] rdcntv_valid;
assign {id_excp_pif, id_excp_ppi, id_excp_tlbr, id_excp_adef, inst, pc_ID} = signal;
assign rd   = inst[ 4: 0];
assign rj   = inst[ 9: 5];
assign rk   = inst[14:10];
assign i12  = inst[21:10];
assign i20  = inst[24: 5];
assign i16  = inst[25:10];
assign i26  = {inst[ 9: 0], inst[25:10]};

wire [63:0] op_31_26_d;
wire [15:0] op_25_22_d;
wire [ 3:0] op_21_20_d;
wire [31:0] op_19_15_d;
wire [7:0] op_12_10_d;
wire [31:0] op_09_05_d;
wire [3:0] op_14_13_d;

assign op_31_26  = inst[31:26];
assign op_25_22  = inst[25:22];
assign op_21_20  = inst[21:20];
assign op_19_15  = inst[19:15];
assign op_14_13  = inst[14:13];
assign op_12_10  = inst[12:10];
assign op_09_05  = inst[9:5];


decoder_6_64 u_dec0(.in(op_31_26 ), .out(op_31_26_d ));
decoder_4_16 u_dec1(.in(op_25_22 ), .out(op_25_22_d ));
decoder_2_4  u_dec2(.in(op_21_20 ), .out(op_21_20_d ));
decoder_5_32 u_dec3(.in(op_19_15 ), .out(op_19_15_d ));
decoder_2_4  u_dec4(.in(op_14_13 ), .out(op_14_13_d ));
decoder_3_8  u_dec5(.in(op_12_10 ), .out(op_12_10_d ));
decoder_5_32 u_dec6(.in(op_09_05 ), .out(op_09_05_d ));



wire        inst_add_w;
wire        inst_sub_w;
wire        inst_slt;
wire        inst_sltu;
wire        inst_nor;
wire        inst_and;
wire        inst_or;
wire        inst_xor;
wire        inst_slli_w;
wire        inst_srli_w;
wire        inst_srai_w;
wire        inst_addi_w;
wire        inst_ld;
wire        inst_ld_w;
wire        inst_ld_b;
wire        inst_ld_h;
wire        inst_ld_bu;
wire        inst_ld_hu;
wire        inst_st;
wire        inst_st_w;
wire        inst_st_b;
wire        inst_st_h;
wire        inst_jirl;
wire        inst_b;
wire        inst_bl;
wire        inst_beq;
wire        inst_bne;
wire        inst_blt;
wire        inst_bltu;
wire        inst_bge;
wire        inst_bgeu;

wire [32:0] sub_res; // 用于判断blt,bltu,bge,bgeu 

wire        inst_lu12i_w;

wire        inst_slti;
wire        inst_sltui;
wire        inst_andi;
wire        inst_ori;
wire        inst_xori;
wire        inst_sll_w;
wire        inst_srl_w;
wire        inst_sra_w;
wire        inst_pcaddu12i;

wire        inst_mul_w;
wire        inst_mulh_w;
wire        inst_mulh_wu;
wire        inst_div_w;
wire        inst_div_wu;
wire        inst_mod_w;
wire        inst_mod_wu;

//exp12
wire        inst_csrrd;
wire        inst_csrwr;
wire        inst_csrxchg;
wire        inst_ertn;
wire        inst_syscall;

//exp13
wire        inst_break;
wire        inst_rdcntid;
wire        inst_rdcntvl;
wire        inst_rdcntvh;

//exp18
wire        inst_tlbsrch;
wire        inst_tlbrd;
wire        inst_tlbwr;
wire        inst_tlbfill;
wire        inst_invtlb;

//exp18 大坑点：invtlb op=7的时候要触发例外!!!
wire        invtlb_op_fault;

wire        type_tlb;       // tlb类
wire        type_al;        // 算术逻辑类，arithmatic or logic
wire        type_ld_st;     // 访存类， load or store
wire        type_bj;        // 分支跳转类，branch or jump
wire        type_ex;        // 例外相关类，exception
wire        type_else;      // 其他

assign inst_slti   = op_31_26_d[6'h00] & op_25_22_d[4'h8];// no rk
assign inst_sltui  = op_31_26_d[6'h00] & op_25_22_d[4'h9];// no rk
assign inst_andi   = op_31_26_d[6'h00] & op_25_22_d[4'hd];// no rk
assign inst_ori    = op_31_26_d[6'h00] & op_25_22_d[4'he];// no rk
assign inst_xori   = op_31_26_d[6'h00] & op_25_22_d[4'hf];// no rk
    
//inst shift register
assign inst_sll_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0e];
assign inst_srl_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0f];
assign inst_sra_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h10];

// exp10 extra inst
assign inst_pcaddu12i = op_31_26_d[6'h07] & ~inst[25];// no rj rk

// add mul/div inst
assign inst_mul_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h18];
assign inst_mulh_w = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h19];
assign inst_mulh_wu= op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h1a];
assign inst_div_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h00];
assign inst_mod_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h01];
assign inst_div_wu = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h02];
assign inst_mod_wu = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h03];

assign inst_add_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h00];
assign inst_sub_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h02];
assign inst_slt    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h04];
assign inst_sltu   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h05];
assign inst_nor    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h08];
assign inst_and    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h09];
assign inst_or     = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0a];
assign inst_xor    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0b];
assign inst_slli_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h01];//no rk
assign inst_srli_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h09];//no rk
assign inst_srai_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h11];//no rk
assign inst_addi_w = op_31_26_d[6'h00] & op_25_22_d[4'ha];//no rk
assign inst_ld_w   = op_31_26_d[6'h0a] & op_25_22_d[4'h2];//no rk
assign inst_ld_b   = op_31_26_d[6'h0a] & op_25_22_d[4'h0];//no rk
assign inst_ld_h   = op_31_26_d[6'h0a] & op_25_22_d[4'h1];//no rk
assign inst_ld_bu  = op_31_26_d[6'h0a] & op_25_22_d[4'h8];//no rk
assign inst_ld_hu  = op_31_26_d[6'h0a] & op_25_22_d[4'h9];//no rk
assign inst_st_w   = op_31_26_d[6'h0a] & op_25_22_d[4'h6];
assign inst_st_b   = op_31_26_d[6'h0a] & op_25_22_d[4'h4];
assign inst_st_h   = op_31_26_d[6'h0a] & op_25_22_d[4'h5];
assign inst_jirl   = op_31_26_d[6'h13];//no rk
assign inst_b      = op_31_26_d[6'h14];//no rj rk
assign inst_bl     = op_31_26_d[6'h15];//no rj rk
assign inst_beq    = op_31_26_d[6'h16];
assign inst_bne    = op_31_26_d[6'h17];
assign inst_blt    = op_31_26_d[6'h18];
assign inst_bge    = op_31_26_d[6'h19];
assign inst_bltu   = op_31_26_d[6'h1a];
assign inst_bgeu   = op_31_26_d[6'h1b];
assign inst_ld     = inst_ld_w | inst_ld_b | inst_ld_h | inst_ld_bu | inst_ld_hu;
assign inst_st     = inst_st_w | inst_st_b | inst_st_h;

assign inst_lu12i_w= op_31_26_d[6'h05] & ~inst[25];//no rj rk

//exp12
assign inst_syscall = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h16];
assign inst_csrrd   = op_31_26_d[6'h01] & (op_25_22[3:2] == 2'b0) & (rj == 5'b0);
assign inst_csrwr   = op_31_26_d[6'h01] & (op_25_22[3:2] == 2'b0) & (rj == 5'b1);
assign inst_csrxchg = op_31_26_d[6'h01] & (op_25_22[3:2] == 2'b0) & (|rj[4:1]);
assign inst_ertn    = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] & (rk == 5'h0e) & (rj == 5'h00) & (rd == 5'h00);


//exp13
assign inst_break   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h14];
assign inst_rdcntid = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h0] & op_19_15_d[5'h00] & (rk == 5'h18) & (rd == 5'h00);
assign inst_rdcntvl = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h0] & op_19_15_d[5'h00] & (rk == 5'h18) & (rj == 5'h00);
assign inst_rdcntvh = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h0] & op_19_15_d[5'h00] & (rk == 5'h19) & (rj == 5'h00);

assign rdcntv_valid = {inst_rdcntvh, inst_rdcntvl};

//exp18
assign inst_tlbsrch = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] & op_14_13_d[2'h1] & op_12_10_d[3'h2]; //rk == 5'h0a;
assign inst_tlbrd   = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] & op_14_13_d[2'h1] & op_12_10_d[3'h3]; //rk == 5'h0b;
assign inst_tlbwr   = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] & op_14_13_d[2'h1] & op_12_10_d[3'h4]; //rk == 5'h0c;
assign inst_tlbfill = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] & op_14_13_d[2'h1] & op_12_10_d[3'h5]; //rk == 5'h0d;
assign inst_invtlb  = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h13];



// 指令分类
assign type_tlb    = inst_tlbsrch | inst_tlbrd | inst_tlbwr | inst_tlbfill | inst_invtlb;
assign type_al    = inst_add_w  | inst_sub_w  | inst_slti   | inst_slt   | inst_sltui  | inst_sltu  |
                    inst_nor    | inst_and    | inst_andi   | inst_or    | inst_ori    | inst_xor   |
                    inst_xori   | inst_sll_w  | inst_slli_w | inst_srl_w | inst_srli_w | inst_sra_w | inst_srai_w | inst_addi_w|
                    inst_mul_w  | inst_mulh_w | inst_mulh_wu| inst_div_w | inst_div_wu | inst_mod_w |
                    inst_mod_wu;
assign type_ld_st = inst_ld_b   | inst_ld_h   | inst_ld_w   | inst_ld_bu | inst_ld_hu  | inst_st_b  |
                    inst_st_h   | inst_st_w;
assign type_bj    = inst_jirl   | inst_b      | inst_bl     | inst_blt   | inst_bge    | inst_bltu  |
                    inst_bgeu   | inst_beq    | inst_bne;
assign type_ex    = inst_csrrd  | inst_csrwr  | inst_csrxchg| inst_ertn  | inst_syscall| inst_break;
assign type_else  = inst_rdcntvh | inst_rdcntvl | inst_rdcntid | inst_lu12i_w | inst_pcaddu12i; 


wire [18:0] alu_op;// add 7 mul/div aluop
wire [31:0] alu_src1;
wire [31:0] alu_src2;
assign alu_op[ 0] = inst_add_w | inst_addi_w | inst_ld | inst_st
                    | inst_jirl | inst_bl | inst_pcaddu12i;
assign alu_op[ 1] = inst_sub_w;
assign alu_op[ 2] = inst_slt | inst_slti;
assign alu_op[ 3] = inst_sltu | inst_sltui;
assign alu_op[ 4] = inst_and | inst_andi;
assign alu_op[ 5] = inst_nor;
assign alu_op[ 6] = inst_or | inst_ori;
assign alu_op[ 7] = inst_xor | inst_xori;
assign alu_op[ 8] = inst_slli_w | inst_sll_w;
assign alu_op[ 9] = inst_srli_w | inst_srl_w;
assign alu_op[10] = inst_srai_w | inst_sra_w;
assign alu_op[11] = inst_lu12i_w;
assign alu_op[12] = inst_mul_w ;
assign alu_op[13] = inst_mulh_w;
assign alu_op[14] = inst_mulh_wu;
assign alu_op[15] = inst_div_w;
assign alu_op[16] = inst_div_wu;
assign alu_op[17] = inst_mod_w;
assign alu_op[18] = inst_mod_wu;

wire        need_ui5;
wire        need_ui12;
wire        need_si12;
wire        need_si16;
wire        need_si20;
wire        need_si26;
wire        src2_is_4;
assign need_ui5   =  inst_slli_w | inst_srli_w | inst_srai_w;
assign need_si12  =  inst_addi_w | inst_ld | inst_st | inst_slti | inst_sltui;
assign need_ui12  =  inst_andi | inst_ori | inst_xori;
assign need_si16  =  inst_jirl | inst_beq | inst_bne | inst_blt | inst_bge | inst_bltu | inst_bgeu;
assign need_si20  =  inst_lu12i_w | inst_pcaddu12i;
assign need_si26  =  inst_b | inst_bl;
assign src2_is_4  =  inst_jirl | inst_bl;

wire        load_op;
wire        src1_is_pc;
wire        src2_is_imm;
wire        res_from_mem;
wire        dst_is_r1;
wire        dst_is_rj;
wire        gr_we;
wire        rf_we;
wire [ 3:0] mem_we;
wire        src_reg_is_rd;
wire [ 4:0] dest;
wire [ 4:0] rf_waddr;
wire [31:0] rj_value;
wire [31:0] rkd_value;
wire        rj_eq_rd;
wire        rj_lt_rd_signed;
wire        rj_lt_rd_unsigned;
wire [31:0] imm;
wire [31:0] br_offs;
wire [31:0] jirl_offs;
wire        rf_raddr1_valid;
wire        rf_raddr2_valid;

assign rf_raddr1_valid = (!inst_b && !inst_bl && !inst_lu12i_w
                      && !inst_pcaddu12i)
                      || inst_csrxchg;

assign rf_raddr2_valid = (!inst_b && !inst_bl && !inst_lu12i_w 
                      && !inst_slli_w && !inst_srli_w && !inst_srai_w && !inst_addi_w && !inst_ld && !inst_jirl
                      && !inst_pcaddu12i
                      && !inst_slti && !inst_sltui
                      && !inst_andi && !inst_ori && !inst_xori)
                      || inst_csrwr || inst_csrxchg;

assign imm = src2_is_4              ? 32'h4                      :
             need_si20              ? {i20[19:0], 12'b0}         : //i20: inst[24:5]
            (need_ui5 || need_si12) ? {{20{i12[11]}}, i12[11:0]} : //i12: inst[21:10] i5: inst[14:10]
            {20'b0, i12[11:0]};                                    // include need_ui12 

assign br_offs = need_si26 ? {{ 4{i26[25]}}, i26[25:0], 2'b0} :
                             {{14{i16[15]}}, i16[15:0], 2'b0} ;

assign jirl_offs = {{14{i16[15]}}, i16[15:0], 2'b0};

assign src_reg_is_rd = inst_beq | inst_bne | inst_blt | inst_bge | inst_bltu | inst_bgeu | inst_st 
                    | inst_csrwr | inst_csrxchg;

assign src1_is_pc    = inst_jirl | inst_bl | inst_pcaddu12i;

assign src2_is_imm   = inst_slli_w |
                       inst_srli_w |
                       inst_srai_w |
                       inst_addi_w |
                       inst_ld     |
                       inst_st     |
                       inst_lu12i_w|
                       inst_jirl   |
                       inst_bl     |
                       inst_pcaddu12i|
                       inst_andi   |
                       inst_ori    |
                       inst_xori   |
                       inst_slti   |
                       inst_sltui;

assign res_from_mem  = inst_ld && valid;
assign dst_is_r1     = inst_bl;
assign dst_is_rj     = inst_rdcntid;
//assign gr_we         = ~inst_st & ~inst_beq & ~inst_bne & ~inst_b
//                      & ~inst_blt & ~inst_bge & ~inst_bltu & ~inst_bgeu & ~inst_ertn & ~inst_syscall;
assign gr_we         =  ~inst_st_w & ~inst_st_h & ~inst_st_b & ~inst_beq  & 
                        ~inst_bne  & ~inst_b    & ~inst_bge  & ~inst_bgeu & 
                        ~inst_blt  & ~inst_bltu & ~inst_ertn & ~inst_syscall & ~type_tlb; 

assign rf_we         = gr_we && valid;
assign mem_we        = {4{inst_st && valid}};
assign dest          = dst_is_r1 ? 5'd1 : dst_is_rj ? rj : rd;
assign rf_waddr      = dest;

/*严格判定Load_DataHazard条件*/
assign rf_raddr1 = rf_raddr1_valid ? rj : 5'b0;
assign rf_raddr2 = rf_raddr2_valid ? (src_reg_is_rd ? rd : rk) : 5'b0;
//assign rf_raddr1 = rj;
//assign rf_raddr2 = src_reg_is_rd ? rd : rk;

assign rj_value  = rf_rdata1;
assign rkd_value = rf_rdata2;

assign rj_eq_rd = (rj_value == rkd_value);
assign sub_res = {1'b0, rj_value} + {1'b0, ~rkd_value} + 1'b1;
assign rj_lt_rd_signed = (rj_value[31] & ~rkd_value[31])
                    | ((rj_value[31] ~^ rkd_value[31]) & sub_res[31]); // ~^表示同或
assign rj_lt_rd_unsigned = ~sub_res[32];





    // exp21:发现conflict逻辑有问题, 难以解决, 大改
    wire        conflict;
    wire        id_delay;
    wire        mem_res_from_mem;
    wire        ex_res_from_csr;
    wire        mem_res_from_csr;
    wire        conflict_r1_wb;
    wire        conflict_r2_wb;
    wire        conflict_r1_mem;
    wire        conflict_r2_mem;
    wire        conflict_r1_ex;
    wire        conflict_r2_ex;
    wire        wb_rf_we   ;
    wire [ 4:0] wb_rf_waddr;
    wire [31:0] wb_rf_wdata;
    wire        mem_rf_we   ;
    wire [ 4:0] mem_rf_waddr;
    wire [31:0] mem_rf_wdata;
    wire        ex_rf_we   ;
    wire [ 4:0] ex_rf_waddr;
    wire [31:0] ex_rf_wdata;
    // assign conflict = Load_DataHazard || CSR_DataHazard;
    assign conflict  =  (id_delay | ex_res_from_csr) & (conflict_r1_ex & rf_raddr1_valid | conflict_r2_ex & rf_raddr2_valid) | 
                                (mem_res_from_mem | mem_res_from_csr) & (conflict_r1_mem & rf_raddr1_valid | conflict_r2_mem & rf_raddr2_valid); 

    assign {wb_rf_we, 
            wb_rf_waddr, 
            wb_rf_wdata} = wb_rf_zip;
            
    assign {mem_res_from_mem,
            mem_res_from_csr,
            mem_rf_we, 
            mem_rf_waddr,
            mem_rf_wdata} = mem_rf_zip;
            
    assign {ex_res_from_csr,
            id_delay,
            ex_rf_we, 
            ex_rf_waddr, 
            ex_rf_wdata} = ex_rf_zip;
    assign conflict_r1_wb  = (|rf_raddr1) & (rf_raddr1 == wb_rf_waddr)  & wb_rf_we;
    assign conflict_r2_wb  = (|rf_raddr2) & (rf_raddr2 == wb_rf_waddr)  & wb_rf_we;
    assign conflict_r1_mem = (|rf_raddr1) & (rf_raddr1 == mem_rf_waddr) & mem_rf_we;
    assign conflict_r2_mem = (|rf_raddr2) & (rf_raddr2 == mem_rf_waddr) & mem_rf_we;
    assign conflict_r1_ex  = (|rf_raddr1) & (rf_raddr1 == ex_rf_waddr)  & ex_rf_we;
    assign conflict_r2_ex  = (|rf_raddr2) & (rf_raddr2 == ex_rf_waddr)  & ex_rf_we;






















assign br_stall = conflict && (inst_beq | inst_bne | inst_blt | inst_bge | inst_bltu | inst_bgeu);
wire [1:0] ale_valid;
assign ale_valid = {inst_st_w | inst_ld_w, inst_st_h | inst_ld_hu | inst_ld_h};

assign br_taken = (inst_beq  &&  rj_eq_rd
                || inst_bne  && !rj_eq_rd
                || inst_blt  &&  rj_lt_rd_signed
                || inst_bge  && !rj_lt_rd_signed
                || inst_bltu &&  rj_lt_rd_unsigned
                || inst_bgeu && !rj_lt_rd_unsigned
                || inst_jirl
                || inst_bl
                || inst_b) && !conflict && valid;
assign br_target = (inst_beq || inst_bne || inst_blt || inst_bge || inst_bltu || inst_bgeu || inst_bl || inst_b) ? (pc_ID + br_offs) :
                                                   /*inst_jirl*/ (rj_value + jirl_offs);

assign alu_src1 = src1_is_pc  ? pc_ID[31:0] : rj_value;
assign alu_src2 = src2_is_imm ? imm : rkd_value;

assign br_signal = {br_taken, br_target};

assign ID_readygo = ~conflict;
//assign ID_readygo = 1'b1;
assign ID_allowin = !valid || ID_readygo && EXE_allowin || ID_flush;

assign EXE_signal_valid = valid && ID_readygo && ~ID_flush;
assign EXE_signal = {rdcntv_valid, ale_valid, pc_ID, rf_we, rf_waddr, rkd_value, res_from_mem, mem_we, alu_op, alu_src1, alu_src2,
        inst_st_b, inst_st_h, inst_st_w, inst_ld_b, inst_ld_bu, inst_ld_h, inst_ld_hu, inst_ld_w};
//pc_ID[157:126]32, rf_we[125:125]1, rf_waddr[124:120]5, rkd_value[119:88]32, res_from_mem[87:87]1, mem_we[86:83]4, alu_op[82:64]19, alu_src1[63:32]32, alu_src2[31:0]32

//exp12

wire        id_res_from_csr = inst_csrrd | inst_csrwr | inst_csrxchg | inst_rdcntid;
wire [13:0] id_csr_num      = inst_ertn ? `CSR_ERA : 
                                inst_syscall ? `CSR_EENTRY :
                                inst_rdcntid ? `CSR_TID : 
                                inst[23:10];
wire        id_csr_we       = inst_csrwr | inst_csrxchg;
wire [31:0] id_csr_wmask    = {32{inst_csrxchg}} & rj_value | {32{inst_csrwr}};
wire [31:0] id_csr_wvalue   = rkd_value;
wire        id_ertn_flush   = inst_ertn;

//exp18 invtlb excep
assign      invtlb_op_fault = rd[4] | rd[3] | (&rd[2:0]);

wire        id_excp_ine     = ~(type_al | type_bj | type_ld_st 
                                | type_else | type_ex | type_tlb)
                                | (inst_invtlb & invtlb_op_fault);
//    wire [ 5:0] id_csr_ecode = (inst_syscall)? `ECODE_SYS : if_csr_ecode;
//    wire [ 8:0] id_csr_esubcode = if_csr_esubcode;


assign ID_to_EXE_excep_signal = {id_excp_pif, id_excp_ppi, id_excp_tlbr,
                            id_res_from_csr, id_csr_num, id_csr_we, id_csr_wmask, id_csr_wvalue, 
                            id_ertn_flush, has_int, id_excp_adef, inst_syscall, inst_break,
                            id_excp_ine};

assign id_to_ex_tlb = {rd, inst_tlbsrch, inst_tlbwr, inst_tlbfill, inst_tlbrd, inst_invtlb};


endmodule
