module log_scale_div (
    // Input Signals
    clk,
    rst_n,
    a,
    b,
    lut_wr_en,
    log2_lut_data_in,
    exp2_lut_data_in,
    // Output Signals
    result
);

//---------------------------------------------------------------------
//   PARAMETER DEFINITION
//---------------------------------------------------------------------
parameter FLOAT_LEN = 16;
parameter EXP_LEN = 5;
parameter MANT_LEN = 10;
parameter LUT_SIZE = 128;

//---------------------------------------------------------------------
//   INPUT AND OUTPUT DECLARATION
//---------------------------------------------------------------------
input clk, rst_n;

input lut_wr_en;
input [MANT_LEN-1:0] log2_lut_data_in;
input [FLOAT_LEN-1:0] exp2_lut_data_in;

input [FLOAT_LEN-1:0] a,b;
output logic [FLOAT_LEN-1:0] result;

//---------------------------------------------------------------------
//   LOGIC DECLARATION
//---------------------------------------------------------------------
// Look Up Table for Log 2 Function
logic [MANT_LEN-1:0] log2_lut0 [0:LUT_SIZE-1];
logic [MANT_LEN-1:0] log2_lut1 [0:LUT_SIZE-1];

// Look Up Table for 2 scale Function
logic [FLOAT_LEN-1:0] exp2_lut [0:LUT_SIZE-1];

// write pointer for handling Look Up Table input
logic [$clog2(LUT_SIZE):0] lut_wr_ptr;

// Flag for Look Up Table write done
// logic lut_wr_done;

// ========== First Stage ==========
// separate each part of input
logic sign_a_fir_w, sign_a_fir_r;
logic sign_b_fir_w, sign_b_fir_r;
logic sign_a_sec_w, sign_a_sec_r;
logic sign_b_sec_w, sign_b_sec_r;
logic [EXP_LEN-1:0] exp_a_raw, exp_b_raw;
logic [MANT_LEN-1:0] mant_a, mant_b;

// Exponent value of unbias exponent
logic signed [(EXP_LEN+2)-1:0] exp_a_fir_w, exp_b_fir_w;

// Logic for log2 Look Up Table Address
logic [$clog2(LUT_SIZE)-1:0] log2_idx_a, log2_idx_b;

// ********** First Stage Register **********
// Logic for pipeline unbiased exponent
logic signed [(EXP_LEN+2)-1:0] exp_a_fir_r, exp_b_fir_r;

// Logic for log2-mantissa after look up
logic [MANT_LEN-1:0] log2_mant_a, log2_mant_b;

// ========== Second Stage ==========
// Exponent/Mantissa value of sum exponent
logic signed [(EXP_LEN+2)-1:0] exp_diff;
logic signed [(MANT_LEN+2)-1:0] mant_diff;

// ********** Second Stage Register **********
// Normalized value of exponent/mantissa sum
logic signed [(EXP_LEN+2)-1:0] exp_norm_w ,exp_norm_r;
logic [MANT_LEN-1:0] mant_norm;

// Logic for exp2 Look Up Table Address
logic [FLOAT_LEN-1:0] exp2_idx;

// Logic for exp2-value after look up
logic [FLOAT_LEN-1:0] exp2_val;

// ========== Third Stage ==========
// Logic for final sign/exponent/mantissa
logic sign_final;
logic [(EXP_LEN+2)-1:0] exp_final;
logic [MANT_LEN-1:0] mant_final;

// Logic for subnormal process
logic [(MANT_LEN+1)-1:0] subnormal_imp;
logic [MANT_LEN-1:0] subnormal_shifted;

// Logic for normal result
logic [FLOAT_LEN-1:0] normal_result;

// ========== Specific Result Path ===========
// Logic for specific condition
logic is_nan_a_fir_w, is_nan_a_fir_r;
logic is_nan_a_sec_w, is_nan_a_sec_r;
logic is_nan_a_thr_w;

logic is_nan_b_fir_w, is_nan_b_fir_r;
logic is_nan_b_sec_w, is_nan_b_sec_r;
logic is_nan_b_thr_w;

logic is_inf_a_fir_w, is_inf_a_fir_r;
logic is_inf_a_sec_w, is_inf_a_sec_r;
logic is_inf_a_thr_w;

logic is_inf_b_fir_w, is_inf_b_fir_r;
logic is_inf_b_sec_w, is_inf_b_sec_r;
logic is_inf_b_thr_w;

logic is_zero_a_fir_w, is_zero_a_fir_r;
logic is_zero_a_sec_w, is_zero_a_sec_r;
logic is_zero_a_thr_w;

logic is_zero_b_fir_w, is_zero_b_fir_r;
logic is_zero_b_sec_w, is_zero_b_sec_r;
logic is_zero_b_thr_w;

// Logic for specific result
logic [FLOAT_LEN-1:0] specific_result;

//---------------------------------------------------------------------
//   DESIGN PART
//---------------------------------------------------------------------

