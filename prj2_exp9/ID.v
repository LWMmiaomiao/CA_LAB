module id_stage(
    input  wire        clk,
    input  wire        reset,
    input  wire        Load_DataHazard,
    input  wire        valid,
    input  wire [63:0] signal,
    input  wire [31:0] rf_rdata1,
    input  wire [31:0] rf_rdata2,
    input  wire        EXE_allowin,
    
    output wire [ 4:0] rf_raddr1,
    output wire [ 4:0] rf_raddr2,
    output wire [32:0] br_signal,// br_taken[32:32] br_target[31:0]
    output wire        ID_readygo,
    output wire        ID_allowin,
    output wire        EXE_signal_valid,
    output wire [150:0]EXE_signal
);

wire [31:0] pc_ID;
wire [31:0] inst;
wire        br_taken;
wire [31:0] br_target;
wire [ 5:0] op_31_26;
wire [ 3:0] op_25_22;
wire [ 1:0] op_21_20;
wire [ 4:0] op_19_15;
wire [ 4:0] rd;
wire [ 4:0] rj;
wire [ 4:0] rk;
wire [11:0] i12;
wire [19:0] i20;
wire [15:0] i16;
wire [25:0] i26;
assign {inst, pc_ID} = signal;
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
assign op_31_26  = inst[31:26];
assign op_25_22  = inst[25:22];
assign op_21_20  = inst[21:20];
assign op_19_15  = inst[19:15];

