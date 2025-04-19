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
//   LOGIC DECLARATION
//---------------------------------------------------------------------
// separate each part of input
logic sign_a, sign_b;
logic [EXP_LEN-1:0] exp_a, exp_b;
logic [MANT_LEN-1:0] mant_a, mant_b;

// internal signal for combinational logic
logic sign_cmp_w, sign_cmp_r;
logic exp_cmp_ab, exp_cmp_ba;
logic mant_cmp_w, mant_cmp_r;

// signal for normal process path
logic sign_res_fir_w, sign_res_fir_r;
logic sign_res_sec_w, sign_res_sec_r;
logic [EXP_LEN-1:0] exp_diff;
logic [EXP_LEN-1:0] exp_res_fir_w, exp_res_fir_r;
logic [EXP_LEN-1:0] exp_res_sec_w, exp_res_sec_r;

// For Round to nearest, ties to even
// {1'b1, mantissa(10 bits), guard bit(1'b0), round bit(1'b0), sticky bits(3'b0)} => 16 bits
// (w for wire, r for pipeline reg)
logic [(MANT_LEN+6)-1:0] m1_preshift, m2_preshift; // 16 bits
logic [(MANT_LEN+6)-1:0] m1_shifted_w, m2_shifted_w; // 16 bits
logic [(MANT_LEN+6)-1:0] m1_shifted_r, m2_shifted_r; // 16 bits

logic [(MANT_LEN+7)-1:0] mant_res_w, mant_res_r; // 17 bits, two 16 bits addition

// signal for normalization
logic [EXP_LEN-1:0] exp_norm_tmp;
logic [EXP_LEN-1:0] exp_norm;

// For Round to nearest, ties to even
logic [(MANT_LEN+5)-1:0] mant_norm; // 15 bits, 10 bits mantissa + 5 bits GRS (3 bits for sticky bits)

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
logic [EXP_LEN-1:0] exp_final;
logic [MANT_LEN-1:0] mant_final;

// process for normal value
logic [FLOAT_LEN-1:0] normal_result;

// signal for specific case
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

// process for specific value
logic [FLOAT_LEN-1:0] specific_result_fir_w, specific_result_fir_r;
logic [FLOAT_LEN-1:0] specific_result_sec_w, specific_result_sec_r;
logic [FLOAT_LEN-1:0] specific_result_thr_w;

//---------------------------------------------------------------------
//   DESIGN PART
//---------------------------------------------------------------------

// Float16 Addition
// (1) separate input to sign, exponent, mantissa
// (2) shift smaller number right to align the bigger one
// (3) mantissa addition and normalization
// (4) Round-to-Nearest-Even rounding
// (5) output result

// This module totally pipeline in three stage
// The First stage from input to barrel-shifter
// The Second stage from barrel-shifter to mantissa addition
// The Third stage from mantissa addition to normal output

// The specific path will add two pipeline register to align normal output timing

// ========== Normal process path ===========

// ========== First Stage: Input -> Barrel-shifter ===========

// separate each part of input
assign sign_a = a[15];
assign sign_b = b[15];
assign exp_a = a[14:10];
assign exp_b = b[14:10];
assign mant_a = a[9:0];
assign mant_b = b[9:0];

// For Round to nearest, ties to even
// {1'b1, mantissa(10 bits), guard bit(1 bit), round bit(1 bit), sticky bit(3 bits)} --> 16 bits

// the part for compare input a & b
assign sign_cmp_w = (sign_a == sign_b);
assign exp_cmp_ab = (exp_a >= exp_b);
assign exp_cmp_ba = (exp_b >= exp_a);
assign mant_cmp_w = (m1_shifted_w > m2_shifted_w);

// the part for sign, exponent, mantissa processing
assign sign_res_fir_w = sign_cmp_w ? sign_a : (mant_cmp_w ? sign_a : sign_b);

assign exp_diff = exp_cmp_ab ? (exp_a - exp_b) : (exp_b - exp_a);
assign exp_res_fir_w = exp_cmp_ab ? exp_a : exp_b;

// the part for barrel-shifter, align small number's mantissa to bigger one
assign m1_preshift = (exp_a == 0) ? {1'b0, mant_a, 5'b00000} : {1'b1, mant_a, 5'b00000};
assign m2_preshift = (exp_b == 0) ? {1'b0, mant_b, 5'b00000} : {1'b1, mant_b, 5'b00000};
assign m1_shifted_w = exp_cmp_ab ? m1_preshift : m1_preshift >> exp_diff;
assign m2_shifted_w = exp_cmp_ba ? m2_preshift : m2_preshift >> exp_diff;

// ********** First Stage to Second Stage: shifted number pipeline **********

