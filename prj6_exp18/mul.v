module mul(
  input  wire [31:0] alu_src1,
  input  wire [31:0] alu_src2,
  input  wire        signed_mul,

  output wire [63:0] mul_result,
  output wire        mul_complete
);

wire [32:0] mul_src1;
wire [32:0] mul_src2;
wire [65:0] temporary_result;

assign mul_src1 = signed_mul ? {alu_src1[31], alu_src1} : {1'b0, alu_src1};
assign mul_src2 = signed_mul ? {alu_src2[31], alu_src2} : {1'b0, alu_src2};
assign mul_complete = 1'b1;

assign temporary_result = $signed(mul_src1) * $signed(mul_src2);
assign mul_result = temporary_result[63:0];




endmodule