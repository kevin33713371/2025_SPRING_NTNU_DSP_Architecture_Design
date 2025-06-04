module float16_adder(
    // Input Signal
    clk,
    rst_n,
    a,
    b,
    // Output Signal
    result
);

//---------------------------------------------------------------------
//   PARAMETER DEFINITION
//---------------------------------------------------------------------
parameter FLOAT_LEN = 16;
parameter EXP_LEN = 5;
parameter MANT_LEN = 10;

//---------------------------------------------------------------------
//   INPUT AND OUTPUT DECLARATION
//---------------------------------------------------------------------
input clk, rst_n;
input [FLOAT_LEN-1:0] a, b;
output logic [FLOAT_LEN-1:0] result;

//---------------------------------------------------------------------
//   LOGIC DECLARATION FOR COMBINATIONAL LOGIC
//---------------------------------------------------------------------

// ========== First Stage: Input -> Compare Logic & Exponent subtract & Barrel-shifter ===========

// separate each part of input (wire)
logic sign_a_w, sign_b_w;
logic [EXP_LEN-1:0] exp_a_w, exp_b_w;
logic [MANT_LEN-1:0] mant_a, mant_b;

// compare signal (wire) for combinational logic
logic sign_cmp_w, exp_cmp_ab_w, exp_cmp_ba, mant_cmp_w;

// signal for exponent subtraction (wire)
logic [EXP_LEN-1:0] exp_diff;

// signal for mantissa pre-shift, prevent shift over 15 bits
logic [(EXP_LEN-1)-1:0] shift_amt;

// signal for mantissa pre-shift
// {1'b1, mantissa(10 bits), guard bit(1'b0), round bit(1'b0), sticky bits(3'b0)} => 16 bits
logic [(MANT_LEN+6)-1:0] m1_preshift, m2_preshift; // 16 bits

// signal for mantissa shifted (wire)
logic [(MANT_LEN+6)-1:0] m1_shifted_w, m2_shifted_w; // 16 bits

// ========== Second Stage: Compare Logic & Exponent subtract & Barrel-shifter -> Each part process ===========

// signal for sign, exponent, mantissa processing (wire)
logic sign_res_fir_w;

logic [EXP_LEN-1:0] exp_res_w;

logic [(MANT_LEN+7)-1:0] mant_res_w; // 17 bits, two 16 bits addition

// ========== Third Stage: Each part process -> Normalization ===========

// signal for exponent normalization (wire)
logic signed[(EXP_LEN+2)-1:0] exp_norm_tmp;
logic [EXP_LEN-1:0] exp_norm_w;

// signal for mantissa normalization (wire)
logic [(MANT_LEN+5)-1:0] mant_norm_w; // 15 bits, 10 bits mantissa + 5 bits GRS (3 bits for sticky bits)

// signal for pipeline sign_res for normal output (wire)
logic sign_res_sec_w;

// ========== Fourth Stage: Normalization -> Normal rounding output ===========

// signal for rounding
// For Round to nearest, ties to even
// extract GRS(Gound bit, Round bit, Sticky bit)
logic [MANT_LEN-1:0] mant_main;
logic lsb, guard_bit, round_bit, sticky_bit;

// signal for Rounding judge
logic round_up;

// signal for compute rounded mantissa
logic [(MANT_LEN+1)-1:0] mant_round; // 11 bits

// signal for final exponent/mantissa
logic is_zero_res;
logic overflow;
logic sign_final;
logic [(EXP_LEN+1)-1:0] exp_final_tmp;
logic [EXP_LEN-1:0] exp_final;
logic [MANT_LEN-1:0] mant_final;

// process for normal value
logic [FLOAT_LEN-1:0] normal_result;

// signal for specific case
logic is_nan_a, is_nan_b, is_inf_a, is_inf_b;

// process for specific value
logic [FLOAT_LEN-1:0] specific_result;

//---------------------------------------------------------------------
//   LOGIC DECLARATION FOR PIPELINE REGISTER
//---------------------------------------------------------------------

// input/output register for timing analysis
logic [FLOAT_LEN-1:0] a_w, a_r, b_w, b_r;
logic [FLOAT_LEN-1:0] result_w, result_r;

// ========== First Stage Register ===========

// separate each part of input (reg)
logic sign_a_r, sign_b_r;
logic [EXP_LEN-1:0] exp_a_r, exp_b_r;

