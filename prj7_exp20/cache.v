`define CACHE_IDLE      5'b00001
`define CACHE_LOOKUP    5'b00010
`define CACHE_MISS      5'b00100
`define CACHE_REPLACE   5'b01000
`define CACHE_REFILL    5'b10000

`define WB_IDLE     2'b01
`define WB_WRITE    2'b10

module lfsr_random (
    input wire clk,
    input wire resetn,
    output reg rnd
);
    // A 16-bit Linear Feedback Shift Register (LFSR) for random number generation
    reg [15:0] lfsr;
    wire feedback;
    assign feedback = lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10];
    always @(posedge clk) begin
        if (!resetn)
            lfsr <= 16'd1926; // seed value for LFSR, 19260817, the birthday of a great person
        else
            lfsr <= {lfsr[14:0], feedback};
    end
    always @(posedge clk) begin
        if (!resetn)
            rnd <= 1'd0;
        else
            rnd <= lfsr[0];
    end
endmodule


module cache(
    input clk,
    input resetn,
    input valid,
    input op,
    input [ 7:0] index,
    input [19:0] tag,
    input [ 3:0] offset,
    input [ 3:0] wstrb,
    input [31:0] wdata,
    output addr_ok,
    output data_ok,
    output [31:0] rdata,
    output rd_req,
    output [ 2:0] rd_type,
    output [31:0] rd_addr,
    input rd_rdy,
    input ret_valid,
    input ret_last,
    input [31:0] ret_data,
    output wr_req,
    output [ 2:0] wr_type,
    output [31:0] wr_addr,
    output [ 3:0] wr_wstrb,
    output[127:0] wr_data,
    input wr_rdy
);

wire hit_write, conflict;
wire victim_way;
reg victim_way_reg;
wire way0_hit, way1_hit, cache_hit;

// input regs
reg reg_op;
reg [ 7:0] reg_index;
reg [19:0] reg_tag;
reg [ 3:0] reg_offset;
reg [ 3:0] reg_wstrb;
reg [31:0] reg_wdata;
always @ (posedge clk or negedge resetn) begin
    if (!resetn) begin
        reg_op <= 1'b0;
        reg_index <= 8'b0;
        reg_tag <= 20'b0;
        reg_offset <= 4'b0;
        reg_wstrb <= 4'b0;
        reg_wdata <= 32'b0;
    end else if (valid && addr_ok) begin
        reg_op <= op;
        reg_index <= index;
        reg_tag <= tag;
        reg_offset <= offset;
        reg_wstrb <= wstrb;
        reg_wdata <= wdata;
    end
end
// write buffer regs
reg wb_way;
reg [7:0] wb_index;
reg [3:0] wb_offset;
reg [3:0] wb_wstrb;
reg [31:0] wb_wdata;
always @ (posedge clk or negedge resetn) begin
    if (!resetn) begin
        wb_way <= 2'b0;
        wb_index <= 8'b0;
        wb_offset <= 4'b0;
        wb_wstrb <= 4'b0;
        wb_wdata <= 32'b0;
    end else if (hit_write) begin
        wb_way <= way0_hit ? 1'b0 : 1'b1;
        wb_index <= reg_index;
        wb_offset <= reg_offset;
        wb_wstrb <= reg_wstrb;
        wb_wdata <= reg_wdata;
    end
end

// state regs
reg [4:0] state;
reg [4:0] next_state;
reg [1:0] wb_state;
reg [1:0] wb_next_state;

// ram instance
wire [ 1:0] tagv_we;
wire [ 7:0] tagv_addr;
wire [20:0] tagv_in;
wire [20:0] tagv_out [1:0];
wire ens;
assign ens = 1'b0;
TAG_RAM tagv_0 (
    .clka(clk), .wea(tagv_we[0]), .ena(ens),
    .addra(tagv_addr), .dina(tagv_in), .douta(tagv_out[0])
);
TAG_RAM tagv_1 (
    .clka(clk), .wea(tagv_we[1]), .ena(ens),
    .addra(tagv_addr), .dina(tagv_in), .douta(tagv_out[1])
);

reg [255:0] dirty [1:0];

wire [ 3:0] bank_we [1:0][3:0];
wire [ 7:0] bank_addr;
wire [31:0] bank_in [3:0];
wire [31:0] bank_out [1:0][3:0];
DATA_Bank_RAM way0_bank0(
    .clka(clk), .wea(bank_we[0][0]), .ena(ens),
    .addra(bank_addr), .dina(bank_in[0]), .douta(bank_out[0][0])
);
DATA_Bank_RAM way0_bank1(
    .clka(clk), .wea(bank_we[0][1]), .ena(ens),
    .addra(bank_addr), .dina(bank_in[1]), .douta(bank_out[0][1])
);
DATA_Bank_RAM way0_bank2(
    .clka(clk), .wea(bank_we[0][2]), .ena(ens),
    .addra(bank_addr), .dina(bank_in[2]), .douta(bank_out[0][2])
);
DATA_Bank_RAM way0_bank3(
    .clka(clk), .wea(bank_we[0][3]), .ena(ens),
    .addra(bank_addr), .dina(bank_in[3]), .douta(bank_out[0][3])
);
DATA_Bank_RAM way1_bank0(
    .clka(clk), .wea(bank_we[1][0]), .ena(ens),
    .addra(bank_addr), .dina(bank_in[0]), .douta(bank_out[1][0])
);
DATA_Bank_RAM way1_bank1(
    .clka(clk), .wea(bank_we[1][1]), .ena(ens),
    .addra(bank_addr), .dina(bank_in[1]), .douta(bank_out[1][1])
);
DATA_Bank_RAM way1_bank2(
    .clka(clk), .wea(bank_we[1][2]), .ena(ens),
    .addra(bank_addr), .dina(bank_in[2]), .douta(bank_out[1][2])
);
DATA_Bank_RAM way1_bank3(
    .clka(clk), .wea(bank_we[1][3]), .ena(ens),
    .addra(bank_addr), .dina(bank_in[3]), .douta(bank_out[1][3])
);

reg [1:0] cnt;
always @ (posedge clk or negedge resetn) begin
    if (!resetn)
        cnt <= 2'b00;
    else if (ret_valid)
        cnt <= ret_last ? 2'b00 : cnt + 1;
end

assign bank_we[0][0] = {4{wb_state == `WB_WRITE && wb_way == 1'b0 && wb_offset[3:2] == 2'b00}} & wb_wstrb |
                       {4{ret_valid && cnt == 2'b00 && victim_way_reg == 1'b0}};