decoder_6_64 u_dec0(.in(op_31_26 ), .out(op_31_26_d ));
decoder_4_16 u_dec1(.in(op_25_22 ), .out(op_25_22_d ));
decoder_2_4  u_dec2(.in(op_21_20 ), .out(op_21_20_d ));
decoder_5_32 u_dec3(.in(op_19_15 ), .out(op_19_15_d ));

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
wire        inst_ld_w;
wire        inst_st_w;
wire        inst_jirl;
wire        inst_b;
wire        inst_bl;
wire        inst_beq;
wire        inst_bne;
wire        inst_lu12i_w;

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
assign inst_st_w   = op_31_26_d[6'h0a] & op_25_22_d[4'h6];
assign inst_jirl   = op_31_26_d[6'h13];//no rk
assign inst_b      = op_31_26_d[6'h14];//no rj rk
assign inst_bl     = op_31_26_d[6'h15];//no rj rk
assign inst_beq    = op_31_26_d[6'h16];
assign inst_bne    = op_31_26_d[6'h17];
assign inst_lu12i_w= op_31_26_d[6'h05] & ~inst[25];//no rj rk

wire [11:0] alu_op;
wire [31:0] alu_src1;
wire [31:0] alu_src2;
assign alu_op[ 0] = inst_add_w | inst_addi_w | inst_ld_w | inst_st_w
                    | inst_jirl | inst_bl;
assign alu_op[ 1] = inst_sub_w;
assign alu_op[ 2] = inst_slt;
assign alu_op[ 3] = inst_sltu;
assign alu_op[ 4] = inst_and;
assign alu_op[ 5] = inst_nor;
assign alu_op[ 6] = inst_or;
assign alu_op[ 7] = inst_xor;
assign alu_op[ 8] = inst_slli_w;
assign alu_op[ 9] = inst_srli_w;
assign alu_op[10] = inst_srai_w;
assign alu_op[11] = inst_lu12i_w;

wire        need_ui5;
wire        need_si12;
wire        need_si16;
wire        need_si20;
wire        need_si26;
wire        src2_is_4;
assign need_ui5   =  inst_slli_w | inst_srli_w | inst_srai_w;
assign need_si12  =  inst_addi_w | inst_ld_w | inst_st_w;
assign need_si16  =  inst_jirl | inst_beq | inst_bne;
assign need_si20  =  inst_lu12i_w;
assign need_si26  =  inst_b | inst_bl;
assign src2_is_4  =  inst_jirl | inst_bl;

wire        load_op;
wire        src1_is_pc;
wire        src2_is_imm;
wire        res_from_mem;
wire        dst_is_r1;
wire        gr_we;
wire        rf_we;
wire [ 3:0] mem_we;
wire        src_reg_is_rd;
wire [ 4:0] dest;
wire [ 4:0] rf_waddr;
wire [31:0] rj_value;
wire [31:0] rkd_value;
wire        rj_eq_rd;
wire [31:0] imm;
wire [31:0] br_offs;
wire [31:0] jirl_offs;
wire        rf_raddr1_valid;
wire        rf_raddr2_valid;

assign rf_raddr1_valid = !inst_b && !inst_bl && !inst_lu12i_w;
assign rf_raddr2_valid = !inst_b && !inst_bl && !inst_lu12i_w && !inst_slli_w && !inst_srli_w && !inst_srai_w && !inst_addi_w && !inst_ld_w && !inst_jirl;

assign imm = src2_is_4 ? 32'h4                      :
             need_si20 ? {i20[19:0], 12'b0}         :
/*need_ui5 || need_si12*/{{20{i12[11]}}, i12[11:0]} ;

assign br_offs = need_si26 ? {{ 4{i26[25]}}, i26[25:0], 2'b0} :
                             {{14{i16[15]}}, i16[15:0], 2'b0} ;

assign jirl_offs = {{14{i16[15]}}, i16[15:0], 2'b0};

assign src_reg_is_rd = inst_beq | inst_bne | inst_st_w;

assign src1_is_pc    = inst_jirl | inst_bl;

assign src2_is_imm   = inst_slli_w |
                       inst_srli_w |
                       inst_srai_w |
                       inst_addi_w |
                       inst_ld_w   |
                       inst_st_w   |
                       inst_lu12i_w|
                       inst_jirl   |
                       inst_bl     ;

assign res_from_mem  = inst_ld_w && valid;
assign dst_is_r1     = inst_bl;
assign gr_we         = ~inst_st_w & ~inst_beq & ~inst_bne & ~inst_b;
assign rf_we         = gr_we && valid;
assign mem_we        = {4{inst_st_w && valid}};
assign dest          = dst_is_r1 ? 5'd1 : rd;
assign rf_waddr      = dest;

/*严格判定Load_DataHazard条件*/
assign rf_raddr1 = rf_raddr1_valid ? rj : 5'b0;
assign rf_raddr2 = rf_raddr2_valid ? (src_reg_is_rd ? rd : rk) : 5'b0;
//assign rf_raddr1 = rj;
//assign rf_raddr2 = src_reg_is_rd ? rd : rk;

assign rj_value  = rf_rdata1;
assign rkd_value = rf_rdata2;

assign rj_eq_rd = (rj_value == rkd_value);
assign br_taken = (   inst_beq  &&  rj_eq_rd
                   || inst_bne  && !rj_eq_rd
                   || inst_jirl
                   || inst_bl
                   || inst_b
                  ) && valid;
assign br_target = (inst_beq || inst_bne || inst_bl || inst_b) ? (pc_ID + br_offs) :
                                                   /*inst_jirl*/ (rj_value + jirl_offs);

assign alu_src1 = src1_is_pc  ? pc_ID[31:0] : rj_value;
assign alu_src2 = src2_is_imm ? imm : rkd_value;

assign br_signal = {br_taken, br_target};

assign ID_readygo = !Load_DataHazard;
//assign ID_readygo = 1'b1;
assign ID_allowin = ID_readygo && EXE_allowin;

assign EXE_signal_valid = valid && !Load_DataHazard;
assign EXE_signal = {pc_ID, rf_we, rf_waddr, rkd_value, res_from_mem, mem_we, alu_op, alu_src1, alu_src2};
//pc_ID[150:119]32, rf_we[118:118]1, rf_waddr[117:113]5, rkd_value[112:81]32, res_from_mem[80:80]1, mem_we[79:76]4, alu_op[75:64]12, alu_src1[63:32]32, alu_src2[31:0]32
endmodule