// compare signal (reg) for combinational logic
logic sign_cmp_r, exp_cmp_ab_r, mant_cmp_r;

// signal for mantissa shifted (reg)
logic [(MANT_LEN+6)-1:0] m1_shifted_r, m2_shifted_r; // 16 bits

// ========== Second Stage Register ===========

// signal for sign, exponent, mantissa processing (reg)
logic sign_res_fir_r;

logic [EXP_LEN-1:0] exp_res_r;

logic [(MANT_LEN+7)-1:0] mant_res_r; // 17 bits, two 16 bits addition

// ========== Third Stage Register ===========

// signal for exponent normalization (reg)
logic [EXP_LEN-1:0] exp_norm_r;

// signal for mantissa normalization (reg)
logic [(MANT_LEN+5)-1:0] mant_norm_r; // 15 bits, 10 bits mantissa + 5 bits GRS (3 bits for sticky bits)

// signal for pipeline sign_res for normal output (reg)
logic sign_res_sec_r;

// =========== Specific Path ===========
logic is_nan_a_fir_w, is_nan_a_fir_r;
logic is_nan_a_sec_w, is_nan_a_sec_r;
logic is_nan_a_thr_w, is_nan_a_thr_r;

logic is_nan_b_fir_w, is_nan_b_fir_r;
logic is_nan_b_sec_w, is_nan_b_sec_r;
logic is_nan_b_thr_w, is_nan_b_thr_r;

logic is_inf_a_fir_w, is_inf_a_fir_r;
logic is_inf_a_sec_w, is_inf_a_sec_r;
logic is_inf_a_thr_w, is_inf_a_thr_r;

logic is_inf_b_fir_w, is_inf_b_fir_r;
logic is_inf_b_sec_w, is_inf_b_sec_r;
logic is_inf_b_thr_w, is_inf_b_thr_r;

logic [FLOAT_LEN-1:0] specific_result_fir_w, specific_result_fir_r;
logic [FLOAT_LEN-1:0] specific_result_sec_w, specific_result_sec_r;
logic [FLOAT_LEN-1:0] specific_result_thr_w, specific_result_thr_r;

//---------------------------------------------------------------------
//   DESIGN PART
//---------------------------------------------------------------------

// Float16 Addition
// (1) separate input to sign, exponent, mantissa
// (2) shift smaller number right to align the bigger one
// (3) mantissa addition and normalization
// (4) Round-to-Nearest-Even rounding
// (5) output result

// This module totally pipeline in four stage
// The First stage from input to compare logic, exponent subtract and barrel-shifter
// The Second stage from barrel-shifter to each signal process
// The Third stage from each signal process to normalization
// The Fourth stage from ormalization to normal rounding output

// The specific path will add three pipeline register to align normal output timing
// (Input Register -> First Pipeline -> Second Pipeline -> Third Pipeline -> Output Register)

// =============================================================
// ========== Normal process path Combinational Logic===========
// =============================================================

// ========== First Stage: Input -> Compare Logic & Exponent subtract & Barrel-shifter ===========

// separate each part of input
assign sign_a_w = a_r[15];
assign sign_b_w = b_r[15];
assign exp_a_w = a_r[14:10];
assign exp_b_w = b_r[14:10];
assign mant_a = a_r[9:0];
assign mant_b = b_r[9:0];

// the part for compare input a & b
assign sign_cmp_w = (sign_a_w == sign_b_w);
assign exp_cmp_ab_w = (exp_a_w >= exp_b_w);
assign exp_cmp_ba = (exp_b_w >= exp_a_w);
assign mant_cmp_w = (m1_shifted_w > m2_shifted_w);

// the part of exponent subtraction
assign exp_diff = exp_cmp_ab_w ? (exp_a_w - exp_b_w) : (exp_b_w - exp_a_w);