assign bank_we[0][1] = {4{wb_state == `WB_WRITE && wb_way == 1'b0 && wb_offset[3:2] == 2'b01}} & wb_wstrb |
                       {4{ret_valid && cnt == 2'b01 && victim_way_reg == 1'b0}};
assign bank_we[0][2] = {4{wb_state == `WB_WRITE && wb_way == 1'b0 && wb_offset[3:2] == 2'b10}} & wb_wstrb |
                       {4{ret_valid && cnt == 2'b10 && victim_way_reg == 1'b0}};
assign bank_we[0][3] = {4{wb_state == `WB_WRITE && wb_way == 1'b0 && wb_offset[3:2] == 2'b11}} & wb_wstrb |
                       {4{ret_valid && cnt == 2'b11 && victim_way_reg == 1'b0}};
assign bank_we[1][0] = {4{wb_state == `WB_WRITE && wb_way == 1'b1 && wb_offset[3:2] == 2'b00}} & wb_wstrb |
                       {4{ret_valid && cnt == 2'b00 && victim_way_reg == 1'b1}};
assign bank_we[1][1] = {4{wb_state == `WB_WRITE && wb_way == 1'b1 && wb_offset[3:2] == 2'b01}} & wb_wstrb |
                       {4{ret_valid && cnt == 2'b01 && victim_way_reg == 1'b1}};
assign bank_we[1][2] = {4{wb_state == `WB_WRITE && wb_way == 1'b1 && wb_offset[3:2] == 2'b10}} & wb_wstrb |
                       {4{ret_valid && cnt == 2'b10 && victim_way_reg == 1'b1}};
