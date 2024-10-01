module div(
    input  wire    div_clk,
    input  wire    resetn,
    input  wire    div,
    input  wire    div_signed,
    input  wire [31:0] x,  
    input  wire [31:0] y,   
    output wire [31:0] s,   
    output wire [31:0] r,   
    output wire    complete 
);

    wire        sign_s;
    wire        sign_r;
    wire [31:0] abs_x;
    wire [31:0] abs_y;
    wire [32:0] pre_r;
    wire [32:0] recover_r;
    reg  [63:0] x_pad;
    reg  [32:0] y_pad;
    reg  [31:0] quotient;
    reg  [32:0] remainder;
    reg  [ 5:0] counter;

    assign sign_s = (x[31]^y[31]) & div_signed;
    assign sign_r = x[31] & div_signed;
    assign abs_x  = (div_signed & x[31]) ? (~x+1'b1): x;
    assign abs_y  = (div_signed & y[31]) ? (~y+1'b1): y;

    assign complete = counter == 6'd33;
    always @(posedge div_clk) begin
        if(~resetn) begin
            counter <= 6'b0;
        end
        else if(div) begin
            if(complete)
                counter <= 6'b0;
            else
                counter <= counter + 1'b1;
        end
    end

    always @(posedge div_clk) begin
        if(~resetn)
            {x_pad, y_pad} <= {64'b0, 33'b0};
        else if(div) begin
            if(~|counter)
                {x_pad, y_pad} <= {32'b0, abs_x, 1'b0, abs_y};
        end
    end

    assign pre_r = remainder - y_pad;                     
    assign recover_r = pre_r[32] ? remainder : pre_r;     
    always @(posedge div_clk) begin
        if(~resetn) 
            quotient <= 32'b0;
        else if(div & ~complete & |counter) begin
            quotient[32-counter] <= ~pre_r[32];
        end
    end
    always @(posedge div_clk) begin
        if(~resetn)
            remainder <= 33'b0;
        if(div & ~complete) begin
            if(~|counter)   
                remainder <= {32'b0, abs_x[31]};
            else
                remainder <=  (counter == 32) ? recover_r : {recover_r, x_pad[31 - counter]};
        end
    end

    assign s = (x[31]^y[31]) & div_signed ? (~quotient+1'b1) : quotient;
    assign r = x[31] & div_signed ? (~remainder+1'b1) : remainder;
endmodule