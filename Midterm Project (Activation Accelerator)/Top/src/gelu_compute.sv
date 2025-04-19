module gelu_compute(
    // Input Signal
    clk,
    rst_n,
    exp_in0,
    exp_in1,
    exp_in2,
    exp_in3,
    exp_in4,
    exp_in5,
    exp_in6,
    exp_in7,
    x_in0,
    x_in1,
    x_in2,
    x_in3,
    x_in4,
    x_in5,
    x_in6,
    x_in7,
    lut_wr_en,
    log2_lut_data_in,
    exp2_lut_data_in,
    // Output Signal
    gelu_out0,
    gelu_out1,
    gelu_out2,
    gelu_out3,
    gelu_out4,
    gelu_out5,
    gelu_out6,
    gelu_out7
);

//---------------------------------------------------------------------
//   PARAMETER DEFINITION
//---------------------------------------------------------------------
parameter FLOAT_LEN = 16;
parameter MANT_LEN = 10;
//---------------------------------------------------------------------
//   INPUT AND OUTPUT DECLARATION
//---------------------------------------------------------------------
input clk, rst_n;
input [FLOAT_LEN-1:0] exp_in0, exp_in1, exp_in2, exp_in3;
input [FLOAT_LEN-1:0] exp_in4, exp_in5, exp_in6, exp_in7;
input [FLOAT_LEN-1:0] x_in0, x_in1, x_in2, x_in3;
input [FLOAT_LEN-1:0] x_in4, x_in5, x_in6, x_in7;
input lut_wr_en;
input [MANT_LEN-1:0] log2_lut_data_in;
input [FLOAT_LEN-1:0] exp2_lut_data_in;
output logic [FLOAT_LEN-1:0] gelu_out0, gelu_out1;
output logic [FLOAT_LEN-1:0] gelu_out2, gelu_out3;
output logic [FLOAT_LEN-1:0] gelu_out4, gelu_out5;
output logic [FLOAT_LEN-1:0] gelu_out6, gelu_out7;
//---------------------------------------------------------------------
//   LOGIC DECLARATION
//---------------------------------------------------------------------
logic [FLOAT_LEN-1:0] denominator0_w, denominator0_r;
logic [FLOAT_LEN-1:0] denominator1_w, denominator1_r;
logic [FLOAT_LEN-1:0] denominator2_w, denominator2_r;
logic [FLOAT_LEN-1:0] denominator3_w, denominator3_r;
logic [FLOAT_LEN-1:0] denominator4_w, denominator4_r;
logic [FLOAT_LEN-1:0] denominator5_w, denominator5_r;
logic [FLOAT_LEN-1:0] denominator6_w, denominator6_r;
logic [FLOAT_LEN-1:0] denominator7_w, denominator7_r;
logic [FLOAT_LEN-1:0] sigmoid0_w, sigmoid0_r;
logic [FLOAT_LEN-1:0] sigmoid1_w, sigmoid1_r;
logic [FLOAT_LEN-1:0] sigmoid2_w, sigmoid2_r;
logic [FLOAT_LEN-1:0] sigmoid3_w, sigmoid3_r;
logic [FLOAT_LEN-1:0] sigmoid4_w, sigmoid4_r;
logic [FLOAT_LEN-1:0] sigmoid5_w, sigmoid5_r;
logic [FLOAT_LEN-1:0] sigmoid6_w, sigmoid6_r;
logic [FLOAT_LEN-1:0] sigmoid7_w, sigmoid7_r;
//---------------------------------------------------------------------
//   DESIGN PART
//---------------------------------------------------------------------

// GELU Computation
// (1) compute 1 + e^(-1.702 * x)
// (2) compute sigmoid = 1 / (1 + e^(-1.702 * x))
// (3) compute gelu = x * sigmoid

// ========== First Part: compute 1 + e^(-1.702 * x) ==========

