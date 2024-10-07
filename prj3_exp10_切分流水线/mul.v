module mul_Wallace(
    input  wire        mul_clk,
    input  wire        resetn,
    input  wire        mul_signed,
    input  wire [31:0] x,
    input  wire [31:0] y,
    output wire [63:0] result
);
    wire [63:0] x_extend;
    wire [33:0] y_extend;// 32位有/无符号乘法均扩展为33位有符号乘法, 由Booth两位乘算法, 需扩展为34位
    assign x_extend = {{32{x[31] & mul_signed}}, x};
    assign y_extend = {{ 2{y[31] & mul_signed}}, y};

    wire [33:0] y_sl;
    wire [33:0] y_sr;
    assign y_sl = {y_extend[32:0], 1'b0};// y_extend左移, 得到y_{n+1} 
    assign y_sr = {1'b0, y_extend[33:1]};// y_extend右移, 得到y_{n-1} 

    wire [33:0] judgement [7:0];// y_{n-1} y_{n} y_{n+1} 
    assign judgement[0] = (~y_sr & ~y_extend & ~y_sl);// y_{n-1} y_{n} y_{n+1} = 000
    assign judgement[1] = (~y_sr & ~y_extend &  y_sl);// y_{n-1} y_{n} y_{n+1} = 001
    assign judgement[2] = (~y_sr &  y_extend & ~y_sl);// y_{n-1} y_{n} y_{n+1} = 010
    assign judgement[3] = (~y_sr &  y_extend &  y_sl);// y_{n-1} y_{n} y_{n+1} = 011
    assign judgement[4] = ( y_sr & ~y_extend & ~y_sl);// y_{n-1} y_{n} y_{n+1} = 100
    assign judgement[5] = ( y_sr & ~y_extend &  y_sl);// y_{n-1} y_{n} y_{n+1} = 101
    assign judgement[6] = ( y_sr &  y_extend & ~y_sl);// y_{n-1} y_{n} y_{n+1} = 110
    assign judgement[7] = ( y_sr &  y_extend &  y_sl);// y_{n-1} y_{n} y_{n+1} = 111

    wire [63:0] x_single_add;
    wire [63:0] x_double_add;
    wire [63:0] x_single_sub;
    wire [63:0] x_double_sub;
    assign x_single_add = {{32{x[31] & mul_signed}}, x};
    assign x_double_add = {x_single_add[62:0], 1'b0};
    assign x_single_sub = ~x_single_add + 1'b1;
    assign x_double_sub = ~x_double_add + 1'b1;

    //根据8种判断位共有5种操作
    // wire [16:0] choose_zero;
    wire [16:0] choose_single_add;
    wire [16:0] choose_double_add;
    wire [16:0] choose_single_sub;
    wire [16:0] choose_double_sub;
    // assign choose_zero       = {judgement[0][32] || judgement[7][32], judgement[0][30] || judgement[7][30], judgement[0][28] || judgement[7][28], judgement[0][26] || judgement[7][26], 
    //                             judgement[0][24] || judgement[7][24], judgement[0][22] || judgement[7][22], judgement[0][20] || judgement[7][20], judgement[0][18] || judgement[7][18], 
    //                             judgement[0][16] || judgement[7][16], judgement[0][14] || judgement[7][14], judgement[0][12] || judgement[7][12], judgement[0][10] || judgement[7][10], 
    //                             judgement[0][ 8] || judgement[7][ 8], judgement[0][ 6] || judgement[7][ 6], judgement[0][ 4] || judgement[7][ 4], judgement[0][ 2] || judgement[7][ 2], 
    //                             judgement[0][ 0] || judgement[7][ 0]};
    assign choose_single_add = {judgement[1][32] || judgement[2][32], judgement[1][30] || judgement[2][30], judgement[1][28] || judgement[2][28], judgement[1][26] || judgement[2][26], 
                                judgement[1][24] || judgement[2][24], judgement[1][22] || judgement[2][22], judgement[1][20] || judgement[2][20], judgement[1][18] || judgement[2][18], 
                                judgement[1][16] || judgement[2][16], judgement[1][14] || judgement[2][14], judgement[1][12] || judgement[2][12], judgement[1][10] || judgement[2][10], 
                                judgement[1][ 8] || judgement[2][ 8], judgement[1][ 6] || judgement[2][ 6], judgement[1][ 4] || judgement[2][ 4], judgement[1][ 2] || judgement[2][ 2], 
                                judgement[1][ 0] || judgement[2][ 0]};
    assign choose_double_add = {judgement[3][32], judgement[3][30], judgement[3][28], judgement[3][26], 
                                judgement[3][24], judgement[3][22], judgement[3][20], judgement[3][18], 
                                judgement[3][16], judgement[3][14], judgement[3][12], judgement[3][10], 
                                judgement[3][ 8], judgement[3][ 6], judgement[3][ 4], judgement[3][ 2], 
                                judgement[3][ 0]};
    assign choose_single_sub = {judgement[5][32] || judgement[6][32], judgement[5][30] || judgement[6][30], judgement[5][28] || judgement[6][28], judgement[5][26] || judgement[6][26], 
                                judgement[5][24] || judgement[6][24], judgement[5][22] || judgement[6][22], judgement[5][20] || judgement[6][20], judgement[5][18] || judgement[6][18], 
                                judgement[5][16] || judgement[6][16], judgement[5][14] || judgement[6][14], judgement[5][12] || judgement[6][12], judgement[5][10] || judgement[6][10], 
                                judgement[5][ 8] || judgement[6][ 8], judgement[5][ 6] || judgement[6][ 6], judgement[5][ 4] || judgement[6][ 4], judgement[5][ 2] || judgement[6][ 2], 
                                judgement[5][ 0] || judgement[6][ 0]};
    assign choose_double_sub = {judgement[4][32], judgement[4][30], judgement[4][28], judgement[4][26], 
                                judgement[4][24], judgement[4][22], judgement[4][20], judgement[4][18], 
                                judgement[4][16], judgement[4][14], judgement[4][12], judgement[4][10], 
                                judgement[4][ 8], judgement[4][ 6], judgement[4][ 4], judgement[4][ 2], 
                                judgement[4][ 0]};

    //产生17个64位的部分积
    wire [63:0] product [16:0];
    genvar i;
    generate
        for (i = 0; i < 17; i = i + 1) begin : part_product
            assign product[i] = {64{choose_single_add[i]}} & x_single_add | {64{choose_double_add[i]}} & x_double_add | {64{choose_single_sub[i]}} & x_single_sub | {64{choose_double_sub[i]}} & x_double_sub;
        end
    endgenerate
    // assign product[ 0] = {64{choose_single_add[ 0]}} & x_single_add | {64{choose_double_add[ 0]}} & x_double_add | {64{choose_single_sub[ 0]}} & x_single_sub | {64{choose_double_sub[ 0]}} & x_double_sub;
    // assign product[ 1] = {64{choose_single_add[ 1]}} & x_single_add | {64{choose_double_add[ 1]}} & x_double_add | {64{choose_single_sub[ 1]}} & x_single_sub | {64{choose_double_sub[ 1]}} & x_double_sub;
    // assign product[ 2] = {64{choose_single_add[ 2]}} & x_single_add | {64{choose_double_add[ 2]}} & x_double_add | {64{choose_single_sub[ 2]}} & x_single_sub | {64{choose_double_sub[ 2]}} & x_double_sub;
    // assign product[ 3] = {64{choose_single_add[ 3]}} & x_single_add | {64{choose_double_add[ 3]}} & x_double_add | {64{choose_single_sub[ 3]}} & x_single_sub | {64{choose_double_sub[ 3]}} & x_double_sub;
    // assign product[ 4] = {64{choose_single_add[ 4]}} & x_single_add | {64{choose_double_add[ 4]}} & x_double_add | {64{choose_single_sub[ 4]}} & x_single_sub | {64{choose_double_sub[ 4]}} & x_double_sub;
    // assign product[ 5] = {64{choose_single_add[ 5]}} & x_single_add | {64{choose_double_add[ 5]}} & x_double_add | {64{choose_single_sub[ 5]}} & x_single_sub | {64{choose_double_sub[ 5]}} & x_double_sub;
    // assign product[ 6] = {64{choose_single_add[ 6]}} & x_single_add | {64{choose_double_add[ 6]}} & x_double_add | {64{choose_single_sub[ 6]}} & x_single_sub | {64{choose_double_sub[ 6]}} & x_double_sub;
    // assign product[ 7] = {64{choose_single_add[ 7]}} & x_single_add | {64{choose_double_add[ 7]}} & x_double_add | {64{choose_single_sub[ 7]}} & x_single_sub | {64{choose_double_sub[ 7]}} & x_double_sub;
    // assign product[ 8] = {64{choose_single_add[ 8]}} & x_single_add | {64{choose_double_add[ 8]}} & x_double_add | {64{choose_single_sub[ 8]}} & x_single_sub | {64{choose_double_sub[ 8]}} & x_double_sub;
    // assign product[ 9] = {64{choose_single_add[ 9]}} & x_single_add | {64{choose_double_add[ 9]}} & x_double_add | {64{choose_single_sub[ 9]}} & x_single_sub | {64{choose_double_sub[ 9]}} & x_double_sub;
    // assign product[10] = {64{choose_single_add[10]}} & x_single_add | {64{choose_double_add[10]}} & x_double_add | {64{choose_single_sub[10]}} & x_single_sub | {64{choose_double_sub[10]}} & x_double_sub;
    // assign product[11] = {64{choose_single_add[11]}} & x_single_add | {64{choose_double_add[11]}} & x_double_add | {64{choose_single_sub[11]}} & x_single_sub | {64{choose_double_sub[11]}} & x_double_sub;
    // assign product[12] = {64{choose_single_add[12]}} & x_single_add | {64{choose_double_add[12]}} & x_double_add | {64{choose_single_sub[12]}} & x_single_sub | {64{choose_double_sub[12]}} & x_double_sub;
    // assign product[13] = {64{choose_single_add[13]}} & x_single_add | {64{choose_double_add[13]}} & x_double_add | {64{choose_single_sub[13]}} & x_single_sub | {64{choose_double_sub[13]}} & x_double_sub;
    // assign product[14] = {64{choose_single_add[14]}} & x_single_add | {64{choose_double_add[14]}} & x_double_add | {64{choose_single_sub[14]}} & x_single_sub | {64{choose_double_sub[14]}} & x_double_sub;
    // assign product[15] = {64{choose_single_add[15]}} & x_single_add | {64{choose_double_add[15]}} & x_double_add | {64{choose_single_sub[15]}} & x_single_sub | {64{choose_double_sub[15]}} & x_double_sub;
    // assign product[16] = {64{choose_single_add[16]}} & x_single_add | {64{choose_double_add[16]}} & x_double_add | {64{choose_single_sub[16]}} & x_single_sub | {64{choose_double_sub[16]}} & x_double_sub;
/*Level 1 : 17 part_product to 12 part_product*/
    wire [63:0] temporary_1 [11:0];
    CSA csa1_1 (
        .in1({product[16][31:0], 32'b0}),
        .in2({product[15][33:0], 30'b0}),
        .in3({product[14][35:0], 28'b0}),
        .C(temporary_1[0]),
        .S(temporary_1[1])
    );
    CSA csa1_2 (
        .in1({product[13][37:0], 26'b0}),
        .in2({product[12][39:0], 24'b0}),
        .in3({product[11][41:0], 22'b0}),
        .C(temporary_1[2]),
        .S(temporary_1[3])
    );
    CSA csa1_3 (
        .in1({product[10][43:0], 20'b0}),
        .in2({product[ 9][45:0], 18'b0}),
        .in3({product[ 8][47:0], 16'b0}),
        .C(temporary_1[4]),
        .S(temporary_1[5])
    );
    CSA csa1_4 (
        .in1({product[ 7][49:0], 14'b0}),
        .in2({product[ 6][51:0], 12'b0}),
        .in3({product[ 5][53:0], 10'b0}),
        .C(temporary_1[6]),
        .S(temporary_1[7])
    );
    CSA csa1_5 (
        .in1({product[ 4][55:0],  8'b0}),
        .in2({product[ 3][57:0],  6'b0}),
        .in3({product[ 2][59:0],  4'b0}),
        .C(temporary_1[8]),
        .S(temporary_1[9])
    );
    assign temporary_1[10] = {product[1][61:0], 2'b0};
    assign temporary_1[11] = product[0];
/*Level 2 : 12 part_product to 8 part_product*/
    wire [63:0] temporary_2 [7:0];
    CSA csa2_1 (
        .in1(temporary_1[0]),
        .in2(temporary_1[1]),
        .in3(temporary_1[2]),
        .C(temporary_2[0]),
        .S(temporary_2[1])
    );
    CSA csa2_2 (
        .in1(temporary_1[3]),
        .in2(temporary_1[4]),
        .in3(temporary_1[5]),
        .C(temporary_2[2]),
        .S(temporary_2[3])
    );
    CSA csa2_3 (
        .in1(temporary_1[6]),
        .in2(temporary_1[7]),
        .in3(temporary_1[8]),
        .C(temporary_2[4]),
        .S(temporary_2[5])
    );
    CSA csa2_4 (
        .in1(temporary_1[9]),
        .in2(temporary_1[10]),
        .in3(temporary_1[11]),
        .C(temporary_2[6]),
        .S(temporary_2[7])
    );

/*Level 3 : 8 part_product to 6 part_product*/
    wire [63:0] temporary_3 [5:0];
    CSA csa3_1 (
        .in1(temporary_2[0]),
        .in2(temporary_2[1]),
        .in3(temporary_2[2]),
        .C(temporary_3[0]),
        .S(temporary_3[1])
    );
    CSA csa3_2 (
        .in1(temporary_2[3]),
        .in2(temporary_2[4]),
        .in3(temporary_2[5]),
        .C(temporary_3[2]),
        .S(temporary_3[3])
    );
    assign temporary_3[4] = temporary_2[6];
    assign temporary_3[5] = temporary_2[7];

    reg [63:0] mul_reg [5:0];
    always @(posedge mul_clk) begin
        if (!resetn)
            {mul_reg[0], mul_reg[1], mul_reg[2], mul_reg[3], mul_reg[4], mul_reg[5]} <= 384'b0;
        else 
            {mul_reg[0], mul_reg[1], mul_reg[2], mul_reg[3], mul_reg[4], mul_reg[5]} <= {temporary_3[0], temporary_3[1], temporary_3[2], temporary_3[3], temporary_3[4], temporary_3[5]};
    end
/*Level 4 : 6 part_product to 4 part_product*/
    wire [63:0] temporary_4 [3:0];
    CSA csa4_1 (
        .in1(mul_reg[0]),
        .in2(mul_reg[1]),
        .in3(mul_reg[2]),
        .C(temporary_4[0]),
        .S(temporary_4[1])
    );
    CSA csa4_2 (
        .in1(mul_reg[3]),
        .in2(mul_reg[4]),
        .in3(mul_reg[5]),
        .C(temporary_4[2]),
        .S(temporary_4[3])
    );
/*Level 5 : 4 part_product to 3 part_product*/
    wire [63:0] temporary_5 [2:0];
    CSA csa5_1 (
        .in1(temporary_4[0]),
        .in2(temporary_4[1]),
        .in3(temporary_4[2]),
        .C(temporary_5[0]),
        .S(temporary_5[1])
    );
    assign temporary_5[2] = temporary_4[3]; 
/*Level 6 : 3 part_product to 2 part_product*/
    wire [63:0] temporary_6 [1:0];
    CSA csa6_1 (
        .in1(temporary_5[0]),
        .in2(temporary_5[1]),
        .in3(temporary_5[2]),
        .C(temporary_6[0]),
        .S(temporary_6[1])
    );
    assign result = (temporary_6[0] + temporary_6[1]);
endmodule


module CSA(
    input  wire [63:0] in1,
    input  wire [63:0] in2,
    input  wire [63:0] in3,
    output wire [63:0] C,
    output wire [63:0] S
);
    
    assign S  = in1 ^ in2 ^ in3;
    assign C = {in1[62:0] & in2[62:0] | in1[62:0] & in3[62:0] | in2[62:0] & in3[62:0], 1'b0} ;

endmodule