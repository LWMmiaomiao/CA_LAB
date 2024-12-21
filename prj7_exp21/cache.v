// module cache (
//     input  wire        resetn, 
//     input  wire        clk,

//     //Cache与CPU流水线的交互接口
//     input  wire        valid,
//     input  wire        op,
//     input  wire [ 7:0] index,
//     input  wire [19:0] tag,
//     input  wire [ 3:0] offset,
//     input  wire [ 3:0] wstrb,
//     input  wire [31:0] wdata,

//     output wire        addr_ok,
//     output wire        data_ok,
//     output wire [31:0] rdata,

//     //Cache与AXI的交互接�????
//     output wire        rd_req,
//     output wire [ 2:0] rd_type,
//     output wire [31:0] rd_addr,

//     input  wire        rd_rdy,
//     input  wire        ret_valid,
//     input  wire        ret_last,
//     input  wire [31:0] ret_data,

//     output wire        wr_req,
//     output wire [ 2:0] wr_type,
//     output wire [31:0] wr_addr,
//     output wire [ 3:0] wr_wstrb,
//     output wire [127:0]wr_data,

//     input  wire        wr_rdy
// );

// //main state machine variables
// localparam  IDLE    = 5'b00001, // 1
//             LOOKUP  = 5'b00010, // 2
//             MISS    = 5'b00100, // 4
//             REPLACE = 5'b01000, // 8
//             REFILL  = 5'b10000; // 10
// reg  [ 4:0] curr_state;
// reg  [ 4:0] next_state;

// //write buffer state machine variables
// localparam  WRBUF_IDLE  = 2'b01, // 1
//             WRBUF_WRITE = 2'b10; // 2
// reg  [ 1:0] wrbuf_curr_state;
// reg  [ 1:0] wrbuf_next_state;

// //Request Bdffer variables
// reg        reg_op;
// reg [ 7:0] reg_index;
// reg [19:0] reg_tag;
// reg [ 3:0] reg_offset;
// reg [ 3:0] reg_wstrb;
// reg [31:0] reg_wdata;

// //Tag Compare variables
// wire        way0_hit;
// wire        way1_hit;
// wire        cache_hit;
// wire        way0_v;
// wire        way1_v;
// wire [19:0] way0_tag;
// wire [19:0] way1_tag;

// //Data Select variables
// wire [31:0] way0_load_word;
// wire [31:0] way1_load_word;
// wire [31:0] load_res;
// wire [127:0]replace_data;
// wire [127:0]way0_data;
// wire [127:0]way1_data;

// //Miss Buffer variables
// reg  [ 1:0] ret_cnt;
// reg  [31:0] load_miss_res;

// //LFSR
// //reg [15:0] lsfr;
// wire       replace_way;
// wire       replace_d;
// wire       replace_v;

// //Write Buffer variables
// wire        hit_write;
// wire        hit_write_hazard;
// reg         wrbuf_way;
// reg  [ 7:0] wrbuf_index;
// reg  [ 3:0] wrbuf_offset;
// reg  [ 3:0] wrbuf_wstrb;
// reg  [31:0] wrbuf_wdata;

// //D-regfile
// reg [255:0] D_table [1:0];

// //TAGV-RAM
// wire        tagv_we    [1:0];
// wire [ 7:0] tagv_addr  [1:0];
// wire [20:0] tagv_wdata [1:0];
// wire [20:0] tagv_rdata [1:0];

// //Data Bank-RAM
// wire [ 3:0] data_bank_RAM_we    [1:0][3:0];
// wire [ 7:0] data_bank_RAM_addr  [1:0][3:0];
// wire [31:0] data_bank_RAM_wdata [1:0][3:0];
// wire [31:0] data_bank_RAM_rdata [1:0][3:0];

// //main state machine
// always @ (posedge clk) begin
//     if (~resetn) begin
//         curr_state <= IDLE;
//     end else begin
//         curr_state <= next_state;
//     end
// end