// pipeline for reduce cirtical path latency
pip_reg1 PIP_FIR(
    .clk(clk),
    .rst_n(rst_n),

    .sign_cmp_w         (sign_cmp_w     ),
    .mant_cmp_w         (mant_cmp_w     ),
    .sign_res_fir_w     (sign_res_fir_w ),
    .exp_res_fir_w      (exp_res_fir_w  ),
    .m1_shifted_w       (m1_shifted_w   ),
    .m2_shifted_w       (m2_shifted_w   ),

    .sign_cmp_r         (sign_cmp_r     ),
    .mant_cmp_r         (mant_cmp_r     ),
    .sign_res_fir_r     (sign_res_fir_r ),
    .exp_res_fir_r      (exp_res_fir_r  ),
    .m1_shifted_r       (m1_shifted_r   ),
    .m2_shifted_r       (m2_shifted_r   )
);

// ========== Second Stage: Barrel-shifter -> Mantissa Addition ===========

assign mant_res_w = sign_cmp_r ? (m1_shifted_r + m2_shifted_r) : (mant_cmp_r ? m1_shifted_r - m2_shifted_r : m2_shifted_r - m1_shifted_r);
assign sign_res_sec_w = sign_res_fir_r;
assign exp_res_sec_w = exp_res_fir_r;

// ********** Second Stage to Third Stage: mantissa result pipeline **********

// pipeline for reduce cirtical path latency
pip_reg2 PIP_SEC(
    .clk(clk),
    .rst_n(rst_n),

    .sign_res_sec_w     (sign_res_sec_w ),
    .exp_res_sec_w      (exp_res_sec_w  ),
    .mant_res_w         (mant_res_w ),

    .sign_res_sec_r     (sign_res_sec_r ),
    .exp_res_sec_r      (exp_res_sec_r  ),
    .mant_res_r         (mant_res_r )
);

// ========== Third Stage: Mantissa Addition ->  Normal Output ===========

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
        17'b1????????????????: mant_norm = mant_res_r[15:1];
        17'b01???????????????: mant_norm = mant_res_r[14:0];
        17'b001??????????????: mant_norm = mant_res_r[13:0] << 1;
        17'b0001?????????????: mant_norm = mant_res_r[12:0] << 2;
        17'b00001????????????: mant_norm = mant_res_r[11:0] << 3;
        17'b000001???????????: mant_norm = mant_res_r[10:0] << 4;
        17'b0000001??????????: mant_norm = mant_res_r[9:0] << 5;
        17'b00000001?????????: mant_norm = mant_res_r[8:0] << 6;
        17'b000000001????????: mant_norm = mant_res_r[7:0] << 7;
        17'b0000000001???????: mant_norm = mant_res_r[6:0] << 8;
        17'b00000000001??????: mant_norm = mant_res_r[5:0] << 9;
        17'b000000000001?????: mant_norm = mant_res_r[4:0] << 10;
        17'b0000000000001????: mant_norm = mant_res_r[3:0] << 11;
        17'b00000000000001???: mant_norm = mant_res_r[2:0] << 12;
        17'b000000000000001??: mant_norm = mant_res_r[1:0] << 13;
        17'b0000000000000001?: mant_norm = mant_res_r[0] << 14;
        default: mant_norm = 15'b0;
    endcase
end

always_comb begin
    casez (mant_res_r)
        17'b1????????????????: exp_norm_tmp = exp_res_sec_r + 1;
        17'b01???????????????: exp_norm_tmp = exp_res_sec_r;
        17'b001??????????????: exp_norm_tmp = exp_res_sec_r - 1;
        17'b0001?????????????: exp_norm_tmp = exp_res_sec_r - 2;
        17'b00001????????????: exp_norm_tmp = exp_res_sec_r - 3;
        17'b000001???????????: exp_norm_tmp = exp_res_sec_r - 4;
        17'b0000001??????????: exp_norm_tmp = exp_res_sec_r - 5;
        17'b00000001?????????: exp_norm_tmp = exp_res_sec_r - 6;
        17'b000000001????????: exp_norm_tmp = exp_res_sec_r - 7;
        17'b0000000001???????: exp_norm_tmp = exp_res_sec_r - 8;
        17'b00000000001??????: exp_norm_tmp = exp_res_sec_r - 9;
        17'b000000000001?????: exp_norm_tmp = exp_res_sec_r - 10;
        17'b0000000000001????: exp_norm_tmp = exp_res_sec_r - 11;
        17'b00000000000001???: exp_norm_tmp = exp_res_sec_r - 12;
        17'b000000000000001??: exp_norm_tmp = exp_res_sec_r - 13;
        17'b0000000000000001?: exp_norm_tmp = exp_res_sec_r - 14;
        default: exp_norm_tmp = 5'b0;
    endcase
end

