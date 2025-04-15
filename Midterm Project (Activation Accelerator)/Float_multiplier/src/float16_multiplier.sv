module float16_multiplier(
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

// signal for special case detection
logic is_nan_a, is_nan_b, is_inf_a, is_inf_b, is_zero_a, is_zero_b;

// signal for normal process path
logic sign_res;
logic [EXP_LEN-1:0] exp_val_a, exp_val_b;
logic [EXP_LEN-1:0] exp_res;
logic [(MANT_LEN+1)-1:0] mant_a_ext, mant_b_ext;
logic [((MANT_LEN+1)*2)-1:0] mant_res; // 22 bits, two 11 bits multiplication

// signal for normalization
logic [EXP_LEN-1:0] exp_norm;
logic [EXP_LEN-1:0] exp_norm_tmp;
logic [((MANT_LEN+1)*2)-1:0] mant_norm; // 22 bits

// signal for rounding
// extract GRS(Gound bit, Round bit, Sticky bit)
logic [MANT_LEN-1:0] mant_main;
logic lsb, guard_bit, round_bit, sticky_bit;

// signal for Round-to-Nearest-Even judge
logic round_up;

// signal for compute rounded mantissa
logic [(MANT_LEN+1)-1:0] mant_round; // 11 bits

// process for specifi/normal value
logic [FLOAT_LEN-1:0] specific_result;
logic [FLOAT_LEN-1:0] normal_result;

// signal for final exponent/mantissa
logic [EXP_LEN-1:0] exp_final;
logic [EXP_LEN-1:0] exp_final_tmp;
logic [MANT_LEN-1:0] mant_final;

//---------------------------------------------------------------------
//   DESIGN PART
//---------------------------------------------------------------------

// Float16 Multiplication
// (1) separate input to sign, exponent, mantissa
// (2) exponent computation: two exponent addition and subtract bias
//     exp_mul = exp_a + exp_b - bias(2^(5-1)-1 = 15)
// (3) mantissa multiplication and normalization
// (4) Round-to-Nearest-Even rounding
// (5) output result

// separate each part of input
assign sign_a = a[15];
assign sign_b = b[15];
assign exp_a = a[14:10];
assign exp_b = b[14:10];
assign mant_a = a[9:0];
assign mant_b = b[9:0];

// special case detection
assign is_nan_a = (exp_a == 5'b11111) && (mant_a != 0);
assign is_nan_b = (exp_b == 5'b11111) && (mant_b != 0);
assign is_inf_a = (exp_a == 5'b11111) && (mant_a == 0);
assign is_inf_b = (exp_b == 5'b11111) && (mant_b == 0);
assign is_zero_a = (exp_a == 0) && (mant_a == 0);
assign is_zero_b = (exp_b == 0) && (mant_b == 0);

// Normal process path
assign sign_res = sign_a ^ sign_b;

// exponent = 0 for subnormal
assign exp_val_a = (exp_a == 0) ? 1 : exp_a;
assign exp_val_b = (exp_b == 0) ? 1 : exp_b;
assign exp_res = exp_val_a + exp_val_b - 5'd15;

assign mant_a_ext = (exp_a == 0) ? {1'b0, mant_a} : {1'b1, mant_a};
assign mant_b_ext = (exp_b == 0) ? {1'b0, mant_b} : {1'b1, mant_b};
assign mant_res = mant_a_ext * mant_b_ext;

// Normalization
// always_comb begin
//     if(mant_res[21]) begin
//         mant_norm = mant_res >> 1;
//     end else begin
//         mant_norm = mant_res;
//     end
// end

// always_comb begin
//     if(mant_res[21]) begin
//         exp_norm = exp_res + 1;
//     end else begin
//         exp_norm = exp_res;
//     end
// end

always_comb begin
    casez(mant_res)
        22'b1?????????????????????: mant_norm = mant_res >> 1;
        22'b01????????????????????: mant_norm = mant_res;
        22'b001???????????????????: mant_norm = mant_res << 1;
        22'b0001??????????????????: mant_norm = mant_res << 2;
        22'b00001?????????????????: mant_norm = mant_res << 3;
        22'b000001????????????????: mant_norm = mant_res << 4;
        22'b0000001???????????????: mant_norm = mant_res << 5;
        22'b00000001??????????????: mant_norm = mant_res << 6;
        22'b000000001?????????????: mant_norm = mant_res << 7;
        22'b0000000001????????????: mant_norm = mant_res << 8;
        22'b00000000001???????????: mant_norm = mant_res << 9;
        22'b000000000001??????????: mant_norm = mant_res << 10;
        default: mant_norm = mant_res << 11;
    endcase
end

always_comb begin
    casez(mant_res)
        22'b1?????????????????????: exp_norm_tmp = exp_res + 1;
        22'b01????????????????????: exp_norm_tmp = exp_res;
        22'b001???????????????????: exp_norm_tmp = exp_res - 1;
        22'b0001??????????????????: exp_norm_tmp = exp_res - 2;
        22'b00001?????????????????: exp_norm_tmp = exp_res - 3;
        22'b000001????????????????: exp_norm_tmp = exp_res - 4;
        22'b0000001???????????????: exp_norm_tmp = exp_res - 5;
        22'b00000001??????????????: exp_norm_tmp = exp_res - 6;
        22'b000000001?????????????: exp_norm_tmp = exp_res - 7;
        22'b0000000001????????????: exp_norm_tmp = exp_res - 8;
        22'b00000000001???????????: exp_norm_tmp = exp_res - 9;
        22'b000000000001??????????: exp_norm_tmp = exp_res - 10;
        default: exp_norm_tmp = exp_res - 11;
    endcase
end

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
assign mant_main = mant_norm[21:12];
assign lsb = mant_norm[12];
assign guard_bit = mant_norm[11];
assign round_bit = mant_norm[10];
assign sticky_bit = | mant_norm[9:0];

// Round-to-Nearest-Even judge
// GR = 11 or GRS = 101 or LGRS = 1100
assign round_up = ((guard_bit && round_bit) || (guard_bit && ~round_bit && sticky_bit) || (lsb && guard_bit && ~round_bit && ~sticky_bit));

// Compute rounded mantissa
assign mant_round = mant_main + round_up;

// Compute final exponent/mantissa
assign exp_final_tmp = (mant_round[10]) ? exp_norm + 1 : exp_norm;
assign exp_final = (exp_final_tmp > 5'd31) ? 5'd31 : exp_final_tmp;
assign mant_final = (mant_round[10]) ? mant_round[10:1] : mant_round[9:0];

// normal result output
assign normal_result = (exp_final > 5'd31) ? {sign_res, 5'h1F, 10'h000} :{sign_res, exp_final, mant_final};

// process for specific value
always_comb begin
    if(is_nan_a || is_nan_b || (is_inf_a && is_zero_b) || (is_zero_a && is_inf_b)) begin
        specific_result = {sign_res, 5'h1F, 10'h200}; // NaN
    end else if(is_inf_a || is_inf_b) begin
        specific_result = {sign_res, 5'h1F, 10'h000}; // Inf
    end else if(is_zero_a || is_zero_b) begin
        specific_result = {sign_res, 5'h00, 10'h000};
    end else begin
        specific_result = 16'h0000;
    end
end

// output result process
assign result = (is_nan_a || is_nan_b || (is_inf_a && is_zero_b) || (is_zero_a && is_inf_b) ||
                 is_inf_a || is_inf_b || is_zero_a || is_zero_b) ? specific_result : normal_result;

endmodule