assign bank_we[1][3] = {4{wb_state == `WB_WRITE && wb_way == 1'b1 && wb_offset[3:2] == 2'b11}} & wb_wstrb |
                       {4{ret_valid && cnt == 2'b11 && victim_way_reg == 1'b1}};

assign bank_addr = (state == `CACHE_IDLE || state == `CACHE_LOOKUP) ? index : reg_index;
wire [31:0] masked_wdata;
wire [31:0] ext_mask;
assign ext_mask = {{8{reg_wstrb[3]}}, {8{reg_wstrb[2]}}, {8{reg_wstrb[1]}}, {8{reg_wstrb[0]}}};
assign masked_wdata = (reg_wdata & ext_mask) | (ret_data & ~ext_mask);
assign bank_in[0] = {32{wb_state == `WB_WRITE}} & wb_wdata |
                    {32{wb_state == `WB_IDLE && (reg_offset[3:2] != 2'b00 || !reg_op)}} & ret_data |
                    {32{wb_state == `WB_IDLE && (reg_offset[3:2] == 2'b00 &&  reg_op)}} & masked_wdata;
assign bank_in[1] = {32{wb_state == `WB_WRITE}} & wb_wdata |
                    {32{wb_state == `WB_IDLE && (reg_offset[3:2] != 2'b01 || !reg_op)}} & ret_data |
                    {32{wb_state == `WB_IDLE && (reg_offset[3:2] == 2'b01 &&  reg_op)}} & masked_wdata;
assign bank_in[2] = {32{wb_state == `WB_WRITE}} & wb_wdata |
                    {32{wb_state == `WB_IDLE && (reg_offset[3:2] != 2'b10 || !reg_op)}} & ret_data |
                    {32{wb_state == `WB_IDLE && (reg_offset[3:2] == 2'b10 &&  reg_op)}} & masked_wdata;
assign bank_in[3] = {32{wb_state == `WB_WRITE}} & wb_wdata |
                    {32{wb_state == `WB_IDLE && (reg_offset[3:2] != 2'b11 || !reg_op)}} & ret_data |
                    {32{wb_state == `WB_IDLE && (reg_offset[3:2] == 2'b11 &&  reg_op)}} & masked_wdata;

lfsr_random lfsr (
    .clk(clk), .resetn(resetn), .rnd(victim_way)
);
always @ (posedge clk) begin
    if (state == `CACHE_IDLE || state == `CACHE_LOOKUP)
        victim_way_reg <= victim_way;
end

// state machine
always @ (posedge clk) begin
    if (!resetn)
        state <= `CACHE_IDLE;
    else
        state <= next_state;
end
always @ (*) begin
    case (state)
    `CACHE_IDLE:
        if (valid)
            next_state = `CACHE_LOOKUP;
        else
            next_state = `CACHE_IDLE;
    `CACHE_LOOKUP:
        if (cache_hit) begin
            if (!valid || conflict)
                next_state = `CACHE_IDLE;
            else
                next_state = `CACHE_LOOKUP;
        end
        else if (!dirty[victim_way_reg][reg_index] || !tagv_out[victim_way_reg][0])
            next_state = `CACHE_REPLACE;
        else
            next_state = `CACHE_MISS;
    `CACHE_MISS:
        if (!wr_rdy)
            next_state = `CACHE_MISS;
        else
            next_state = `CACHE_REPLACE;
    `CACHE_REPLACE:
        if (!rd_rdy)
            next_state = `CACHE_REPLACE;
        else
            next_state = `CACHE_REFILL;
    `CACHE_REFILL:
        if (ret_valid && ret_last)
            next_state = `CACHE_IDLE;
        else
            next_state = `CACHE_REFILL;
    default:
        next_state = `CACHE_IDLE;
    endcase
end

always @ (posedge clk) begin
    if (!resetn)
        wb_state <= `WB_IDLE;
    else
        wb_state <= wb_next_state;
end
always @ (*) begin
    case (wb_state)
    `WB_IDLE:
        if (!hit_write)
            wb_next_state = `WB_IDLE;
        else
            wb_next_state = `WB_WRITE;
    `WB_WRITE:
        if (hit_write && wr_rdy)
            wb_next_state = `WB_WRITE;
        else
            wb_next_state = `WB_IDLE;
    default:
        wb_next_state = `WB_IDLE;
    endcase
end


assign way0_hit = tagv_out[0][0] && (tagv_out[0][20:1] == reg_tag);
assign way1_hit = tagv_out[1][0] && (tagv_out[1][20:1] == reg_tag);
assign cache_hit = way0_hit || way1_hit;

assign tagv_addr = (state == `CACHE_IDLE || state == `CACHE_LOOKUP) ? index : reg_index;
assign tagv_in = {reg_tag, 1'b1};
assign tagv_we[0] = ret_valid && ret_last && victim_way_reg == 1'b0;
assign tagv_we[1] = ret_valid && ret_last && victim_way_reg == 1'b1;

assign hit_write = reg_op && cache_hit && state == `CACHE_LOOKUP;
assign conflict = !op && valid && (hit_write || wb_state == `WB_WRITE)
                      && index == reg_index && offset[3:2] == reg_offset[3:2];


always @ (posedge clk) begin
    if (!resetn) begin
        dirty[0] <= 256'b0;
        dirty[1] <= 256'b0;
    end else if (wb_state == `WB_WRITE)
        dirty[wb_way][wb_index] <= 1'b1;
    else if (ret_valid)
        dirty[victim_way_reg][reg_index] <= reg_op;
end


assign addr_ok = (state == `CACHE_IDLE) || (state == `CACHE_LOOKUP && cache_hit && valid && (op || !conflict));
assign data_ok = (state == `CACHE_LOOKUP && (cache_hit || reg_op)) ||
                 (state == `CACHE_REFILL && !reg_op && ret_valid && cnt == reg_offset[3:2]);

assign rdata = ret_valid ? ret_data : bank_out[way1_hit][reg_offset[3:2]];

assign rd_req = state == `CACHE_REPLACE;
assign rd_type = 3'b100;
assign rd_addr = {reg_tag, reg_index, 4'b0};
assign wr_req = (state == `CACHE_MISS && next_state == `CACHE_REPLACE);
assign wr_type = 3'b100;
assign wr_addr = {tagv_out[victim_way_reg][20:1], reg_index, 4'b0};
assign wr_wstrb = 4'b1111;
assign wr_data = {bank_out[victim_way_reg][3], bank_out[victim_way_reg][2], bank_out[victim_way_reg][1], bank_out[victim_way_reg][0]};

endmodule