float16_adder FP16_ADD_0(
    .clk(clk),
    .rst_n(rst_n),
    .a(16'h3C00),
    .b(exp_in0),
    .result(denominator0_w)
);

float16_adder FP16_ADD_1(
    .clk(clk),
    .rst_n(rst_n),
    .a(16'h3C00),
    .b(exp_in1),
    .result(denominator1_w)
);

float16_adder FP16_ADD_2(
    .clk(clk),
    .rst_n(rst_n),
    .a(16'h3C00),
    .b(exp_in2),
    .result(denominator2_w)
);

float16_adder FP16_ADD_3(
    .clk(clk),
    .rst_n(rst_n),
    .a(16'h3C00),
    .b(exp_in3),
    .result(denominator3_w)
);

float16_adder FP16_ADD_4(
    .clk(clk),
    .rst_n(rst_n),
    .a(16'h3C00),
    .b(exp_in4),
    .result(denominator4_w)
);

float16_adder FP16_ADD_5(
    .clk(clk),
    .rst_n(rst_n),
    .a(16'h3C00),
    .b(exp_in5),
    .result(denominator5_w)
);

float16_adder FP16_ADD_6(
    .clk(clk),
    .rst_n(rst_n),
    .a(16'h3C00),
    .b(exp_in6),
    .result(denominator6_w)
);

float16_adder FP16_ADD_7(
    .clk(clk),
    .rst_n(rst_n),
    .a(16'h3C00),
    .b(exp_in7),
    .result(denominator7_w)
);

// ========== Second Part: compute sigmoid = 1 / (1 + e^(-1.702 * x)) ==========

log_scale_div LOG_DIV_0(
    .clk(clk),
    .rst_n(rst_n),
    .a(16'h3C00),
    .b(denominator0_r),
    .lut_wr_en(lut_wr_en),
    .log2_lut_data_in(log2_lut_data_in),
    .exp2_lut_data_in(exp2_lut_data_in),
    .result(sigmoid0_w)
);

log_scale_div LOG_DIV_1(
    .clk(clk),
    .rst_n(rst_n),
    .a(16'h3C00),
    .b(denominator1_r),
    .lut_wr_en(lut_wr_en),
    .log2_lut_data_in(log2_lut_data_in),
    .exp2_lut_data_in(exp2_lut_data_in),
    .result(sigmoid1_w)
);

log_scale_div LOG_DIV_2(
    .clk(clk),
    .rst_n(rst_n),
    .a(16'h3C00),
    .b(denominator2_r),
    .lut_wr_en(lut_wr_en),
    .log2_lut_data_in(log2_lut_data_in),
    .exp2_lut_data_in(exp2_lut_data_in),
    .result(sigmoid2_w)
);

log_scale_div LOG_DIV_3(
    .clk(clk),
    .rst_n(rst_n),
    .a(16'h3C00),
    .b(denominator3_r),
    .lut_wr_en(lut_wr_en),
    .log2_lut_data_in(log2_lut_data_in),
    .exp2_lut_data_in(exp2_lut_data_in),
    .result(sigmoid3_w)
);

log_scale_div LOG_DIV_4(
    .clk(clk),
    .rst_n(rst_n),
    .a(16'h3C00),
    .b(denominator4_r),
    .lut_wr_en(lut_wr_en),
    .log2_lut_data_in(log2_lut_data_in),
    .exp2_lut_data_in(exp2_lut_data_in),
    .result(sigmoid4_w)
);

log_scale_div LOG_DIV_5(
    .clk(clk),
    .rst_n(rst_n),
    .a(16'h3C00),
    .b(denominator5_r),
    .lut_wr_en(lut_wr_en),
    .log2_lut_data_in(log2_lut_data_in),
    .exp2_lut_data_in(exp2_lut_data_in),
    .result(sigmoid5_w)
);

log_scale_div LOG_DIV_6(
    .clk(clk),
    .rst_n(rst_n),
    .a(16'h3C00),
    .b(denominator6_r),
    .lut_wr_en(lut_wr_en),
    .log2_lut_data_in(log2_lut_data_in),
    .exp2_lut_data_in(exp2_lut_data_in),
    .result(sigmoid6_w)
);

log_scale_div LOG_DIV_7(
    .clk(clk),
    .rst_n(rst_n),
    .a(16'h3C00),
    .b(denominator7_r),
    .lut_wr_en(lut_wr_en),
    .log2_lut_data_in(log2_lut_data_in),
    .exp2_lut_data_in(exp2_lut_data_in),
    .result(sigmoid7_w)
);

// ========== Last Part: compute gelu = x * sigmoid ==========

log_scale_mul LOG_MUL_0(
    .clk(clk),
    .rst_n(rst_n),
    .a(x_in0),
    .b(sigmoid0_r),
    .lut_wr_en(lut_wr_en),
    .log2_lut_data_in(log2_lut_data_in),
    .exp2_lut_data_in(exp2_lut_data_in),
    .result(gelu_out0)
);

log_scale_mul LOG_MUL_1(
    .clk(clk),
    .rst_n(rst_n),
    .a(x_in1),
    .b(sigmoid1_r),
    .lut_wr_en(lut_wr_en),
    .log2_lut_data_in(log2_lut_data_in),
    .exp2_lut_data_in(exp2_lut_data_in),
    .result(gelu_out1)
);

log_scale_mul LOG_MUL_2(
    .clk(clk),
    .rst_n(rst_n),
    .a(x_in2),
    .b(sigmoid2_r),
    .lut_wr_en(lut_wr_en),
    .log2_lut_data_in(log2_lut_data_in),
    .exp2_lut_data_in(exp2_lut_data_in),
    .result(gelu_out2)
);

log_scale_mul LOG_MUL_3(
    .clk(clk),
    .rst_n(rst_n),
    .a(x_in3),
    .b(sigmoid3_r),
    .lut_wr_en(lut_wr_en),
    .log2_lut_data_in(log2_lut_data_in),
    .exp2_lut_data_in(exp2_lut_data_in),
    .result(gelu_out3)
);

log_scale_mul LOG_MUL_4(
    .clk(clk),
    .rst_n(rst_n),
    .a(x_in4),
    .b(sigmoid4_r),
    .lut_wr_en(lut_wr_en),
    .log2_lut_data_in(log2_lut_data_in),
    .exp2_lut_data_in(exp2_lut_data_in),
    .result(gelu_out4)
);

log_scale_mul LOG_MUL_5(
    .clk(clk),
    .rst_n(rst_n),
    .a(x_in5),
    .b(sigmoid5_r),
    .lut_wr_en(lut_wr_en),
    .log2_lut_data_in(log2_lut_data_in),
    .exp2_lut_data_in(exp2_lut_data_in),
    .result(gelu_out5)
);

log_scale_mul LOG_MUL_6(
    .clk(clk),
    .rst_n(rst_n),
    .a(x_in6),
    .b(sigmoid6_r),
    .lut_wr_en(lut_wr_en),
    .log2_lut_data_in(log2_lut_data_in),
    .exp2_lut_data_in(exp2_lut_data_in),
    .result(gelu_out6)
);

log_scale_mul LOG_MUL_7(
    .clk(clk),
    .rst_n(rst_n),
    .a(x_in7),
    .b(sigmoid7_r),
    .lut_wr_en(lut_wr_en),
    .log2_lut_data_in(log2_lut_data_in),
    .exp2_lut_data_in(exp2_lut_data_in),
    .result(gelu_out7)
);

// Pipeline Register Update
always_ff @ (posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        denominator0_r <= 16'b0;
        denominator1_r <= 16'b0;
        denominator2_r <= 16'b0;
        denominator3_r <= 16'b0;
        denominator4_r <= 16'b0;
        denominator5_r <= 16'b0;
        denominator6_r <= 16'b0;
        denominator7_r <= 16'b0;
        sigmoid0_r <= 16'b0;
        sigmoid1_r <= 16'b0;
        sigmoid2_r <= 16'b0;
        sigmoid3_r <= 16'b0;
        sigmoid4_r <= 16'b0;
        sigmoid5_r <= 16'b0;
        sigmoid6_r <= 16'b0;
        sigmoid7_r <= 16'b0;
    end else begin
        denominator0_r <= denominator0_w;
        denominator1_r <= denominator1_w;
        denominator2_r <= denominator2_w;
        denominator3_r <= denominator3_w;
        denominator4_r <= denominator4_w;
        denominator5_r <= denominator5_w;
        denominator6_r <= denominator6_w;
        denominator7_r <= denominator7_w;
        sigmoid0_r <= sigmoid0_w;
        sigmoid1_r <= sigmoid1_w;
        sigmoid2_r <= sigmoid2_w;
        sigmoid3_r <= sigmoid3_w;
        sigmoid4_r <= sigmoid4_w;
        sigmoid5_r <= sigmoid5_w;
        sigmoid6_r <= sigmoid6_w;
        sigmoid7_r <= sigmoid7_w;
    end
end

endmodule