// ========== Look Up Table Initialization ===========
// procedure block for handle lut_wr_ptr
always_ff @ (posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        lut_wr_ptr <= 8'b0;
    end else begin
        lut_wr_ptr <= (lut_wr_en) ? lut_wr_ptr + 1 : lut_wr_ptr;
    end
end

// procedure block for handle log2_lut0
always_ff @ (posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        log2_lut0[lut_wr_ptr] <= 16'b0;
    end else begin
        log2_lut0[lut_wr_ptr] <= (lut_wr_en) ? log2_lut_data_in : log2_lut0[lut_wr_ptr];
    end
end

// procedure block for handle log2_lut1
always_ff @ (posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        log2_lut1[lut_wr_ptr] <= 16'b0;
    end else begin
        log2_lut1[lut_wr_ptr] <= (lut_wr_en) ? log2_lut_data_in : log2_lut1[lut_wr_ptr];
    end
end

// procedure block for handle exp2_lut
always_ff @ (posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        exp2_lut[lut_wr_ptr] <= 16'b0;
    end else begin
        exp2_lut[lut_wr_ptr] <= (lut_wr_en) ? exp2_lut_data_in : exp2_lut[lut_wr_ptr];
    end
end

// ========== First Stage: Unpack float16 a and b ===========

// separate each part of input
assign {sign_a_fir_w, exp_a_raw, mant_a} = a;
assign {sign_b_fir_w, exp_b_raw, mant_b} = b;

// get the read address of log2_lut0 & log2_lut0
assign log2_idx_a = mant_a[9:3];
assign log2_idx_b = mant_b[9:3];

// get the unbiased exponent
assign exp_a_fir_w = $signed({2'b00, exp_a_raw}) - 7'sd15;
assign exp_b_fir_w = $signed({2'b00, exp_b_raw}) - 7'sd15;

// ********** First Stage Register: LUT Lookups & pipeline unbiased exponent **********

// procedure block for sign_a & sign_b & unbiased exponent pipeline
always_ff @ (posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        sign_a_fir_r <= 1'b0;
        sign_b_fir_r <= 1'b0;
        exp_a_fir_r <= 7'b0;
        exp_b_fir_r <= 7'b0;
    end else begin
        sign_a_fir_r <= sign_a_fir_w;
        sign_b_fir_r <= sign_b_fir_w;
        exp_a_fir_r <= exp_a_fir_w;
        exp_b_fir_r <= exp_b_fir_w;
    end
end

// procedure block for get the log2-mantissa of input a
always_ff @ (posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        log2_mant_a <= 10'b0;
    end else begin
        // log2_mant_a <= (lut_wr_done) ? log2_lut0[log2_idx_a] : 10'b0;
        log2_mant_a <= log2_lut0[log2_idx_a];
    end
end

// procedure block for get the log2-mantissa of input b
always_ff @ (posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        log2_mant_b <= 10'b0;
    end else begin
        // log2_mant_b <= (lut_wr_done) ? log2_lut1[log2_idx_b] : 10'b0;
        log2_mant_b <= log2_lut1[log2_idx_b];
    end
end

// ========== Second Stage: Compute exponent/mantissa sum and normalize ===========

// pipeline for sign_a & sign_b
assign sign_a_sec_w = sign_a_fir_r;
assign sign_b_sec_w = sign_b_fir_r;

// compute exponent/mantissa sum
assign exp_diff = exp_a_fir_r - exp_b_fir_r;
assign mant_diff = {2'b00, log2_mant_a} - {2'b00, log2_mant_b};

// normalize the sum of exponent/mantissa
always_comb begin
    if(mant_diff[11]) begin
        exp_norm_w = exp_diff - 7'sd1;
    end else begin
        exp_norm_w = exp_diff;
    end
end

assign mant_norm = mant_diff[9:0];

// get the index of exp2 look up
assign exp2_idx = mant_norm[9:3];

// ********** Second Stage Register: LUT Lookups & pipeline normalized exponent/mantissa **********

// procedure block for sign_a & sign_b & normalized exponent/mantissa pipeline
always_ff @ (posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        sign_a_sec_r <= 1'b0;
        sign_b_sec_r <= 1'b0;
        exp_norm_r  <= 7'b0;
    end else begin
        sign_a_sec_r <= sign_a_sec_w;
        sign_b_sec_r <= sign_b_sec_w;
        exp_norm_r  <= exp_norm_w;
    end
end

// procedure block for exp2 look up table look up
always_ff @ (posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        exp2_val <= 16'b0;
    end else begin
        // exp2_val <= (lut_wr_done) ? exp2_lut[exp2_idx] : 16'b0;
        exp2_val <= exp2_lut[exp2_idx];
    end
end

// ========== Third Stage: Exponent adjust & concatenate ===========

// get the sign of the final number
assign sign_final = sign_a_sec_r ^ sign_b_sec_r;

// get the exponent of the final number
assign exp_final = exp_norm_r + 7'sd15;

// get the mantissa of the final number
assign mant_final = exp2_val[9:0];

// procedure block for normal result
always_comb begin
    if(exp_final <= 0 && exp_norm_r >= -MANT_LEN) begin
        // subnormal
        subnormal_imp = {1'b1, mant_final};
        subnormal_shifted = subnormal_imp >> (1 - exp_final);
        normal_result = {sign_final, 5'h00, subnormal_shifted};
    end else if(exp_final <= 0) begin
        // underflow to zero
        normal_result = {sign_final, 5'h00, 10'h000};
    end else if(exp_final > 30) begin
        // overflow to inf
        normal_result = {sign_final, 5'h1F, 10'h000};
    end else begin
        // normal
        normal_result = {sign_final, exp_final[4:0], mant_final};
    end
end

// ========== Specific Result Path ===========
assign is_nan_a_fir_w = (exp_a_raw == 5'h1F) && (mant_a != 0);
assign is_nan_b_fir_w = (exp_b_raw == 5'h1F) && (mant_b != 0);
assign is_inf_a_fir_w = (exp_a_raw == 5'h1F) && (mant_a == 0);
assign is_inf_b_fir_w = (exp_b_raw == 5'h1F) && (mant_b == 0);
assign is_zero_a_fir_w = (exp_a_raw == 5'h00) && (mant_a == 0);
assign is_zero_b_fir_w = (exp_b_raw == 5'h00) && (mant_b == 0);

// Two stage pipeline to align normal result
always_ff @ (posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        is_nan_a_fir_r  <= 1'b0;
        is_nan_b_fir_r  <= 1'b0;
        is_inf_a_fir_r  <= 1'b0;
        is_inf_b_fir_r  <= 1'b0;
        is_zero_a_fir_r <= 1'b0;
        is_zero_b_fir_r <= 1'b0;
    end else begin
        is_nan_a_fir_r  <= is_nan_a_fir_w;
        is_nan_b_fir_r  <= is_nan_b_fir_w;
        is_inf_a_fir_r  <= is_inf_a_fir_w;
        is_inf_b_fir_r  <= is_inf_b_fir_w;
        is_zero_a_fir_r <= is_zero_a_fir_w;
        is_zero_b_fir_r <= is_zero_b_fir_w;
    end
end

always_comb begin
    is_nan_a_sec_w  = is_nan_a_fir_r;
    is_nan_b_sec_w  = is_nan_b_fir_r;
    is_inf_a_sec_w  = is_inf_a_fir_r;
    is_inf_b_sec_w  = is_inf_b_fir_r;
    is_zero_a_sec_w = is_zero_a_fir_r;
    is_zero_b_sec_w = is_zero_b_fir_r;
end

always_ff @ (posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        is_nan_a_sec_r  <= 1'b0;
        is_nan_b_sec_r  <= 1'b0;
        is_inf_a_sec_r  <= 1'b0;
        is_inf_b_sec_r  <= 1'b0;
        is_zero_a_sec_r <= 1'b0;
        is_zero_b_sec_r <= 1'b0;
    end else begin
        is_nan_a_sec_r  <= is_nan_a_sec_w;
        is_nan_b_sec_r  <= is_nan_b_sec_w;
        is_inf_a_sec_r  <= is_inf_a_sec_w;
        is_inf_b_sec_r  <= is_inf_b_sec_w;
        is_zero_a_sec_r <= is_zero_a_sec_w;
        is_zero_b_sec_r <= is_zero_b_sec_w;
    end
end

always_comb begin
    is_nan_a_thr_w  = is_nan_a_sec_r;
    is_nan_b_thr_w  = is_nan_b_sec_r;
    is_inf_a_thr_w  = is_inf_a_sec_r;
    is_inf_b_thr_w  = is_inf_b_sec_r;
    is_zero_a_thr_w = is_zero_a_sec_r;
    is_zero_b_thr_w = is_zero_b_sec_r;
end

// procedure block for specific result
always_comb begin

    if(is_nan_a_thr_w || is_nan_b_thr_w) begin
        // a or b NaN -> NaN
        specific_result = {sign_final, 5'h1F, 10'h200};
    end else if(is_inf_a_thr_w && is_zero_b_thr_w) begin
        // Inf / 0 -> NaN
        specific_result = {sign_final, 5'h1F, 10'h200};
    end else if(is_zero_a_thr_w && is_zero_b_thr_w) begin
        // 0 / 0 -> NaN
        specific_result = {sign_final, 5'h1F, 10'h200};
    end else if(is_inf_a_thr_w) begin
        // Inf / (non-zero) -> Inf
        specific_result = {sign_final, 5'h1F, 10'h000};
    end else if(is_zero_b_thr_w) begin
        // (non-Inf) / 0 -> Inf
        specific_result = {sign_final, 5'h1F, 10'h000};
    end else if(is_inf_b_thr_w) begin
        // (non-NaN/Inf/0) / Inf -> 0
        specific_result = {sign_final, 5'h00, 10'h000};
    end else if(is_zero_a_thr_w) begin
        //  0 / (non-NaN/Inf/0) -> 0
        specific_result = {sign_final, 5'h00, 10'h000};
    end else begin
        specific_result = 16'h0000;
    end
end

// &&&&&&&&&& Final Output Path &&&&&&&&&&

assign result = (is_nan_a_thr_w || is_nan_b_thr_w || is_inf_a_thr_w || is_inf_b_thr_w || is_zero_a_thr_w || is_zero_b_thr_w) ? specific_result : normal_result;

endmodule