`ifndef MYCPU_HEAD
`define MYCPU_HEAD

`define IF_TO_ID_EXCEP_WIDTH    1
`define ID_TO_EXE_EXCEP_WIDTH    86
`define EXE_TO_MEM_EXCEP_WIDTH   87
`define MEM_TO_WB_EXCEP_WIDTH   119

//exp18
`define ID_TO_EX_TLB_WIDTH      10
`define EX_TO_MEM_TLB_WIDTH     10
`define MEM_TO_WB_TLB_WIDTH     10


`define WB_TO_IF_CSR_DATA_WIDTH 66
`define WB_TO_IF_REFETCH_WIDTH 33
// exp12
`define CSR_CRMD        14'h0
`define CSR_PRMD        14'h1
`define CSR_EUEN        14'h02
`define CSR_ECFG        14'h04
`define CSR_ESTAT       14'h5
`define CSR_ERA         14'h6
`define CSR_BADV        14'h07
`define CSR_EENTRY      14'hc
`define CSR_SAVE0       14'h30
`define CSR_SAVE1       14'h31
`define CSR_SAVE2       14'h32
`define CSR_SAVE3       14'h33
`define CSR_TID         14'h40
`define CSR_TCFG        14'h41
`define CSR_TVAL        14'h42
`define CSR_TICLR       14'h44

`define CSR_CRMD_PLV    1:0
`define CSR_CRMD_IE     2
`define CSR_CRMD_PIE    2
`define CSR_PRMD_PPLV   1:0
`define CSR_PRMD_PIE    2    
`define CSR_ESTAT_IS10  1:0
`define CSR_ERA_PC      31:0
`define CSR_EENTRY_VA   31:6
`define CSR_SAVE_DATA   31:0

`define CSR_ECFG_LIE    12:0
`define CSR_TICLR_CLR   0
`define CSR_TID_TID     31:0
`define CSR_TCFG_EN     0
`define CSR_TCFG_PERIOD 1
`define CSR_TCFG_INITV  31:2

//------exp18------
// new csr
`define CSR_TLBIDX      14'h010
`define CSR_TLBEHI      14'h011
`define CSR_TLBELO0     14'h012
`define CSR_TLBELO1     14'h013
`define CSR_TLBRENTRY   14'h088
`define CSR_ASID        14'h018
//TLBIDX
`define CSR_TLBIDX_INDEX    3:0
`define CSR_TLBIDX_PS       29:24
`define CSR_TLBIDX_NE       31
// TLBEHI
`define CSR_TLBEHI_VPPN     31:13
// TLBELO0 TLBELO1
`define CSR_TLBELO_V        0
`define CSR_TLBELO_D        1
`define CSR_TLBELO_PLV      3:2
`define CSR_TLBELO_MAT      5:4
`define CSR_TLBELO_G        6
`define CSR_TLBELO_PPN      31:8
// ASID
`define CSR_ASID_ASID       9:0
// TLBRENTRY
`define CSR_TLBRENTRY_PA    31:6



`define ECODE_INT       6'h0
`define ECODE_ADEF       6'h8
`define ECODE_ALE       6'h9
`define ECODE_SYS       6'hB
`define ECODE_BRK       6'hc
`define ECODE_INE       6'hd
`define ECODE_TLBR      6'h3F

`define ESUBCODE_ADEF   9'h0


`define FS2DS_LEN 65
`define DS2ES_LEN 250
`define ES2MS_LEN 123
`define MS2WS_LEN 150

//exp15 AXI_BRIDGE
`define STATE_IDLE      5'b00001
`define STATE_AR_REQ    3'b010
`define STATE_AR_ACK    3'b100

`define STATE_R_RDY     3'b010
`define STATE_R_ACK     3'b100

`define STATE_W_REQ     5'b00010
`define STATE_W_ADDR    5'b00100
`define STATE_W_DATA    5'b01000
`define STATE_W_ACK     5'b10000

`define STATE_B_REQ     3'b010
`define STATE_B_ACK     3'b100

`define TLBNUM             16

`endif