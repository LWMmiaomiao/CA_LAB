module cache(
	input 		clk,
	input 		resetn,

	input 		cachable,

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
	input  		wr_rdy,

	input       cacop,
    input  wire sto_tag,
    input  wire idx_inv,
    input  wire hit_inv,
    output wire cacop_ok

);
    	reg [255:0] dirty_way [1:0];
	// read ram: DATA_Bank_RAM RAM & TAGV RAM
	wire [7:0] addr;

	wire [31:0] store_data;

	wire tagv_en0, tagv0_we, tagv_en1, tagv1_we;
	wire [20:0] tagv_in0, tagv_in1;
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

	// request buffer
	reg [19:0] tag_reg;
	reg [3:0]  offset_reg;
	reg [3:0]  wstrb_reg;
	reg [31:0] wdata_reg;
	reg [7:0]  index_reg;
	reg op_reg;
	reg cachable_reg;

	// write buffer
	reg [19:0] tag_wbuf;
	reg [3:0]  offset_wbuf;
	reg [3:0]  wstrb_wbuf;
	reg [31:0] wdata_wbuf;
	reg [7:0]  index_wbuf;
	reg op_wbuf;
	reg hit_wbuf;

	// miss buffer
	reg [19:0] tag_miss;

	// always @(posedge clk) begin
	// 	if ((tagv0_we && !tagv_en0) || (tagv1_we && !tagv_en1)) begin
	// 		$display("tagv0_we: %b, tagv_en0: %b, tagv1_we: %b, tagv_en1: %b", tagv0_we, tagv_en0, tagv1_we, tagv_en1);
	// 		$display("tagv_we error");
	// 		$stop;
	// 	end
	// end


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
	reg cacop_cycle;

	always @(posedge clk or negedge resetn)
	begin
		if (!resetn)
			curr_state <= IDLE;
		else
			curr_state <= next_state;
	end
	always @(posedge clk or negedge resetn) begin
		if (!resetn)
			cacop_cycle <= 1'b0;
		else if (curr_state == IDLE && cacop && curr_state_wbuf == WBUF_IDLE)
			cacop_cycle <= 1'b1;
		else if (cacop_cycle && next_state == IDLE)
			cacop_cycle <= 1'b0;
		else
			cacop_cycle <= cacop_cycle;	
	end

	always @(*)
	begin
		case (curr_state)
		IDLE:
		begin
			if(write_conflict || (cacop && curr_state_wbuf != WBUF_IDLE))
				next_state = IDLE;
			else if (valid)
				next_state = LOOKUP;
			else if (cacop && idx_inv)
				next_state = MISS;
			else if (cacop && hit_inv)
				next_state = LOOKUP;
			else if (cacop && sto_tag)
				next_state = LOOKUP;
			else if (!valid)
				next_state = IDLE;
			else
				next_state = LOOKUP;
		end
		LOOKUP:
		begin
			// if (cacop) begin
			// 	if (cacop_cycle) begin
			// 		if (hit_inv && cache_hit)
			// 			next_state = MISS;
			// 		else if (hit_inv && ~cache_hit)
			// 			next_state = IDLE;
			// 		else
			// 			next_state = IDLE;
			// 	end
			// 	else
			// 		next_state = IDLE;
			// end
			// else
			if (!cacop_cycle) begin
				if((cache_hit && (!valid || write_conflict)))
					next_state = IDLE;
				else if((cache_hit && (valid && ~write_conflict)))
					next_state = LOOKUP;
				else
					next_state = MISS;
			end
			else begin
				if (hit_inv && cache_hit)
					next_state = MISS;
				else if (hit_inv && ~cache_hit)
					next_state = IDLE;
				else
					next_state = IDLE;
			end
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
			if (cacop_cycle && (idx_inv || hit_inv))
				next_state = IDLE;
			else if(!rd_rdy)
				next_state = REPLACE;
			else
				next_state = REFILL;
		end
		REFILL:
		begin
			if(ret_valid && ret_last || (~cachable_reg & op_reg))
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
	always @(posedge clk)
	begin
		if(((valid || !write_conflict || cacop) && curr_state == IDLE) ||
		   ((cache_hit && !write_conflict) && curr_state == LOOKUP))
		begin
			tag_reg <= tag;
			offset_reg <= offset;
			wstrb_reg <= wstrb;
			wdata_reg <= wdata;
			index_reg <= index;
			op_reg <= op;
			cachable_reg <= (cacop ? 1 : cachable);
		end
		else
		begin
			tag_reg <= tag_reg;
			offset_reg <= offset_reg;
			wstrb_reg <= wstrb_reg;
			wdata_reg <= wdata_reg;
			index_reg <= index_reg;
			op_reg <= op_reg;
			cachable_reg <= cachable_reg;
		end
	end

	/***** Write Buffer *****/
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
	
	reg replace_way;
	/***** Miss Buffer *****/
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
		else if(curr_state == REPLACE && cacop_cycle && cacop && (idx_inv || hit_inv)) begin
			dirty_way[replace_way][index_reg] <= 1'b0;
		end
		else if (cacop_cycle && (tagv1_we || tagv0_we)) begin
			dirty_way[tagv1_we][index_reg] <= 1'b0;
		end
		else if(curr_state_wbuf == WBUF_WRITE)
		begin
			if(hit_wbuf)
				dirty_way[1][index_wbuf] <= 1'b1;
			else
				dirty_way[0][index_wbuf] <= 1'b1;
		end
		else if(curr_state == REFILL && op_reg && cachable_reg)
		begin
			if(replace_way)
				dirty_way[1][index_reg] <= 1'b1;
			else
				dirty_way[0][index_reg] <= 1'b1;
		end
		else if(curr_state == REFILL && ~op_reg && cachable_reg)
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
		else if(curr_state == MISS & wr_rdy & (dirty_way[replace_way][addr] | (~cachable_reg & op_reg)))
			we_req_reg <= 1'b1;
		else
			we_req_reg <= 1'b0;
	end

	/***** LSFR *****/
	reg [7:0]lsfr;
	always @(posedge clk)
	begin
		if(!resetn) begin
			lsfr <= 8'b10011100;
			replace_way <= 0;
		end
		else if (curr_state == IDLE && cacop && !valid && (sto_tag || idx_inv)) begin
			replace_way <= offset[0];
		end
		else if (curr_state == LOOKUP && cacop_cycle) begin
			replace_way <= way0_hit ? 0 : 1;
		end
		else if(curr_state == REFILL && ret_valid && ret_last) begin
			replace_way <= lsfr[0];
			lsfr <= {lsfr[6:0], lsfr[7] ^ lsfr[5] ^ lsfr[4] ^ lsfr[3]};
		end
	end
	// assign replace_way = lsfr[0];


	/***** Input for TAGV RAM & DATA RAM *****/
	assign addr = 	({8{(curr_state[0] || curr_state[1])}} & index) |
			({8{(curr_state[2] || curr_state[3] || curr_state[4])}} & index_reg);

	assign tagv_en0 = ~((curr_state == REFILL) & (replace_way | ~cachable_reg));
    // assign tagv_en0 = 1'b1;
	// assign tagv_en0 = ~(((curr_state == REFILL) & (replace_way | ~cachable_reg)) ||
	// 				    ((curr_state == REPLACE) && cacop && (idx_inv || hit_inv) && wr_req && wr_rdy) ||
	// 					(curr_state == LOOKUP && cacop && sto_tag));
	assign tagv0_we = (((curr_state == REFILL) && ret_valid && ret_last) ||
					   ((curr_state == REPLACE) && cacop_cycle && (idx_inv || hit_inv)) ||
					   (curr_state == LOOKUP && cacop_cycle && sto_tag)
					  ) && ~replace_way;
	assign tagv_in0 = (cacop_cycle && (idx_inv || hit_inv))? 21'b0 : {tag_reg, 1'b1};

	// assign tagv_en1 = ~(((curr_state == REFILL) & (~replace_way | ~cachable_reg)) ||
	// 				    ((curr_state == REPLACE) && cacop && (idx_inv || hit_inv) && wr_req && wr_rdy) ||
	// 					(curr_state == LOOKUP && cacop && sto_tag));
	assign tagv_en1 = ~((curr_state == REFILL) & (~replace_way | ~cachable_reg));
	// assign tagv_en1 = 1'b1;
	assign tagv1_we = (((curr_state == REFILL) && ret_valid && ret_last) ||
					   ((curr_state == REPLACE) && cacop_cycle && (idx_inv || hit_inv)) ||
					   (curr_state == LOOKUP && cacop_cycle && sto_tag)
					  ) && replace_way;
	assign tagv_in1 = (cacop_cycle && (idx_inv || hit_inv))? 21'b0 : {tag_reg, 1'b1};


	assign data_en0 = {4{~((curr_state == REFILL) & (replace_way | ~cachable_reg))}};
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

	assign data_en1 = {4{~((curr_state == REFILL) & ~(replace_way | ~cachable_reg))}};
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

	assign way0_hit = (tag_reg == tag_way0) && valid_way0 && curr_state == LOOKUP && cachable_reg;
	assign way1_hit = (tag_reg == tag_way1) && valid_way1 && curr_state == LOOKUP && cachable_reg;
	assign cache_hit = way0_hit || way1_hit;
	assign hit_write = cache_hit && op_reg;

	assign write_conflict = ((valid && ~op) && hit_write && (offset_reg[3:2] == offset[3:2]) && (curr_state == LOOKUP))
				|| (valid && ~op) && (offset_wbuf[3:2] == offset[3:2]) && (curr_state_wbuf == WBUF_WRITE);

	assign addr_ok = (curr_state == IDLE && valid && !write_conflict) || (!cacop_cycle && !cacop && (curr_state == LOOKUP) && cache_hit && valid && (op || (~op && ~write_conflict)));
	assign data_ok = !cacop_cycle &&
		(
			((curr_state == LOOKUP) && cache_hit) 
			|| ((curr_state == LOOKUP) && op_reg)
			|| ((curr_state == REFILL) && ret_valid && (((ret_cnt == offset_reg[3:2]) & cachable_reg) | ~cachable_reg) && ~op_reg)
		);

	assign way0_load_word = data_out[0][offset_reg[3:2] * 32 +: 32];
	assign way1_load_word = data_out[1][offset_reg[3:2] * 32 +: 32];
	assign load_data_cache = way0_hit ? way0_load_word : way1_load_word;
	assign load_data_mem = ret_data;
	assign rdata = ((curr_state == LOOKUP) && cache_hit) ? load_data_cache : load_data_mem;


	assign wr_req = we_req_reg;
	assign wr_type = cachable_reg ? 3'b100 : 3'b010;
	assign wr_addr = cachable_reg ? {tag_miss, index_reg, 4'b0} : {tag_reg, index_reg, offset_reg};
	assign wr_wstrb = cachable_reg ? 4'b1111 : wstrb_reg;
	assign wr_data = cachable_reg ? data_out[replace_way] : {4{wdata_reg}};

	assign rd_req = (curr_state == REPLACE) & ~(~cachable_reg & op_reg);
	assign rd_type = cachable_reg ? 3'b100 : 3'b010;
	assign rd_addr = {tag_reg, index_reg, ((~cachable_reg & ~op_reg) ? offset_reg : 4'b0)};

	assign cacop_ok = (curr_state == REPLACE && next_state == IDLE && cacop_cycle && (idx_inv || hit_inv)) ||
					  (curr_state == LOOKUP && !cache_hit && cacop_cycle && hit_inv) ||
					  (curr_state == LOOKUP && cacop_cycle && sto_tag);

endmodule