// always @ (*) begin
//     case (curr_state)
//         IDLE:
//             if (valid & ~hit_write_hazard) begin
//                 next_state = LOOKUP;
//             end else begin
//                 next_state = IDLE;
//             end
//         LOOKUP:
//             if (cache_hit & (~valid | hit_write_hazard)) begin
//                 next_state = IDLE;
//             end else if (cache_hit & valid & ~hit_write_hazard) begin
//                 next_state = LOOKUP;
//             end else begin
//                 next_state = MISS;
//             end
//         MISS:
//             if (wr_rdy) begin
//                 next_state = REPLACE;
//             end else begin
//                 next_state = MISS;
//             end
//         REPLACE:
//             if (rd_rdy) begin
//                 next_state = REFILL;
//             end else begin
//                 next_state = REPLACE;
//             end
//         REFILL:
//             if (ret_valid & ret_last) begin
//                 next_state = IDLE;
//             end else begin
//                 next_state = REFILL;
//             end
//         default:next_state = IDLE;
//     endcase
// end

// // write buffer state machine
// always @ (posedge clk) begin
//     if (~resetn) begin
//         wrbuf_curr_state <= WRBUF_IDLE;
//     end else begin
//         wrbuf_curr_state <= wrbuf_next_state;
//     end
// end

// always @ (*) begin
//     case (wrbuf_curr_state)
//         WRBUF_IDLE:
//             if (hit_write) begin
//                 wrbuf_next_state = WRBUF_WRITE;
//             end else begin
//                 wrbuf_next_state = WRBUF_IDLE;
//             end
//         WRBUF_WRITE:
//             if (hit_write) begin
//                 wrbuf_next_state = WRBUF_WRITE;
//             end else begin
//                 wrbuf_next_state = WRBUF_IDLE;
//             end
//         default:wrbuf_next_state = WRBUF_IDLE;
//     endcase
// end

// //Request Bdffer
// always @ (posedge clk) begin
//     if (~resetn) begin
//         reg_op     <= 1'b0;
//         reg_index  <= 8'b0;
//         reg_tag    <= 20'b0;
//         reg_offset <= 4'b0;
//         reg_wstrb  <= 4'b0;
//         reg_wdata  <= 32'b0;
//     end else if(next_state == LOOKUP)begin
//         reg_op     <= op;
//         reg_index  <= index;
//         reg_tag    <= tag;
//         reg_offset <= offset;
//         reg_wstrb  <= wstrb;
//         reg_wdata  <= wdata;
//     end
// end


// //Tag Compare
// assign way0_v    = tagv_rdata[0][20];
// assign way1_v    = tagv_rdata[1][20];
// assign way0_tag  = tagv_rdata[0][19:0];
// assign way1_tag  = tagv_rdata[1][19:0];
// assign way0_hit  = way0_v && (way0_tag == reg_tag);
// assign way1_hit  = way1_v && (way1_tag == reg_tag);
// assign cache_hit = way0_hit || way1_hit;

// //Data Select
// assign way0_data      = {data_bank_RAM_rdata[0][3],data_bank_RAM_rdata[0][2],data_bank_RAM_rdata[0][1],data_bank_RAM_rdata[0][0]};
// assign way1_data      = {data_bank_RAM_rdata[1][3],data_bank_RAM_rdata[1][2],data_bank_RAM_rdata[1][1],data_bank_RAM_rdata[1][0]};
// assign way0_load_word = way0_data[reg_offset[3:2]*32 +: 32];
// assign way1_load_word = way1_data[reg_offset[3:2]*32 +: 32];
// assign load_res = {32{way0_hit}} & way0_load_word
//                 | {32{way1_hit}} & way1_load_word;
// assign replace_data = replace_way ? way1_data : way0_data;
// assign replace_d    = replace_way ? D_table[1][wrbuf_index] : D_table[0][wrbuf_index];
// assign replace_v    = replace_way ? way1_v : way0_v;

