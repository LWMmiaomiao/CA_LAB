// module div(
//     input  wire        clk,
//     input  wire        reset,
//     input  wire [31:0] alu_src1,
//     input  wire [31:0] alu_src2,
//     input  wire [ 3:0] div_op,
    
//     output wire        div_complete,
//     output wire [63:0] div_result,
//     output wire [63:0] mod_result
// );
// /*signed_div和unsigned_div的4个ready握手信号始终保持同步*/
// wire        signed_out_valid;
// wire        unsigned_out_valid;
// wire [63:0] signed_div_result;
// wire [63:0] unsigned_div_result;
// reg         signed_div_valid;
// reg         unsigned_div_valid;
// wire        signed_div_ready;
// wire        unsigned_div_ready;
// reg         signed_lock;
// reg         unsigned_lock;

// wire op_div, op_divu, op_mod, op_modu;
// assign {op_modu, op_mod, op_divu, op_div} = div_op;

// /*当IP握手成功但未完成运算时仍会持续往外发送ready握手信号, 增加lock信号防止错误握手*/
// always @(posedge clk) begin
//     if(reset) begin
//         signed_lock <= 1'b0;
//     end
//     else if(signed_div_valid && signed_div_ready) begin
//         signed_lock <= 1'b1;
//     end
//     else if(signed_out_valid) begin
//         signed_lock <= 1'b0;
//     end
// end
// always @(posedge clk) begin
//     if(reset) begin
//         signed_div_valid <= 1'b0;
//     end
//     else if(signed_div_ready) begin
//         signed_div_valid <= 1'b0;
//     end
//     else if((op_div || op_mod) && !signed_lock) begin
//         signed_div_valid <= 1'b1;
//     end
// end

// always @(posedge clk) begin
//     if(reset) begin
//         unsigned_lock <= 1'b0;
//     end
//     else if(unsigned_div_valid && unsigned_div_ready) begin
//         unsigned_lock <= 1'b1;
//     end
//     else if(unsigned_out_valid) begin
//         unsigned_lock <= 1'b0;
//     end
// end
// always @(posedge clk) begin
//     if(reset) begin
//         unsigned_div_valid <= 1'b0;
//     end
//     else if(unsigned_div_ready) begin
//         unsigned_div_valid <= 1'b0;
//     end
//     else if((op_divu || op_modu) && !unsigned_lock) begin
//         unsigned_div_valid <= 1'b1;
//     end
// end

// signed_div signed_div(
//     .aclk(clk),
//     .s_axis_dividend_tdata(alu_src1),
//     .s_axis_divisor_tdata(alu_src2),
//     .s_axis_dividend_tvalid(signed_div_valid),
//     .s_axis_divisor_tvalid(signed_div_valid),
//     .s_axis_dividend_tready(signed_div_ready),
//     .s_axis_divisor_tready(signed_div_ready),
    
//     .m_axis_dout_tdata(signed_div_result),
//     .m_axis_dout_tvalid(signed_out_valid)
//     );
// unsigned_div unsigned_div(
//     .aclk(clk),
//     .s_axis_dividend_tdata(alu_src1),
//     .s_axis_divisor_tdata(alu_src2),
//     .s_axis_dividend_tvalid(unsigned_div_valid),
//     .s_axis_divisor_tvalid(unsigned_div_valid),
//     .s_axis_dividend_tready(unsigned_div_ready),
//     .s_axis_divisor_tready(unsigned_div_ready),
    
//     .m_axis_dout_tdata(unsigned_div_result),
//     .m_axis_dout_tvalid(unsigned_out_valid)
//     );
// assign div_result = op_div ? signed_div_result[63:32] : unsigned_div_result[63:32];
// assign mod_result = op_mod ? signed_div_result[31: 0] : unsigned_div_result[31: 0];

// assign div_complete = (op_div||op_mod) && signed_out_valid || (op_divu||op_modu) && unsigned_out_valid;

// endmodule