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
    reg [5:0] counter;
    always @(posedge div_clk) begin
        if (!resetn)
            counter <= 6'b0;
        else if(div) begin
            if (complete)
                counter <= 6'b0;
            else
                counter <= counter + 1'b1;
        end
    end
    assign complete = !resetn || counter[0] && counter[5];

    wire [31:0] x_abs;
    wire [31:0] y_abs;
    assign x_abs = div_signed && x[31] ? (~x + 1'b1) : x;
    assign y_abs = div_signed && y[31] ? (~y + 1'b1) : y;

    wire [63:0] dividend;
    wire [32:0] divisor;
    assign dividend = {32'b0, x_abs};// 64位被除数绝对值
    assign divisor  = {1'b0, y_abs};//  33位除数绝对值

    reg [31:0] quotient;
    reg [32:0] remainder;
    wire [32:0] dif_value;
    wire [32:0] recover_remainder;
    assign dif_value = remainder - divisor; // 每次迭代试除的差值
    assign recover_remainder = dif_value[32] ? remainder : dif_value;

    always @(posedge div_clk) begin
        if(!resetn || !div) 
            quotient <= 32'b0;
        else if(div & (|counter) & ~complete) begin // 第一次迭代开始时才设置quotient
            quotient[32-counter] <= !dif_value[32];
        end
    end

    always @(posedge div_clk) begin
        if(!resetn)
            remainder <= 33'b0;
        else if(div & !complete) begin
            if(~|counter)   //余数初始化
                remainder <= dividend[63:31]; // 第一次迭代，取A的高 33 位
            else
                remainder <= (counter[5]) ? recover_remainder : {recover_remainder[31:0], dividend[31 - counter]};// 直接更新余数
        end
    end

    assign s = (x[31] ^ y[31]) & div_signed ? (~quotient + 1'b1) : quotient;
    assign r = x[31] & div_signed ? (~remainder[31:0] + 1'b1) : remainder[31:0];

endmodule