// //Miss Buffer
// always @(posedge clk) begin
//     if(~resetn) begin
//         ret_cnt <= 2'b0;
//     end else if(ret_valid & ~ret_last) begin
//         ret_cnt <= ret_cnt + 2'b1;
//     end else if(ret_valid & ret_last) begin
//         ret_cnt <= 2'b0;
//     end
// end
// always@(posedge clk)begin
//     if(~resetn)begin
//         load_miss_res <= 32'b0;
//     end
//     else if(curr_state == REFILL & ret_valid & ret_cnt == reg_offset[3:2])begin
//         load_miss_res <= ret_data;
//     end
// end

// //LFSR
// reg [7:0]   lfsr;
// wire feedback;
// assign feedback = lfsr[6] ^ lfsr[4] ^ lfsr[2] ^ lfsr[0];

// always @(posedge clk)begin
//     if(~resetn)
//         lfsr <= 8'b00000001;
//     else if(curr_state == REFILL & ret_valid & ret_last)
//         lfsr <= {lfsr[6:0], feedback};
// end
// assign replace_way = lfsr[0];

// //Write Buffer
// assign hit_write = (curr_state == LOOKUP) & cache_hit & reg_op;
// assign hit_write_hazard = (curr_state == LOOKUP) & hit_write & valid & ~op & ({reg_index,reg_offset} == {index,offset})
//                         | (wrbuf_curr_state == WRBUF_WRITE) & valid & ~op & (reg_offset[3:2] == offset[3:2]);
// always @(posedge clk)begin
//     if(~resetn) begin
//         wrbuf_index  <= 8'b0;
//         wrbuf_way    <= 1'b0;
//         wrbuf_wstrb  <= 4'b0;
//         wrbuf_wdata  <= 32'b0;
//         wrbuf_offset <= 4'b0;
//     end else if(curr_state == LOOKUP && reg_op && cache_hit) begin
//         wrbuf_index  <= reg_index;
//         wrbuf_way    <= way1_hit;
//         wrbuf_wstrb  <= reg_wstrb;
//         wrbuf_wdata  <= reg_wdata;
//         wrbuf_offset <= reg_offset;
//     end
// end


// //Dirty table 
// always @(posedge clk) begin
//     if(~resetn) begin
//         D_table[0] <= 256'b0;
//         D_table[1] <= 256'b0;
//     end else if(wrbuf_curr_state == WRBUF_WRITE) begin
//         D_table[wrbuf_way][wrbuf_index] <= 1'b1;
//     end
// end

// //TAGV-RAM 
// assign tagv_we[0]    = curr_state == REFILL & ret_valid & ret_last & (replace_way == 1'b0);
// assign tagv_we[1]    = curr_state == REFILL & ret_valid & ret_last & (replace_way == 1'b1);
// assign tagv_addr[0]  = (curr_state == IDLE) | (curr_state == LOOKUP) ? index : reg_index;
// assign tagv_addr[1]  = (curr_state == IDLE) | (curr_state == LOOKUP) ? index : reg_index;
// assign tagv_wdata[0] = {1'b1,reg_tag};
// assign tagv_wdata[1] = {1'b1,reg_tag};

// genvar i, j;
// generate for (i = 0; i < 2; i = i+1) begin
//     TAG_RAM tagv_rami(
//         .clka (clk),
//         .ena(1'b1),
//         .wea  (tagv_we[i]),
//         .addra(tagv_addr[i]),
//         .dina (tagv_wdata[i]),
//         .douta(tagv_rdata[i])
//     );
// end
// endgenerate

