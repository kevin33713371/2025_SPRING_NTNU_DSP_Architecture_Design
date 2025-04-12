module float16_adder(
    // Input Signal
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
input [FLOAT_LEN-1:0] a, b;
output logic [FLOAT_LEN-1:0] result;

//---------------------------------------------------------------------
//   LOGIC DECLARATION
//---------------------------------------------------------------------
// separate each part of input
logic sign_a, sign_b;
logic [EXP_LEN-1:0] exp_a, exp_b;
logic [MANT_LEN-1:0] mant_a, mant_b;

// signal for specific case
logic is_nan_a, is_nan_b, is_inf_a, is_inf_b;

// process for specifi/normal value
logic [FLOAT_LEN-1:0] specific_result;
logic [FLOAT_LEN-1:0] normal_result;

// signal for normal process path
logic sign_res;
logic [EXP_LEN-1:0] exp_diff, exp_res_base;
// {1'b1, mantissa(10 bits), guard bit(1'b0), round bit(1'b0), sticky bits(3'b0)} => 16 bits
logic [(MANT_LEN+6)-1:0] m1_preshift, m2_preshift; // 16 bits
logic [(MANT_LEN+6)-1:0] m1_shifted, m2_shifted; // 16 bits
logic [(MANT_LEN+7)-1:0] mant_res; // 17 bits, two 16 bits addition

// internal signal for combinational logic
logic sign_cmp, exp_cmp_ab, exp_cmp_ba, mant_cmp;

// signal for normalization
logic [EXP_LEN-1:0] exp_norm;
logic [(MANT_LEN+5)-1:0] mant_norm; // 15 bits, 10 bits mantissa + 5 bits GRS (3 bits for sticky bits)

// signal for rounding
// extract GRS(Gound bit, Round bit, Sticky bit)
logic [MANT_LEN-1:0] mant_main;
logic lsb, guard_bit, round_bit, sticky_bit;

// signal for Round-to-Nearest-Even judge
logic round_up;

// signal for compute rounded mantissa
logic [(MANT_LEN+1)-1:0] mant_round; // 11 bits

// signal for final exponent/mantissa
logic [EXP_LEN-1:0] exp_final;
logic [MANT_LEN-1:0] mant_final;

//---------------------------------------------------------------------
//   DESIGN PART
//---------------------------------------------------------------------

// Float16 Addition
// (1) separate input to sign, exponent, mantissa
// (2) shift smaller number right to align the bigger one
// (3) mantissa addition and normalization
// (4) Round-to-Nearest-Even rounding
// (5) output result

// separate each part of input
assign sign_a = a[15];
assign sign_b = b[15];
assign exp_a = a[14:10];
assign exp_b = b[14:10];
assign mant_a = a[9:0];
assign mant_b = b[9:0];

// signal for specific case
assign is_nan_a = (exp_a == 5'h1F) && (mant_a != 0);
assign is_nan_b = (exp_b == 5'h1F) && (mant_b != 0);
assign is_inf_a = (exp_a == 5'h1F) && (mant_a == 0);
assign is_inf_b = (exp_b == 5'h1F) && (mant_b == 0);

// process for specific value
always_comb begin
    if(is_nan_a || is_nan_b)
        specific_result = 16'h7E00; // 0, 11111, 1000000000
    else if(is_inf_a && is_inf_b && (sign_a != sign_b))
        specific_result = 16'h7E00;
    else if(is_inf_a)
        specific_result = a;
    else if(is_inf_b)
        specific_result = b;
    else
        specific_result = 16'h0000;
end

// Normal process path
// {1'b1, mantissa(10 bits), guard bit(1 bit), round bit(1 bit), sticky bit(3 bits)} --> 16 bits
assign sign_cmp = (sign_a == sign_b);
assign exp_cmp_ab = (exp_a >= exp_b);
assign exp_cmp_ba = (exp_b >= exp_a);
assign mant_cmp = (m1_shifted > m2_shifted);

assign sign_res = sign_cmp ? sign_a : (mant_cmp ? sign_a : sign_b);

assign exp_diff = exp_cmp_ab ? (exp_a - exp_b) : (exp_b - exp_a);
assign exp_res_base = exp_cmp_ab ? exp_a : exp_b;

assign m1_preshift = (exp_a == 0) ? {1'b0, mant_a, 5'b00000} : {1'b1, mant_a, 5'b00000};
assign m2_preshift = (exp_b == 0) ? {1'b0, mant_b, 5'b00000} : {1'b1, mant_b, 5'b00000};
assign m1_shifted = exp_cmp_ab ? m1_preshift : m1_preshift >> exp_diff;
assign m2_shifted = exp_cmp_ba ? m2_preshift : m2_preshift >> exp_diff;
assign mant_res = sign_cmp ? (m1_shifted + m2_shifted) : (mant_cmp ? m1_shifted - m2_shifted : m2_shifted - m1_shifted);

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

always_comb begin
    casez (mant_res)
        17'b1????????????????: mant_norm = mant_res[15:1];
        17'b01???????????????: mant_norm = mant_res[14:0];
        17'b001??????????????: mant_norm = mant_res[13:0] << 1;
        17'b0001?????????????: mant_norm = mant_res[12:0] << 2;
        17'b00001????????????: mant_norm = mant_res[11:0] << 3;
        17'b000001???????????: mant_norm = mant_res[10:0] << 4;
        17'b0000001??????????: mant_norm = mant_res[9:0] << 5;
        17'b00000001?????????: mant_norm = mant_res[8:0] << 6;
        17'b000000001????????: mant_norm = mant_res[7:0] << 7;
        17'b0000000001???????: mant_norm = mant_res[6:0] << 8;
        17'b00000000001??????: mant_norm = mant_res[5:0] << 9;
        17'b000000000001?????: mant_norm = mant_res[4:0] << 10;
        17'b0000000000001????: mant_norm = mant_res[3:0] << 11;
        17'b00000000000001???: mant_norm = mant_res[2:0] << 12;
        17'b000000000000001??: mant_norm = mant_res[1:0] << 13;
        17'b0000000000000001?: mant_norm = mant_res[0] << 14;
        default: mant_norm = 15'b0;
    endcase
end

always_comb begin
    casez (mant_res)
        17'b1????????????????: exp_norm = exp_res_base + 1;
        17'b01???????????????: exp_norm = exp_res_base;
        17'b001??????????????: exp_norm = exp_res_base - 1;
        17'b0001?????????????: exp_norm = exp_res_base - 2;
        17'b00001????????????: exp_norm = exp_res_base - 3;
        17'b000001???????????: exp_norm = exp_res_base - 4;
        17'b0000001??????????: exp_norm = exp_res_base - 5;
        17'b00000001?????????: exp_norm = exp_res_base - 6;
        17'b000000001????????: exp_norm = exp_res_base - 7;
        17'b0000000001???????: exp_norm = exp_res_base - 8;
        17'b00000000001??????: exp_norm = exp_res_base - 9;
        17'b000000000001?????: exp_norm = exp_res_base - 10;
        17'b0000000000001????: exp_norm = exp_res_base - 11;
        17'b00000000000001???: exp_norm = exp_res_base - 12;
        17'b000000000000001??: exp_norm = exp_res_base - 13;
        17'b0000000000000001?: exp_norm = exp_res_base - 14;
        default: exp_norm = 5'b0;
    endcase
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

// nornal result output
assign normal_result = {sign_res, exp_final, mant_final};
assign result = (is_nan_a || is_nan_b || is_inf_a || is_inf_b) ? specific_result : normal_result;


endmodule