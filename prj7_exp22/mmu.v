`include "mycpu_head.vh"

module MMU(
    output wire [18:0] s_vppn,
    output wire        s_va_bit12,
    output wire [ 9:0] s_asid,
    input  wire        s_found,
    input  wire [19:0] s_ppn,
    input  wire [ 5:0] s_ps,
    input  wire [ 1:0] s_plv,
    input  wire [ 1:0] s_mat,
    input  wire        s_d,
    input  wire        s_v,

    input  wire [31:0] va,
    output wire [31:0] pa,
    input  wire [ 9:0] req_asid,
    input  wire [31:0] csr_crmd_rvalue,
    input  wire [31:0] csr_dmw0_rvalue,
    input  wire [31:0] csr_dmw1_rvalue,
    output wire        page_invalid,
    output wire        page_per_denied,
    output wire        page_fault,
    output wire        page_not_dirty,
    output wire        cachable
);

wire [1:0]  csr_crmd_plv;
wire is_direct, is_mapped, is_page_mapped;
assign csr_crmd_plv = csr_crmd_rvalue[`CSR_CRMD_PLV];
assign is_direct =  csr_crmd_rvalue[`CSR_CRMD_DA] && ~csr_crmd_rvalue[`CSR_CRMD_PG];
assign is_mapped = ~csr_crmd_rvalue[`CSR_CRMD_DA] &&  csr_crmd_rvalue[`CSR_CRMD_PG];

wire dmw0_hit, dmw1_hit;
wire [31:0] page_mapped_pa;

assign dmw0_hit = is_mapped && csr_dmw0_rvalue[csr_crmd_plv] && (csr_dmw0_rvalue[`CSR_DMW_VSEG] == va[`CSR_DMW_VSEG]);
assign dmw1_hit = is_mapped && csr_dmw1_rvalue[csr_crmd_plv] && (csr_dmw1_rvalue[`CSR_DMW_VSEG] == va[`CSR_DMW_VSEG]);

assign is_page_mapped = is_mapped && ~dmw0_hit && ~dmw1_hit;

assign {s_vppn, s_va_bit12} = va[31:12];
assign s_asid = req_asid;

assign page_mapped_pa = {32{s_ps == 6'd12}} & {s_ppn[19:0], va[11:0]} |
                        {32{s_ps == 6'd21}} & {s_ppn[19:9], va[20:0]};

assign pa = {32{is_direct}}         & va   |
            {32{dmw0_hit}}          & {csr_dmw0_rvalue[`CSR_DMW_PSEG], va[28:0]} |
            {32{dmw1_hit}}          & {csr_dmw1_rvalue[`CSR_DMW_PSEG], va[28:0]} |
            {32{is_page_mapped}}    & page_mapped_pa;

assign page_invalid     =   is_page_mapped & ~s_v;
assign page_per_denied  =   is_page_mapped & (csr_crmd_plv > s_plv);
assign page_fault       =   is_page_mapped & ~s_found;
assign page_not_dirty   =   is_page_mapped & ~s_d;

wire [1:0] csr_crmd_datm;
wire [1:0]  dmw_mat0;
wire [1:0]  dmw_mat1;
assign csr_crmd_datm = csr_crmd_rvalue[`CSR_CRMD_DATM];
assign dmw_mat0 =   csr_dmw0_rvalue[`CSR_DMW_MAT];
assign dmw_mat1 =   csr_dmw1_rvalue[`CSR_DMW_MAT];
assign cachable = is_direct ? (csr_crmd_datm == 2'b01) :
				    dmw0_hit ? (dmw_mat0 == 2'b01) :
				    dmw1_hit ? (dmw_mat1 == 2'b01) :
				    (s_mat == 2'b01);

endmodule