// //Data Bank-RAM 
// generate for (i = 0; i < 4; i = i+1) begin
//     assign data_bank_RAM_we[0][i]    = {4{(wrbuf_curr_state == WRBUF_WRITE) & (wrbuf_offset[3:2] == i) & (wrbuf_way == 1'b0)}} & wrbuf_wstrb
//                                  | {4{(curr_state == REFILL) & ret_valid & ret_cnt == i & (replace_way == 1'b0)}};
//     assign data_bank_RAM_we[1][i]    = {4{(wrbuf_curr_state == WRBUF_WRITE) & (wrbuf_offset[3:2] == i) & (wrbuf_way == 1'b1)}} & wrbuf_wstrb
//                                  | {4{(curr_state == REFILL) & ret_valid & ret_cnt == i & (replace_way == 1'b1)}};
//     assign data_bank_RAM_addr[0][i]  = (wrbuf_curr_state == WRBUF_WRITE & wrbuf_offset[3:2] == i & wrbuf_way == 1'b0) ? wrbuf_index :
//                                    (curr_state == IDLE | curr_state == LOOKUP) ? index : reg_index;
//     assign data_bank_RAM_addr[1][i]  = (wrbuf_curr_state == WRBUF_WRITE & wrbuf_offset[3:2] == i & wrbuf_way == 1'b1) ? wrbuf_index :
//                                    (curr_state == IDLE | curr_state == LOOKUP) ? index : reg_index;
//     assign data_bank_RAM_wdata[0][i] = wrbuf_curr_state == WRBUF_WRITE  ? wrbuf_wdata : 
//                                    (reg_op & reg_offset[3:2] == i) ? 
//                                    {reg_wstrb[3] ? reg_wdata[31:24] : ret_data[31:24],
//                                     reg_wstrb[2] ? reg_wdata[23:16] : ret_data[23:16],
//                                     reg_wstrb[1] ? reg_wdata[15: 8] : ret_data[15: 8],
//                                     reg_wstrb[0] ? reg_wdata[ 7: 0] : ret_data[ 7: 0]} :
//                                    ret_data;
//     assign data_bank_RAM_wdata[1][i] = wrbuf_curr_state == WRBUF_WRITE  ? wrbuf_wdata : 
//                                    (reg_op & reg_offset[3:2] == i) ? 
//                                    {reg_wstrb[3] ? reg_wdata[31:24] : ret_data[31:24],
//                                     reg_wstrb[2] ? reg_wdata[23:16] : ret_data[23:16],
//                                     reg_wstrb[1] ? reg_wdata[15: 8] : ret_data[15: 8],
//                                     reg_wstrb[0] ? reg_wdata[ 7: 0] : ret_data[ 7: 0]} :
//                                    ret_data;                            
// end
// endgenerate

// generate for (i = 0; i < 2; i = i+1) begin
//     for (j = 0; j < 4; j = j+1) begin
//         DATA_Bank_RAM_RAM db_rami(
//             .clka (clk),
//             .ena  (1'b1),
//             .wea  (data_bank_RAM_we[i][j]),
//             .addra(data_bank_RAM_addr[i][j]),
//             .dina (data_bank_RAM_wdata[i][j]),
//             .douta(data_bank_RAM_rdata[i][j])
//         );
//     end
// end
// endgenerate


// assign addr_ok = (curr_state == IDLE) 
//                | (curr_state == LOOKUP & cache_hit & valid & (op | (~op & ~hit_write_hazard))); 
// assign data_ok = (curr_state == LOOKUP & cache_hit)
//                | (curr_state == REFILL & ret_valid & ret_cnt==reg_offset[3:2]);
// assign rdata   = curr_state == LOOKUP & cache_hit ? load_res
//                 :ret_data;


// assign rd_req  = curr_state == REPLACE;
// assign rd_type = 3'b100;
// assign rd_addr = {reg_tag,reg_index,4'b0};