// shift amount for prevent shift over 15 bits
assign shift_amt = (exp_diff > 5'd15) ? 5'd15 : exp_diff;

// the part for barrel-shifter, align small number's mantissa to bigger one
assign m1_preshift = (exp_a_w == 0) ? {1'b0, mant_a, 5'b00000} : {1'b1, mant_a, 5'b00000};
assign m2_preshift = (exp_b_w == 0) ? {1'b0, mant_b, 5'b00000} : {1'b1, mant_b, 5'b00000};
assign m1_shifted_w = exp_cmp_ab_w ? m1_preshift : m1_preshift >> shift_amt;
assign m2_shifted_w = exp_cmp_ba ? m2_preshift : m2_preshift >> shift_amt;

// ========== Second Stage: Compare Logic & Exponent subtract & Barrel-shifter ->  ===========

// the part for sign, exponent, mantissa processing
assign sign_res_fir_w = sign_cmp_r ? sign_a_r : (mant_cmp_r ? sign_a_r : sign_b_r);

assign exp_res_w = exp_cmp_ab_r ? exp_a_r : exp_b_r;

assign mant_res_w = sign_cmp_r ? (m1_shifted_r + m2_shifted_r) : (mant_cmp_r ? m1_shifted_r - m2_shifted_r : m2_shifted_r - m1_shifted_r);

// ========== Third Stage: Each part process ->  Normalization ===========

// Normalization
    // 1x.xxxxxxxxxxxxxxx -> shift right 1 bit to 01.xxxxxxxxxxxxxxx and exp + 1
    // ==> extract [15:1]
    // 01.xxxxxxxxxxxxxxx -> maintain mantissa and maintain exponent
    // ==> extract [14:0]
    // 00.1xxxxxxxxxxxxxx -> shift left 1 bit to 01.xxxxxxxxxxxxxxx and exp - 1
    // ==> extract [13:0] and shift left 1
    // 00.01xxxxxxxxxxxxx -> shift left 2 bit to 01.xxxxxxxxxxxxxxx and exp - 2
    // ==> extract [12:0] and shift left 2
    // 00.001xxxxxxxxxxxx -> shift left 3 bit to 01.xxxxxxxxxxxxxxx and exp - 3
    // ==> extract [11:0] and shift left 3
    // 00.0001xxxxxxxxxxx -> shift left 4 bit to 01.xxxxxxxxxxxxxxx and exp - 4
    // ==> extract [10:0] and shift left 4
    //                         .
    //                         .
    //                         .
    // 00.00000000000001x -> shift left 14 bit to 01.xxxxxxxxxxxxxxx and exp - 14
    // ==> extract [0] and shift left 14

// For Round to nearest, ties to even
always_comb begin
    casez (mant_res_r)
        17'b1????????????????: mant_norm_w = mant_res_r[15:1];
        17'b01???????????????: mant_norm_w = mant_res_r[14:0];
        17'b001??????????????: mant_norm_w = mant_res_r[13:0] << 1;
        17'b0001?????????????: mant_norm_w = mant_res_r[12:0] << 2;
        17'b00001????????????: mant_norm_w = mant_res_r[11:0] << 3;
        17'b000001???????????: mant_norm_w = mant_res_r[10:0] << 4;
        17'b0000001??????????: mant_norm_w = mant_res_r[9:0] << 5;
        17'b00000001?????????: mant_norm_w = mant_res_r[8:0] << 6;
        17'b000000001????????: mant_norm_w = mant_res_r[7:0] << 7;
        17'b0000000001???????: mant_norm_w = mant_res_r[6:0] << 8;
        17'b00000000001??????: mant_norm_w = mant_res_r[5:0] << 9;
        17'b000000000001?????: mant_norm_w = mant_res_r[4:0] << 10;
        17'b0000000000001????: mant_norm_w = mant_res_r[3:0] << 11;
        17'b00000000000001???: mant_norm_w = mant_res_r[2:0] << 12;
        17'b000000000000001??: mant_norm_w = mant_res_r[1:0] << 13;
        17'b0000000000000001?: mant_norm_w = mant_res_r[0] << 14;
        default: mant_norm_w = 15'b0;
    endcase
end

always_comb begin
    casez (mant_res_r)
        17'b1????????????????: exp_norm_tmp = $signed({2'b00, exp_res_r}) + 1;
        17'b01???????????????: exp_norm_tmp = $signed({2'b00, exp_res_r});
        17'b001??????????????: exp_norm_tmp = $signed({2'b00, exp_res_r}) - 1;
        17'b0001?????????????: exp_norm_tmp = $signed({2'b00, exp_res_r}) - 2;
        17'b00001????????????: exp_norm_tmp = $signed({2'b00, exp_res_r}) - 3;
        17'b000001???????????: exp_norm_tmp = $signed({2'b00, exp_res_r}) - 4;
        17'b0000001??????????: exp_norm_tmp = $signed({2'b00, exp_res_r}) - 5;
        17'b00000001?????????: exp_norm_tmp = $signed({2'b00, exp_res_r}) - 6;
        17'b000000001????????: exp_norm_tmp = $signed({2'b00, exp_res_r}) - 7;
        17'b0000000001???????: exp_norm_tmp = $signed({2'b00, exp_res_r}) - 8;
        17'b00000000001??????: exp_norm_tmp = $signed({2'b00, exp_res_r}) - 9;
        17'b000000000001?????: exp_norm_tmp = $signed({2'b00, exp_res_r}) - 10;
        17'b0000000000001????: exp_norm_tmp = $signed({2'b00, exp_res_r}) - 11;
        17'b00000000000001???: exp_norm_tmp = $signed({2'b00, exp_res_r}) - 12;
        17'b000000000000001??: exp_norm_tmp = $signed({2'b00, exp_res_r}) - 13;
        17'b0000000000000001?: exp_norm_tmp = $signed({2'b00, exp_res_r}) - 14;
        default: exp_norm_tmp = 7'sd0;
    endcase
