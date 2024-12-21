`include "mycpu_head.vh"

module AXI_bridge(
	input  wire        aclk,
	input  wire        aresetn,
	// read request interface
	output reg  [ 3:0] arid   ,
	output reg  [31:0] araddr ,
	output reg  [ 7:0] arlen  ,
	output reg  [ 2:0] arsize ,
	output reg  [ 1:0] arburst,
	output reg  [ 1:0] arlock ,
	output reg  [ 3:0] arcache,
	output reg  [ 2:0] arprot ,
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
	output reg  [ 3:0] awid   ,
	output reg  [31:0] awaddr ,
	output reg  [ 7:0] awlen  ,
	output reg  [ 2:0] awsize ,
	output reg  [ 1:0] awburst,
	output reg  [ 1:0] awlock ,
	output reg  [ 3:0] awcache,
	output reg  [ 2:0] awprot ,
	output wire        awvalid,
	input  wire        awready,
	// write data interface
	output reg  [ 3:0] wid    ,
	output      [31:0] wdata  ,
	output reg  [ 3:0] wstrb  ,
	output 	           wlast  ,
	output wire        wvalid ,
	input  wire        wready ,
	// write response interface
	input  wire [ 3:0] bid    ,
	input  wire [ 1:0] bresp  ,
	input  wire        bvalid ,
	output wire        bready ,

	// inst cache interface
	input  wire        icache_rd_req,
	input  wire [ 2:0] icache_rd_type,
	input  wire [31:0] icache_rd_addr,
	output wire        icache_rd_rdy,
	output reg         icache_ret_valid,
	output wire        icache_ret_last,
	output wire [31:0] icache_ret_data,


	// data cache interface
	input  wire        dcache_rd_req,
	input  wire [ 2:0] dcache_rd_type,
	input  wire [31:0] dcache_rd_addr,
	output wire        dcache_rd_rdy,
	output wire        dcache_ret_valid,
	output wire        dcache_ret_last,
	output wire [31:0] dcache_ret_data,

	input  wire        dcache_wr_req,
	input  wire [ 2:0] dcache_wr_type,
	input  wire [31:0] dcache_wr_addr,
	input  wire [3:0]  dcache_wr_wstrb,
	input  wire [127:0]dcache_wr_data,
	output wire        dcache_wr_rdy

	/* data sram interface
	input  wire        data_sram_req,
	input  wire [ 1:0] data_sram_size,
	input  wire        data_sram_wr,
	input  wire [ 3:0] data_sram_wstrb,
	input  wire [31:0] data_sram_addr,
	input  wire [31:0] data_sram_wdata,
	output wire        data_sram_addr_ok,
	output wire        data_sram_data_ok,
	output wire [31:0] data_sram_rdata
	*/
);
    //read request state machine
    reg  [ 2:0] ar_current_state;
    reg  [ 2:0] ar_next_state;
    wire        state_ar_idle;
    wire        state_ar_req;
    wire        state_ar_ack;

    //read data state machine
    reg  [ 2:0] r_current_state;
    reg  [ 2:0] r_next_state;
    wire        state_r_idle;
    wire        state_r_rdy;
    wire        state_r_ack;
    reg  [ 3:0] rid_reg;

    reg  [31:0] rdata_buffer [15:0];
    reg  [ 3:0] read_wait_counter;

    //write request state machine
    reg  [ 4:0] w_current_state;
    reg  [ 4:0] w_next_state;
    wire        state_w_idle;
    wire        state_w_req;
    wire        state_w_addr;
    wire        state_w_data;
    wire        state_w_ack;

    //write data state machine
    reg  [ 2:0] b_current_state;
    reg  [ 2:0] b_next_state;
    wire        state_b_idle;
    wire        state_b_req;
    wire        state_b_ack;
    reg  [ 3:0] write_addr_wait_counter;
    reg  [ 3:0] write_data_wait_counter;
    wire        data_conflict;

    wire areset = !aresetn;
//************************************************************
    //read request
    always @(posedge aclk) begin
        if (areset) 
            ar_current_state <= `STATE_IDLE;
        else
            ar_current_state <= ar_next_state;
    end

    always @(*) begin
        case (ar_current_state)
            `STATE_IDLE: begin
                if (areset | data_conflict)
                    ar_next_state = `STATE_IDLE;
                // else if ((icache_rd_req | data_sram_req & ~data_sram_wr) & ~(read_wait_counter[0]))
                else if ((icache_rd_req | dcache_rd_req) & ~(read_wait_counter[0]))
                    ar_next_state = `STATE_AR_REQ;
                else
                    ar_next_state = `STATE_IDLE;
            end

            `STATE_AR_REQ: begin
                if (arvalid & arready)
                    ar_next_state = `STATE_AR_ACK;
                else 
                    ar_next_state = `STATE_AR_REQ;
            end

            `STATE_AR_ACK: begin
                ar_next_state = `STATE_IDLE;
            end

            default : ar_next_state = `STATE_IDLE;
        endcase
    end

    assign {state_ar_ack, state_ar_req, state_ar_idle} = ar_current_state;
    
    assign arvalid      = state_ar_req;
    always @(posedge aclk) begin
        if (areset) begin
            arid    <= 4'b0;
            araddr  <= 32'b0;
            arsize  <= 3'b010;
            {arlen, arburst, arlock, arcache, arprot} <=
                {8'b0, 2'b01, 2'b0, 4'b0, 3'b0};
        end
        else if (state_ar_idle) begin
            // if (data_sram_req & ~data_sram_wr) begin
            if (dcache_rd_req) begin
                arid    <= 4'b1;
                // araddr  <= data_sram_addr;
                // arsize  <= {1'b0, data_sram_size};
                // arlen   <= 8'b0;
                araddr  <= dcache_rd_addr;
                arsize  <= 3'b010;
                arlen   <= {6'b0, {2{dcache_rd_type[2]}}};
            end
            else if (icache_rd_req) begin
                arid    <= 4'b0;
                araddr  <= icache_rd_addr;
                arsize  <= 3'b010;
                arlen   <= {6'b0, {2{icache_rd_type[2]}}};
            end
        end
    end

//************************************************************
    //read response
    always @(posedge aclk) begin
        if (areset)
            r_current_state <= `STATE_IDLE;
        else
            r_current_state <= r_next_state;
    end

    always @(*) begin
        case (r_current_state)
            `STATE_IDLE: begin
                if (areset)
                    r_next_state = `STATE_IDLE;
                else if (arvalid & arready | (|read_wait_counter))
                    r_next_state = `STATE_R_RDY;
                else
                    r_next_state = `STATE_IDLE;
            end

            `STATE_R_RDY: begin
                if (rvalid & rready & rlast)
                    r_next_state = `STATE_R_ACK;
                else
                    r_next_state = `STATE_R_RDY;
            end

            `STATE_R_ACK: begin
                r_next_state = `STATE_IDLE;
            end

            default : r_next_state = `STATE_IDLE;
        endcase
    end

    assign {state_r_ack, state_r_rdy, state_r_idle} = r_current_state;

    assign rready = state_r_rdy;
    always @(posedge aclk) begin
        if (areset) 
            read_wait_counter <= 4'b0;
        else if (arready & arvalid & rready & rvalid & rlast)
            read_wait_counter <= read_wait_counter;
        else if (arready & arvalid)
            read_wait_counter <= read_wait_counter + 1'b1;
        else if (rready & rvalid & rlast)
            read_wait_counter <= read_wait_counter - 1'b1;
    end
    
    always @(posedge aclk) begin
        if (areset)
            {rdata_buffer[15], rdata_buffer[14], rdata_buffer[13], rdata_buffer[12],
            rdata_buffer[11], rdata_buffer[10], rdata_buffer[9], rdata_buffer[8],
            rdata_buffer[7], rdata_buffer[6], rdata_buffer[5], rdata_buffer[4],
            rdata_buffer[3], rdata_buffer[2], rdata_buffer[1], rdata_buffer[0]} <=
            {16{32'b0}};
        else if (rready & rvalid)
            rdata_buffer[rid] <= rdata;
    end

    always @(posedge aclk) begin
        if (areset)
            rid_reg <= 4'b0;
        else if (rready & rvalid)
            rid_reg <= rid;
    end

//************************************************************
    //write request & write data
    always @(posedge aclk) begin
        if (areset)
            w_current_state <= `STATE_IDLE;
        else
            w_current_state <= w_next_state;
    end

    always @(*) begin
        case (w_current_state)
            `STATE_IDLE: begin
                if (areset)
                    w_next_state = `STATE_IDLE;
                // else if (data_sram_req & data_sram_wr)
                else if (dcache_wr_req)
                    w_next_state = `STATE_W_REQ;
                else
                    w_next_state = `STATE_IDLE;
            end

            `STATE_W_REQ: begin
                // if (awvalid & awready & wvalid & wready)
                //     w_next_state = `STATE_W_ACK;
                // else if (awvalid & awready)
                //     w_next_state = `STATE_W_ADDR;
                // else if (wvalid & wready)
                //     w_next_state = `STATE_W_DATA;
                if (awvalid & awready)
                    w_next_state = `STATE_W_DATA;
                else
                    w_next_state = `STATE_W_REQ;
            end

            // `STATE_W_ADDR: begin
            //     if (wvalid & wready)
            //         w_next_state = `STATE_W_ACK;
            //     else
            //         w_next_state = `STATE_W_ADDR;
            // end

            `STATE_W_DATA: begin
                // if (awvalid & awready)
                if (wvalid & wready & wlast)
                    w_next_state = `STATE_W_ACK;
                else
                    w_next_state = `STATE_W_DATA;
            end

            `STATE_W_ACK: begin
                if (bvalid & bready)
                    w_next_state = `STATE_IDLE;
                else
                    w_next_state = `STATE_W_ACK;
            end
        endcase
    end

    assign {state_w_ack, state_w_data, state_w_addr, state_w_req, state_w_idle} = w_current_state;

    // assign awvalid = state_w_req | state_w_data;
    // assign wvalid  = state_w_req | state_w_addr;
    assign awvalid = state_w_req;
    assign wvalid  = state_w_data;

    always @(posedge aclk) begin
        if (areset) begin
            awaddr <= 32'b0;
            awsize <= 3'b0;
            {awid, awlen, awburst, awlock, awcache, awprot} <=
            {4'b1, 8'b0, 2'b01, 2'b0, 4'b0, 3'b0};
        end
        else if (state_w_idle & dcache_wr_req) begin
            // if (data_sram_req & data_sram_wr) begin
            //     awaddr <= data_sram_addr;
            //     awsize <= {1'b0, data_sram_size};
            awaddr <= dcache_wr_addr;
            awsize <= 3'b010;
		    awlen  <= {6'b0, {2{dcache_wr_type[2]}}};
        end
    end

    // always @(posedge aclk) begin
    //     if (areset) begin
    //         wdata <= 32'b0;
    //         wstrb <= 4'b0;
    //         {wid, wlast} <= {4'b1, 1'b1};
    //     end
    //     else if (state_w_idle) begin
    //         if (data_sram_req & data_sram_wr) begin
    //            wdata <= data_sram_wdata;
    //            wstrb <= data_sram_wstrb;
    //         end
    //     end
    // end
    reg [31:0] wdata_buffer [3:0];
	reg [7:0]  wlen;
    always @(posedge aclk) begin
        if (areset) begin
            {wdata_buffer[3],wdata_buffer[2],wdata_buffer[1],wdata_buffer[0]} <= 128'b0;
            wstrb <= 4'b0;
            wid <= 4'b1;
        end
        else if (state_w_idle & dcache_wr_req) begin
            {wdata_buffer[3],wdata_buffer[2],wdata_buffer[1],wdata_buffer[0]} <= dcache_wr_data;
            wstrb <= dcache_wr_wstrb;
        end
    end

    always @(posedge aclk) begin
	if(areset)
	    wlen <= 8'b0;
	else if(state_w_idle & dcache_wr_req)
		wlen <= {6'b0, {2{dcache_wr_type[2]}}};
	else if(state_w_data & wvalid & wready)
		wlen <= wlen - 1'b1;
    end

    assign wlast = ~|wlen[1:0];
    assign wdata = wdata_buffer[~wlen[1:0]];

//************************************************************
    //write response
    always @(posedge aclk) begin
        if (areset) 
            b_current_state <= `STATE_IDLE;
        else 
            b_current_state <= b_next_state;
    end

    always @(*) begin
        case (b_current_state)
            `STATE_IDLE: begin
                if (areset)
                    b_next_state = `STATE_IDLE;
                else if (bready)
                    b_next_state = `STATE_B_REQ;
                else
                    b_next_state = `STATE_IDLE;
            end

            `STATE_B_REQ: begin
                if (bready & bvalid)
                    b_next_state = `STATE_B_ACK;
                else
                    b_next_state = `STATE_B_REQ;
            end

            `STATE_B_ACK: begin
                b_next_state = `STATE_IDLE;
            end

            default: b_next_state = `STATE_IDLE;
        endcase 
    end

    assign {state_b_ack, state_b_req, state_b_idle} = b_current_state;

    assign bready = state_w_ack;
    assign data_conflict = (araddr == awaddr) & (~state_w_idle) & ~state_b_ack;

    // always @(posedge aclk) begin
    //     if (areset)
    //         write_addr_wait_counter <= 4'b0;
    //     else if (awvalid & awready)
    //         write_addr_wait_counter <= write_addr_wait_counter + 4'b1;
    //     else if (bvalid & bready)
    //         write_addr_wait_counter <= write_addr_wait_counter - 4'b1;
    // end

    // always @(posedge aclk) begin
    //     if (areset)
    //         write_data_wait_counter <= 4'b0;
    //     else if (wvalid & wready)
    //         write_data_wait_counter <= write_data_wait_counter + 4'b1;
    //     else if (bvalid & bready)
    //         write_data_wait_counter <= write_data_wait_counter - 4'b1;
    // end

//************************************************************
    //interface
    assign icache_ret_data   = rdata_buffer[0];
    assign icache_rd_rdy     = state_ar_idle & ~dcache_rd_req & ~(read_wait_counter[0]) & ~data_conflict;
    assign icache_ret_last   = state_r_ack & ~rid_reg[0];
    always @(posedge aclk) begin
        if (areset)
            icache_ret_valid <= 1'b0;
        else if (~rid[0] & rvalid & rready)
            icache_ret_valid <= 1'b1;
        else if (icache_ret_valid)
            icache_ret_valid <= 1'b0;
    end

    // assign data_sram_rdata   = rdata_buffer[1];
    // assign data_sram_addr_ok = arid[0] & arvalid & arready | wid[0] & awvalid & awready;
    // assign data_sram_data_ok = rid_reg[0] & state_r_ack | bid[0] & bvalid & bready;
	assign dcache_rd_rdy = state_ar_idle & ~(read_wait_counter[0]) & ~data_conflict;
	assign dcache_ret_data = rid ? rdata : 32'b0;
	assign dcache_ret_last = rid[0] & rlast & rvalid & rready;
	assign dcache_ret_valid = rid[0] & rvalid & rready;
	assign dcache_wr_rdy = state_w_idle;

endmodule