// reg wr_req_reg;
// always @(posedge clk) begin
//     if(~resetn) begin
//         wr_req_reg <= 1'b0;
//     end else if(curr_state == MISS & next_state == REPLACE) begin
//         wr_req_reg <= 1'b1;
//     end else if(wr_rdy) begin
//         wr_req_reg <= 1'b0;
//     end
// end
// assign wr_req  = wr_req_reg & replace_v & replace_d;
// assign wr_type = 3'b100;
// assign wr_addr = replace_way ? {tagv_rdata[1][19:0],reg_index,4'b0} : {tagv_rdata[0][19:0],reg_index,4'b0};
// assign wr_wstrb= 4'b1111;
// assign wr_data = replace_data;
// endmodule
module cache(
	input 		clk,
	input 		resetn,

	input		valid,
	input		op,
	input	[7:0] 	index,
	input 	[19:0] 	tag,
	input 	[3:0] 	offset,
	input 	[3:0] 	wstrb,
	input 	[31:0] 	wdata,

	output		addr_ok,
	output 		data_ok,
	output 	[31:0] 	rdata,

	output 		rd_req,
	output 	[2:0]	rd_type,
	output 	[31:0]	rd_addr,
	input  		rd_rdy,
	input  		ret_valid,
	input  		ret_last,
	input 	[31:0]	ret_data,

	output 		wr_req,
	output 	[2:0]	wr_type,
	output 	[31:0]	wr_addr,
	output 	[3:0]	wr_wstrb,
	output 	[127:0]	wr_data,
	input  		wr_rdy
);
    	reg [255:0] dirty_way [1:0];
	// read ram: DATA_Bank_RAM RAM & TAGV RAM
	wire [7:0] addr;

	wire [31:0] store_data;

	wire tagv_en0, tagv0_we, tagv_en1, tagv1_we;
	wire [21:0] tagv_in0, tagv_in1;
	wire [20:0]tagv_way0, tagv_way1;

	wire [3:0] data_en0, data_en1;
	wire [3:0] data0_we [3:0], data1_we [3:0];
	wire [127:0] data_in0, data_in1;
	wire [127:0] data_out [1:0];

	
	wire [19:0]tag_way0, tag_way1;
	wire valid_way0, valid_way1;

	wire way0_hit, way1_hit, cache_hit, hit_write;
	wire write_conflict;
	
	wire [31:0] way0_load_word, way1_load_word, load_data_cache, load_data_mem;


	/* TAGV RAM & DATA RAM */
	TAG_RAM tagv_0(.clka(clk), .ena(tagv_en0), .wea(tagv0_we), .addra(addr), .dina(tagv_in0), .douta(tagv_way0));
	TAG_RAM tagv_1(.clka(clk), .ena(tagv_en1), .wea(tagv1_we), .addra(addr), .dina(tagv_in1), .douta(tagv_way1));

	DATA_Bank_RAM data_00(.clka(clk), .ena(data_en0[0]), .wea(data0_we[0]), .addra(addr), .dina(data_in0[31:0]), .douta(data_out[0][31:0]));
	DATA_Bank_RAM data_01(.clka(clk), .ena(data_en0[1]), .wea(data0_we[1]), .addra(addr), .dina(data_in0[63:32]), .douta(data_out[0][63:32]));
	DATA_Bank_RAM data_02(.clka(clk), .ena(data_en0[2]), .wea(data0_we[2]), .addra(addr), .dina(data_in0[95:64]), .douta(data_out[0][95:64]));
	DATA_Bank_RAM data_03(.clka(clk), .ena(data_en0[3]), .wea(data0_we[3]), .addra(addr), .dina(data_in0[127:96]), .douta(data_out[0][127:96]));
	DATA_Bank_RAM data_10(.clka(clk), .ena(data_en1[0]), .wea(data1_we[0]), .addra(addr), .dina(data_in1[31:0]), .douta(data_out[1][31:0]));
	DATA_Bank_RAM data_11(.clka(clk), .ena(data_en1[1]), .wea(data1_we[1]), .addra(addr), .dina(data_in1[63:32]), .douta(data_out[1][63:32]));
	DATA_Bank_RAM data_12(.clka(clk), .ena(data_en1[2]), .wea(data1_we[2]), .addra(addr), .dina(data_in1[95:64]), .douta(data_out[1][95:64]));
	DATA_Bank_RAM data_13(.clka(clk), .ena(data_en1[3]), .wea(data1_we[3]), .addra(addr), .dina(data_in1[127:96]), .douta(data_out[1][127:96]));


	/***** MAIN STATE MACHINE AND WRITE-BUFFER STATE MACHEINE *****/
	// parameter one-hot
	// IDLE, LOOKUP, MISS, REPLACE, REFILL
	localparam 	IDLE 	= 5'b00001,
			LOOKUP 	= 5'b00010,
			WRITE 	= 5'b00010,
			MISS 	= 5'b00100,
			REPLACE = 5'b01000,
			REFILL 	= 5'b10000;
	localparam 	WBUF_IDLE	= 2'b01,
			WBUF_WRITE	= 2'b10;

	reg [4:0] curr_state, next_state;
	reg [1:0] curr_state_wbuf, next_state_wbuf;

	always @(posedge clk or negedge resetn)
	begin
		if (!resetn)
			curr_state <= IDLE;
		else
			curr_state <= next_state;
	end
	always @(*)
	begin
		case (curr_state)
		IDLE:
		begin
			if(!valid || write_conflict)
				next_state = IDLE;
			else
				next_state = LOOKUP;
		end
		LOOKUP:
		begin
			if((cache_hit && (!valid || write_conflict)))
				next_state = IDLE;
			else if((cache_hit && (valid && ~write_conflict)))
				next_state = LOOKUP;
			else
				next_state = MISS;
		end
		MISS:
		begin
			if(!wr_rdy)
				next_state = MISS;
			else
				next_state = REPLACE;
		end
		REPLACE:
		begin
			if(!rd_rdy)
				next_state = REPLACE;
			else
				next_state = REFILL;
		end
		REFILL:
		begin
			if(ret_valid && ret_last)
				next_state = IDLE;
			else
				next_state = REFILL;
		end
		default:
			next_state = IDLE;
		endcase
	end


	always @(posedge clk or negedge resetn)
	begin
		if (!resetn)
			curr_state_wbuf <= WBUF_IDLE;
		else
			curr_state_wbuf <= next_state_wbuf;
	end
	always @(*)
	begin
		if(curr_state_wbuf == WBUF_IDLE)
		begin
			if(!hit_write)
				next_state_wbuf = WBUF_IDLE;
			else if(hit_write)
				next_state_wbuf = WBUF_WRITE;
			else
				next_state_wbuf = WBUF_IDLE;
		end
		else if(curr_state_wbuf == WBUF_WRITE)
		begin
			if(!hit_write)
				next_state_wbuf = WBUF_IDLE;
			else
				next_state_wbuf = WBUF_WRITE;
		end
		else
			next_state_wbuf = WBUF_IDLE;
	end


	/***** Request Buffer *****/
	reg [19:0] tag_reg;
	reg [3:0]  offset_reg;
	reg [3:0]  wstrb_reg;
	reg [31:0] wdata_reg;
	reg [7:0]  index_reg;
	reg op_reg;
	always @(posedge clk)
	begin
		if(((valid || !write_conflict) && curr_state == IDLE) ||
		   ((cache_hit && !write_conflict) && curr_state == LOOKUP))
		begin
			tag_reg <= tag;
			offset_reg <= offset;
			wstrb_reg <= wstrb;
			wdata_reg <= wdata;
			index_reg <= index;
			op_reg <= op;

		end
		else
		begin
			tag_reg <= tag_reg;
			offset_reg <= offset_reg;
			wstrb_reg <= wstrb_reg;
			wdata_reg <= wdata_reg;
			index_reg <= index_reg;
			op_reg <= op_reg;
		end
	end

	/***** Write Buffer *****/
	reg [19:0] tag_wbuf;
	reg [3:0]  offset_wbuf;
	reg [3:0]  wstrb_wbuf;
	reg [31:0] wdata_wbuf;
	reg [7:0]  index_wbuf;
	reg op_wbuf;
	reg hit_wbuf;
	always @(posedge clk)
	begin
		if(hit_write)
		begin
			tag_wbuf <= tag_reg;
			offset_wbuf <= offset_reg;
			wstrb_wbuf <= wstrb_reg;
			wdata_wbuf <= wdata_reg;
			index_wbuf <= index_reg;
			op_wbuf <= op_reg;
			hit_wbuf <= way1_hit ? 1'b1 : 1'b0;
		end
		else
		begin
			tag_wbuf <= tag_wbuf;
			offset_wbuf <= offset_wbuf;
			wstrb_wbuf <= wstrb_wbuf;
			wdata_wbuf <= wdata_wbuf;
			index_wbuf <= index_wbuf;
			op_wbuf <= op_wbuf;
			hit_wbuf <= hit_wbuf;
		end
	end
	

	/***** Miss Buffer *****/
	reg [19:0] tag_miss;
	always @(posedge clk)
	begin
		if(curr_state == MISS && wr_rdy)
		begin
			tag_miss <= replace_way ? tagv_way1[20:1] : tagv_way0[20:1];
		end
	end
	reg [2:0] ret_cnt;
	always @(posedge clk)
	begin
		if(curr_state == REPLACE && rd_rdy)
			ret_cnt <= 3'b000;
		else if(curr_state == REFILL && ret_valid)
			ret_cnt <= ret_cnt + 1;
		else
			ret_cnt <= ret_cnt;
	end

	/***** Dirty *****/
	always @(posedge clk)
	begin
		if(!resetn) //???
		begin
			dirty_way[0] = 256'b0;
			dirty_way[1] = 256'b0;
		end
		else if(curr_state_wbuf == WBUF_WRITE)
		begin
			if(hit_wbuf)
				dirty_way[1][index_wbuf] <= 1'b1;
			else
				dirty_way[0][index_wbuf] <= 1'b1;
		end
		else if(curr_state == REFILL && op_reg)
		begin
			if(replace_way)
				dirty_way[1][index_reg] <= 1'b1;
			else
				dirty_way[0][index_reg] <= 1'b1;
		end
		else if(curr_state == REFILL && ~op_reg)
		begin
			if(replace_way)
				dirty_way[1][index_reg] <= 1'b0;
			else
				dirty_way[0][index_reg] <= 1'b0;
		end
		else
		begin
			dirty_way[0] <= dirty_way[0];
			dirty_way[1] <= dirty_way[1];
		end
	end


	/***** WRITE_REQUEST_REG *****/
	reg we_req_reg;
	always @(posedge clk)
	begin
		if(!resetn)
			we_req_reg <= 1'b0;
		else if(curr_state == MISS & wr_rdy & dirty_way[replace_way][addr])
			we_req_reg <= 1'b1;
		else
			we_req_reg <= 1'b0;
	end

	/***** LSFR *****/
	reg [7:0]lsfr;
	always @(posedge clk)
	begin
		if(!resetn)
			lsfr <= 8'b10011100;
		else if(curr_state == REFILL && ret_valid && ret_last)
			lsfr <= {lsfr[6:0], lsfr[7] ^ lsfr[5] ^ lsfr[4] ^ lsfr[3]};
	end
	assign replace_way = lsfr[0];


	/***** Input for TAGV RAM & DATA RAM *****/
	assign addr = 	({8{(curr_state[0] || curr_state[1])}} & index) |
			({8{(curr_state[2] || curr_state[3] || curr_state[4])}} & index_reg);

	assign tagv_en0 = ~((curr_state == REFILL) & replace_way);
	assign tagv0_we = (curr_state == REFILL) && ret_valid && ret_last && ~replace_way;
	assign tagv_in0 = {tag_reg, 1'b1};

	assign tagv_en1 = ~((curr_state == REFILL) & ~replace_way);
	assign tagv1_we = (curr_state == REFILL) && ret_valid && ret_last && replace_way;
	assign tagv_in1 = {tag_reg, 1'b1};


	assign data_en0 = {4{~((curr_state == REFILL) & replace_way)}};
	genvar i;
	generate
		for(i = 0; i < 4; i = i + 1)
		begin
			assign data0_we[i] = {4{(curr_state == REFILL) && ret_valid && (ret_cnt == i)}} |
					(wstrb_wbuf & {4{(curr_state_wbuf == WBUF_WRITE) && (offset_wbuf[3:2] == i) && ~hit_wbuf}});
		end
	endgenerate
	assign data_in0 = {4{store_data & {32{curr_state_wbuf == WBUF_IDLE}}}} |
			 {4{wdata_wbuf & {32{curr_state_wbuf == WBUF_WRITE}}}};

	assign data_en1 = {4{~((curr_state == REFILL) & ~replace_way)}};
	generate
		for(i = 0; i < 4; i = i + 1)
		begin
			assign data1_we[i] = {4{(curr_state == REFILL) && ret_valid && (ret_cnt == i)}} |
					(wstrb_wbuf & {4{(curr_state_wbuf == WBUF_WRITE) && (offset_wbuf[3:2] == i) && hit_wbuf}}); 
		end
	endgenerate
	assign data_in1 = {4{store_data & {32{curr_state_wbuf == WBUF_IDLE}}}} |
			 {4{wdata_wbuf & {32{curr_state_wbuf == WBUF_WRITE}}}};

	assign store_data = 	(ret_cnt != offset_reg[3:2]) ? ret_data: 
				{wstrb_reg[3]? wdata_reg[31:24]: ret_data[31:24], 
				 wstrb_reg[2]? wdata_reg[23:16]: ret_data[23:16],
				 wstrb_reg[1]? wdata_reg[15:8]: ret_data[15:8],
				 wstrb_reg[0]? wdata_reg[7:0]: ret_data[7:0]};



	assign tag_way0 = tagv_way0[20:1];
	assign tag_way1 = tagv_way1[20:1];
	assign valid_way0 = tagv_way0[0];
	assign valid_way1 = tagv_way1[0];

	assign way0_hit = (tag_reg == tag_way0) && valid_way0 && curr_state == LOOKUP;
	assign way1_hit = (tag_reg == tag_way1) && valid_way1 && curr_state == LOOKUP;
	assign cache_hit = way0_hit || way1_hit;
	assign hit_write = cache_hit && op_reg;

	assign write_conflict = ((valid && ~op) && hit_write && (offset_reg[3:2] == offset[3:2]) && (curr_state == LOOKUP))
				|| (valid && ~op) && (offset_wbuf[3:2] == offset[3:2]) && (curr_state_wbuf == WBUF_WRITE);

	assign addr_ok = (curr_state == IDLE) || ((curr_state == LOOKUP) && cache_hit && valid && (op || (~op && ~write_conflict)));
	assign data_ok = ((curr_state == LOOKUP) && cache_hit) 
			|| ((curr_state == LOOKUP) && op_reg)
			|| ((curr_state == REFILL) && ret_valid && (ret_cnt == offset_reg[3:2]) && ~op_reg);

	assign way0_load_word = data_out[0][offset_reg[3:2] * 32 +: 32];
	assign way1_load_word = data_out[1][offset_reg[3:2] * 32 +: 32];
	assign load_data_cache = way0_hit ? way0_load_word : way1_load_word;
	assign load_data_mem = ret_data;
	assign rdata = ((curr_state == LOOKUP) && cache_hit) ? load_data_cache : load_data_mem;


	assign wr_req = we_req_reg;
	assign wr_type = 3'b100;
	assign wr_addr = {tag_miss, index_reg, 4'b0};
	assign wr_wstrb = 4'b1111;
	assign wr_data = data_out[replace_way];

	assign rd_req = curr_state == REPLACE;
	assign rd_type = 3'b100;
	assign rd_addr = {tag_reg, index_reg, 4'b0};

endmodule