end

// Update exp_norm from exp_norm_tmp to detect overflow/underflow
always_comb begin
    if(exp_norm_tmp < 7'sd0) begin
        exp_norm_w = 5'd0;
    end else if(exp_norm_tmp > 7'sd31) begin
        exp_norm_w = 5'd31;
    end else begin
        exp_norm_w = exp_norm_tmp[4:0];
    end
end

// pipeline sign_res for normal output
assign sign_res_sec_w = sign_res_fir_r;

// ========== Fourth Stage: Normalization -> Normal rounding output ===========

// Rounding: Round-to-Nearest-Even
// Extract GRS(Gound bit, Round bit, Sticky bit)
assign mant_main = mant_norm_r[14:5];
assign lsb = mant_norm_r[5];
assign guard_bit = mant_norm_r[4];
assign round_bit = mant_norm_r[3];
assign sticky_bit = | mant_norm_r[2:0];

// Round-to-Nearest-Even judge
// GR = 11 or GRS = 101 or LGRS = 1100
assign round_up = ((guard_bit && round_bit) || (guard_bit && ~round_bit && sticky_bit) || (lsb && guard_bit && ~round_bit && ~sticky_bit));

// Compute rounded mantissa
assign mant_round = mant_main + round_up;

// Compute final exponent/mantissa
assign overflow = mant_round[10];
assign exp_final_tmp = (overflow) ? exp_norm_r + 1 : exp_norm_r;
assign exp_final = (exp_final_tmp > 6'd31) ? 5'd31 : exp_final_tmp;
assign mant_final = mant_round[9:0];

// check special case a + b = 0
assign is_zero_res = (exp_final == 5'd0 && mant_final == 10'd0);
assign sign_final = (is_zero_res) ? 1'b0 : sign_res_sec_r;

// normal result output
assign normal_result = {sign_final, exp_final, mant_final};

// ===========================================================
// ========== Normal process path Pipeline Register===========
// ===========================================================

// input/output register
assign a_w = a;
assign b_w = b;
assign result = result_r;

// procedure block for module's pipeline
always_ff @ (posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        // input/output register
        a_r <= 16'h0000;
        b_r <= 16'h0000;
        result_r <= 16'h0000;

        // First Stage Register
        sign_a_r <= 1'b0;
        sign_b_r <= 1'b0;
        exp_a_r <= 5'b0;
        exp_b_r <= 5'b0;

        sign_cmp_r <= 1'b0;
        exp_cmp_ab_r <= 1'b0;
        mant_cmp_r <= 1'b0;

        m1_shifted_r <= 16'b0;
        m2_shifted_r <= 16'b0;

        // Second Stage Register
        sign_res_fir_r <= 1'b0;
        exp_res_r <= 5'b0;
        mant_res_r <= 17'b0;

        // Third Stage Register
        exp_norm_r <= 5'b0;
        mant_norm_r <= 15'b0;
        sign_res_sec_r <= 1'b0;
    end else begin
        // input/output register
        a_r <= a_w;
        b_r <= b_w;
        result_r <= result_w;

        // First Stage Register
        sign_a_r <= sign_a_w;
        sign_b_r <= sign_b_w;
        exp_a_r <= exp_a_w;
        exp_b_r <= exp_b_w;

        sign_cmp_r <= sign_cmp_w;
        exp_cmp_ab_r <= exp_cmp_ab_w;
        mant_cmp_r <= mant_cmp_w;

        m1_shifted_r <= m1_shifted_w;
        m2_shifted_r <= m2_shifted_w;

        // Second Stage Register
        sign_res_fir_r <= sign_res_fir_w;
        exp_res_r <= exp_res_w;
        mant_res_r <= mant_res_w;

        // Third Stage Register
        exp_norm_r <= exp_norm_w;
        mant_norm_r <= mant_norm_w;
        sign_res_sec_r <= sign_res_sec_w;
    end
end

// ===============================================================
// ========== Specific process path Combinational Logic===========
// ===============================================================

// ********** Add three pipeline register to align normal output **********

// signal for specific case
assign is_nan_a = (exp_a_w == 5'h1F) && (mant_a != 0);
assign is_nan_b = (exp_b_w == 5'h1F) && (mant_b != 0);
assign is_inf_a = (exp_a_w == 5'h1F) && (mant_a == 0);
assign is_inf_b = (exp_b_w == 5'h1F) && (mant_b == 0);

// process for specific value
always_comb begin
    if(is_nan_a || is_nan_b)
        specific_result = 16'h7E00; // 0, 11111, 1000000000
    else if(is_inf_a && is_inf_b && (sign_a_w != sign_b_w))
        specific_result = 16'h7E00;
    else if(is_inf_a)
        specific_result = a_r;
    else if(is_inf_b)
        specific_result = b_r;
    else
        specific_result = 16'h0000;
end

// ===============================================================
// ========== Specific process path Pipeline Register===========
// ===============================================================

// Three stage pipeline to align normal result
assign is_nan_a_fir_w = is_nan_a;
assign is_nan_a_sec_w = is_nan_a_fir_r;
assign is_nan_a_thr_w = is_nan_a_sec_r;

assign is_nan_b_fir_w = is_nan_b;
assign is_nan_b_sec_w = is_nan_b_fir_r;
assign is_nan_b_thr_w = is_nan_b_sec_r;

assign is_inf_a_fir_w = is_inf_a;
assign is_inf_a_sec_w = is_inf_a_fir_r;
assign is_inf_a_thr_w = is_inf_a_sec_r;

assign is_inf_b_fir_w = is_inf_b;
assign is_inf_b_sec_w = is_inf_b_fir_r;
assign is_inf_b_thr_w = is_inf_b_sec_r;

assign specific_result_fir_w = specific_result;
assign specific_result_sec_w = specific_result_fir_r;
assign specific_result_thr_w = specific_result_sec_r;

always_ff @ (posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        is_nan_a_fir_r <= 1'b0;
        is_nan_a_sec_r <= 1'b0;
        is_nan_a_thr_r <= 1'b0;

        is_nan_b_fir_r <= 1'b0;
        is_nan_b_sec_r <= 1'b0;
        is_nan_b_thr_r <= 1'b0;

        is_inf_a_fir_r <= 1'b0;
        is_inf_a_sec_r <= 1'b0;
        is_inf_a_thr_r <= 1'b0;

        is_inf_b_fir_r <= 1'b0;
        is_inf_b_sec_r <= 1'b0;
        is_inf_b_thr_r <= 1'b0;

        specific_result_fir_r <= 16'h0000;
        specific_result_sec_r <= 16'h0000;
        specific_result_thr_r <= 16'h0000;
    end else begin
        is_nan_a_fir_r <= is_nan_a_fir_w;
        is_nan_a_sec_r <= is_nan_a_sec_w;
        is_nan_a_thr_r <= is_nan_a_thr_w;

        is_nan_b_fir_r <= is_nan_b_fir_w;
        is_nan_b_sec_r <= is_nan_b_sec_w;
        is_nan_b_thr_r <= is_nan_b_thr_w;

        is_inf_a_fir_r <= is_inf_a_fir_w;
        is_inf_a_sec_r <= is_inf_a_sec_w;
        is_inf_a_thr_r <= is_inf_a_thr_w;

        is_inf_b_fir_r <= is_inf_b_fir_w;
        is_inf_b_sec_r <= is_inf_b_sec_w;
        is_inf_b_thr_r <= is_inf_b_thr_w;

        specific_result_fir_r <= specific_result_fir_w;
        specific_result_sec_r <= specific_result_sec_w;
        specific_result_thr_r <= specific_result_thr_w;
    end
end

// &&&&&&&&&& Final Output Path &&&&&&&&&&

assign result_w = (is_nan_a_thr_r || is_nan_b_thr_r || is_inf_a_thr_r || is_inf_b_thr_r) ? specific_result_thr_r : normal_result;


endmodule