module softmax_compute(
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
    lut_wr_en,
    log2_lut_data_in,
    exp2_lut_data_in,
    // Output Signal
    softmax_out0,
    softmax_out1,
    softmax_out2,
    softmax_out3,
    softmax_out4,
    softmax_out5,
    softmax_out6,
    softmax_out7
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
input lut_wr_en;
input [MANT_LEN-1:0] log2_lut_data_in;
input [FLOAT_LEN-1:0] exp2_lut_data_in;
output logic [FLOAT_LEN-1:0] softmax_out0, softmax_out1;
output logic [FLOAT_LEN-1:0] softmax_out2, softmax_out3;
output logic [FLOAT_LEN-1:0] softmax_out4, softmax_out5;
output logic [FLOAT_LEN-1:0] softmax_out6, softmax_out7;
//---------------------------------------------------------------------
//   LOGIC DECLARATION
//---------------------------------------------------------------------
logic [FLOAT_LEN-1:0] exp_sum_fir_stage0_w, exp_sum_fir_stage0_r;
logic [FLOAT_LEN-1:0] exp_sum_fir_stage1_w, exp_sum_fir_stage1_r;
logic [FLOAT_LEN-1:0] exp_sum_fir_stage2_w, exp_sum_fir_stage2_r;
logic [FLOAT_LEN-1:0] exp_sum_fir_stage3_w, exp_sum_fir_stage3_r;

logic [FLOAT_LEN-1:0] exp_sum_sec_stage0_w, exp_sum_sec_stage0_r;
logic [FLOAT_LEN-1:0] exp_sum_sec_stage1_w, exp_sum_sec_stage1_r;

logic [FLOAT_LEN-1:0] exp_sum_final_w, exp_sum_final_r;
//---------------------------------------------------------------------
//   DESIGN PART
//---------------------------------------------------------------------

// Softmax Computation
// (1) sum of exponent
// (2) each exponent / sum of exponent

// ========== First Part: Sum of exponent ==========
// Float16 Adder Tree
float16_adder SUM_FIR_0(
    .clk(clk),
    .rst_n(rst_n),
    .a(exp_in0),
    .b(exp_in1),
    .result(exp_sum_fir_stage0_w)
);

float16_adder SUM_FIR_1(
    .clk(clk),
    .rst_n(rst_n),
    .a(exp_in2),
    .b(exp_in3),
    .result(exp_sum_fir_stage1_w)
);

float16_adder SUM_FIR_2(
    .clk(clk),
    .rst_n(rst_n),
    .a(exp_in4),
    .b(exp_in5),
    .result(exp_sum_fir_stage2_w)
);

float16_adder SUM_FIR_3(
    .clk(clk),
    .rst_n(rst_n),
    .a(exp_in6),
    .b(exp_in7),
    .result(exp_sum_fir_stage3_w)
);

float16_adder SUM_SEC_0(
    .clk(clk),
    .rst_n(rst_n),
    .a(exp_sum_fir_stage0_r),
    .b(exp_sum_fir_stage1_r),
    .result(exp_sum_sec_stage0_w)
);

float16_adder SUM_SEC_1(
    .clk(clk),
    .rst_n(rst_n),
    .a(exp_sum_fir_stage2_r),
    .b(exp_sum_fir_stage3_r),
    .result(exp_sum_sec_stage1_w)
);

float16_adder SUM_FINAL(
    .clk(clk),
    .rst_n(rst_n),
    .a(exp_sum_sec_stage0_r),
    .b(exp_sum_sec_stage1_r),
    .result(exp_sum_final_w)
);

// ========== Second Part: each exponent / sum of exponent ==========

log_scale_div LOG_DIV_0(
    .clk(clk),
    .rst_n(rst_n),
    .a(exp_in0),
    .b(exp_sum_final_r),
    .lut_wr_en(lut_wr_en),
    .log2_lut_data_in(log2_lut_data_in),
    .exp2_lut_data_in(exp2_lut_data_in),
    .result(softmax_out0)
);

log_scale_div LOG_DIV_1(
    .clk(clk),
    .rst_n(rst_n),
    .a(exp_in1),
    .b(exp_sum_final_r),
    .lut_wr_en(lut_wr_en),
    .log2_lut_data_in(log2_lut_data_in),
    .exp2_lut_data_in(exp2_lut_data_in),
    .result(softmax_out1)
);

log_scale_div LOG_DIV_2(
    .clk(clk),
    .rst_n(rst_n),
    .a(exp_in2),
    .b(exp_sum_final_r),
    .lut_wr_en(lut_wr_en),
    .log2_lut_data_in(log2_lut_data_in),
    .exp2_lut_data_in(exp2_lut_data_in),
    .result(softmax_out2)
);

log_scale_div LOG_DIV_3(
    .clk(clk),
    .rst_n(rst_n),
    .a(exp_in3),
    .b(exp_sum_final_r),
    .lut_wr_en(lut_wr_en),
    .log2_lut_data_in(log2_lut_data_in),
    .exp2_lut_data_in(exp2_lut_data_in),
    .result(softmax_out3)
);

log_scale_div LOG_DIV_4(
    .clk(clk),
    .rst_n(rst_n),
    .a(exp_in4),
    .b(exp_sum_final_r),
    .lut_wr_en(lut_wr_en),
    .log2_lut_data_in(log2_lut_data_in),
    .exp2_lut_data_in(exp2_lut_data_in),
    .result(softmax_out4)
);

log_scale_div LOG_DIV_5(
    .clk(clk),
    .rst_n(rst_n),
    .a(exp_in5),
    .b(exp_sum_final_r),
    .lut_wr_en(lut_wr_en),
    .log2_lut_data_in(log2_lut_data_in),
    .exp2_lut_data_in(exp2_lut_data_in),
    .result(softmax_out5)
);

log_scale_div LOG_DIV_6(
    .clk(clk),
    .rst_n(rst_n),
    .a(exp_in6),
    .b(exp_sum_final_r),
    .lut_wr_en(lut_wr_en),
    .log2_lut_data_in(log2_lut_data_in),
    .exp2_lut_data_in(exp2_lut_data_in),
    .result(softmax_out6)
);

log_scale_div LOG_DIV_7(
    .clk(clk),
    .rst_n(rst_n),
    .a(exp_in7),
    .b(exp_sum_final_r),
    .lut_wr_en(lut_wr_en),
    .log2_lut_data_in(log2_lut_data_in),
    .exp2_lut_data_in(exp2_lut_data_in),
    .result(softmax_out7)
);

// Pipeline Register Update
always_ff @ (posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        exp_sum_fir_stage0_r    <= 16'h0000;
        exp_sum_fir_stage1_r    <= 16'h0000;
        exp_sum_fir_stage2_r    <= 16'h0000;
        exp_sum_fir_stage3_r    <= 16'h0000;
        exp_sum_sec_stage0_r    <= 16'h0000;
        exp_sum_sec_stage1_r    <= 16'h0000;
        exp_sum_final_r         <= 16'h0000;
    end else begin
        exp_sum_fir_stage0_r    <= exp_sum_fir_stage0_w;
        exp_sum_fir_stage1_r    <= exp_sum_fir_stage1_w;
        exp_sum_fir_stage2_r    <= exp_sum_fir_stage2_w;
        exp_sum_fir_stage3_r    <= exp_sum_fir_stage3_w;
        exp_sum_sec_stage0_r    <= exp_sum_sec_stage0_w;
        exp_sum_sec_stage1_r    <= exp_sum_sec_stage1_w;
        exp_sum_final_r         <= exp_sum_final_w;
    end
end

endmodule