// Update exp_norm from exp_norm_tmp to detect overflow/underflow
always_comb begin
    if(exp_norm_tmp < 0) begin
        exp_norm = 5'd0;
    end else if(exp_norm_tmp > 31) begin
        exp_norm = 5'd31;
    end else begin
        exp_norm = exp_norm_tmp;
    end
end

// Rounding: Round-to-Nearest-Even
// Extract GRS(Gound bit, Round bit, Sticky bit)
assign mant_main = mant_norm[14:5];
assign lsb = mant_norm[5];
assign guard_bit = mant_norm[4];
assign round_bit = mant_norm[3];
assign sticky_bit = | mant_norm[2:0];

// Round-to-Nearest-Even judge
// GR = 11 or GRS = 101 or LGRS = 1100
assign round_up = ((guard_bit && round_bit) || (guard_bit && ~round_bit && sticky_bit) || (lsb && guard_bit && ~round_bit && ~sticky_bit));

// Compute rounded mantissa
assign mant_round = mant_main + round_up;

// Compute final exponent/mantissa
assign exp_final = (mant_round[10]) ? exp_norm + 1 : exp_norm;
assign mant_final = (mant_round[10]) ? mant_round[10:1] : mant_round[9:0];

// normal result output
assign normal_result = {sign_res_sec_r, exp_final, mant_final};

// ========== Specific process path ===========
// ********** Add two pipeline register to align normal output **********

// signal for specific case
assign is_nan_a_fir_w = (exp_a == 5'h1F) && (mant_a != 0);
assign is_nan_b_fir_w = (exp_b == 5'h1F) && (mant_b != 0);
assign is_inf_a_fir_w = (exp_a == 5'h1F) && (mant_a == 0);
assign is_inf_b_fir_w = (exp_b == 5'h1F) && (mant_b == 0);

// process for specific value
always_comb begin
    if(is_nan_a_fir_w || is_nan_b_fir_w)
        specific_result_fir_w = 16'h7E00; // 0, 11111, 1000000000
    else if(is_inf_a_fir_w && is_inf_b_fir_w && (sign_a != sign_b))
        specific_result_fir_w = 16'h7E00;
    else if(is_inf_a_fir_w)
        specific_result_fir_w = a;
    else if(is_inf_b_fir_w)
        specific_result_fir_w = b;
    else
        specific_result_fir_w = 16'h0000;
end

// Two stage pipeline to align normal result
always_ff @ (posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        is_nan_a_fir_r  <= 1'b0;
        is_nan_b_fir_r  <= 1'b0;
        is_inf_a_fir_r  <= 1'b0;
        is_inf_b_fir_r  <= 1'b0;
    end else begin
        is_nan_a_fir_r  <= is_nan_a_fir_w;
        is_nan_b_fir_r  <= is_nan_b_fir_w;
        is_inf_a_fir_r  <= is_inf_a_fir_w;
        is_inf_b_fir_r  <= is_inf_b_fir_w;
    end
end

always_comb begin
    is_nan_a_sec_w  = is_nan_a_fir_r;
    is_nan_b_sec_w  = is_nan_b_fir_r;
    is_inf_a_sec_w  = is_inf_a_fir_r;
    is_inf_b_sec_w  = is_inf_b_fir_r;
end

always_ff @ (posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        is_nan_a_sec_r  <= 1'b0;
        is_nan_b_sec_r  <= 1'b0;
        is_inf_a_sec_r  <= 1'b0;
        is_inf_b_sec_r  <= 1'b0;
    end else begin
        is_nan_a_sec_r  <= is_nan_a_sec_w;
        is_nan_b_sec_r  <= is_nan_b_sec_w;
        is_inf_a_sec_r  <= is_inf_a_sec_w;
        is_inf_b_sec_r  <= is_inf_b_sec_w;
    end
end

always_comb begin
    is_nan_a_thr_w  = is_nan_a_sec_r;
    is_nan_b_thr_w  = is_nan_b_sec_r;
    is_inf_a_thr_w  = is_inf_a_sec_r;
    is_inf_b_thr_w  = is_inf_b_sec_r;
end

// First pipeline register
always_ff @ (posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        specific_result_fir_r <= 16'b0;
    end else begin
        specific_result_fir_r <= specific_result_fir_w;
    end
end

// First stage -> Second stage
assign specific_result_sec_w = specific_result_fir_r;

// Second pipeline register
always_ff @ (posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        specific_result_sec_r <= 16'b0;
    end else begin
        specific_result_sec_r <= specific_result_sec_w;
    end
end

// First stage -> Second stage
assign specific_result_thr_w = specific_result_sec_r;

// &&&&&&&&&& Final Output Path &&&&&&&&&&

assign result = (is_nan_a_thr_w || is_nan_b_thr_w || is_inf_a_thr_w || is_inf_b_thr_w) ? specific_result_thr_w : normal_result;


endmodule