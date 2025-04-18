module log_scale_mul_div (
    // Input Signals
    clk,
    rst_n,
    a,
    b,
    mul_or_div,
    lut_wr_en,
    log2_lut_data_in0,
    log2_lut_data_in1,
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

input [FLOAT_LEN-1:0] a,b;
input mul_or_div;
output logic [FLOAT_LEN-1:0] result;

input lut_wr_en;
input [FLOAT_LEN-1:0] log2_lut_data_in0, log2_lut_data_in1, exp2_lut_data_in;
//---------------------------------------------------------------------
//   LOGIC DECLARATION
//---------------------------------------------------------------------
// Look Up Table for Log 2 Function
// (* ram_style = "block", infer_ram_style = "block" *) logic [FLOAT_LEN-1:0] log2_lut0 [0:LUT_SIZE-1];
// (* ram_style = "block", infer_ram_style = "block" *) logic [FLOAT_LEN-1:0] log2_lut1 [0:LUT_SIZE-1];
logic [FLOAT_LEN-1:0] log2_lut0 [0:LUT_SIZE-1];
logic [FLOAT_LEN-1:0] log2_lut1 [0:LUT_SIZE-1];

// Look Up Table for 2 scale Function
// (* ram_style = "block", infer_ram_style = "block" *) logic [FLOAT_LEN-1:0] exp2_lut [0:LUT_SIZE-1];
logic [FLOAT_LEN-1:0] exp2_lut [0:LUT_SIZE-1];

// write pointer for handling Look Up Table input
logic [$clog2(LUT_SIZE)-1:0] lut_wr_ptr;

// Flag for Look Up Table write done
logic lut_wr_done;

// separate each part of input
logic sign_a, sign_b;
logic [EXP_LEN-1:0] exp_a_raw, exp_b_raw;
logic [MANT_LEN-1:0] mant_a, mant_b;

// Logic for log2 Look Up Table Address
logic [$clog2(LUT_SIZE)-1:0] log2_idx_a, log2_idx_b;

// Logic for log2-value after look up
logic [FLOAT_LEN-1:0] log2_val_a, log2_val_b;

// Exponent value of unbias exponent
logic [EXP_LEN-1:0] exp_a, exp_b;

// Logic for log2 real number (w for wire, r for pipeline reg)
logic [FLOAT_LEN-1:0] log2_a_full_w, log2_b_full_w;
logic [FLOAT_LEN-1:0] log2_a_full_r, log2_b_full_r;

// Logic for log2 modified number of b
logic [FLOAT_LEN-1:0] log2_b_modified;

// Logic for log2 computation of addition/subtraction
logic [FLOAT_LEN-1:0] log2_combined;

// Logic for extract the exponent after log2 computation
logic [EXP_LEN-1:0] log2_exp;
logic [MANT_LEN-1:0] log2_mant;

// Logic for extract the index of exp look up
logic [$clog2(LUT_SIZE)-1:0] exp2_idx;

// Logic for the value after exp2 look up
logic [FLOAT_LEN-1:0] exp2_val;

// Logic for the exponent after look up
logic [EXP_LEN-1:0] exp2_exp_final;

// Logic for the value after total computing
logic [FLOAT_LEN-1:0] val_final;

//---------------------------------------------------------------------
//   DESIGN PART
//---------------------------------------------------------------------
// ========== Look Up Table Initialization ===========
// procedure block for handle lut_wr_ptr
always_ff @ (posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        lut_wr_ptr <= 7'b0;
    end else begin
        lut_wr_ptr <= (lut_wr_en) ? lut_wr_ptr + 1 : lut_wr_ptr;
    end
end

// procedure block for handle lut_wr_done
always_ff @ (posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        lut_wr_done <= 1'b0;
    end else begin
        lut_wr_done <= (&lut_wr_ptr) ? 1'b1 : 1'b0;
    end
end

// procedure block for handle log2_lut0
always_ff @ (posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        log2_lut0[lut_wr_ptr] <= 16'b0;
    end else begin
        log2_lut0[lut_wr_ptr] <= (lut_wr_en) ? log2_lut_data_in0 : log2_lut0[lut_wr_ptr];
    end
end

// procedure block for handle log2_lut1
always_ff @ (posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        log2_lut1[lut_wr_ptr] <= 16'b0;
    end else begin
        log2_lut1[lut_wr_ptr] <= (lut_wr_en) ? log2_lut_data_in1 : log2_lut1[lut_wr_ptr];
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

// ========== Step 1: Unpack float16 a and b ===========
// separate each part of input
assign sign_a = a[15];
assign sign_b = b[15];
assign exp_a_raw = a[14:10];
assign exp_b_raw = b[14:10];
assign mant_a = a[9:0];
assign mant_b = b[9:0];

// get the read address of log2_lut0 & log2_lut0
assign log2_idx_a = mant_a[9:3];
assign log2_idx_b = mant_b[9:3];

// ========== Step 2: LUT Lookups ===========
// procedure block for get the log2-value of input a
always_ff @ (posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        log2_val_a <= 16'b0;
    end else begin
        log2_val_a <= (lut_wr_done) ? log2_lut0[log2_idx_a] : 16'b0;
    end
end

// procedure block for get the log2-value of input b
always_ff @ (posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        log2_val_b <= 16'b0;
    end else begin
        log2_val_b <= (lut_wr_done) ? log2_lut1[log2_idx_b] : 16'b0;
    end
end

// ========== Step 3: Compute log2(a), log2(b) ===========
// unbias the raw exponent
assign exp_a = exp_a_raw - 5'd15;
assign exp_b = exp_b_raw - 5'd15;

// Instantiation of float16 adder for reducting log-2's real input
float16_adder log_add_a(
    .clk(clk),
    .rst_n(rst_n),

    .a({sign_a, exp_a, 10'b0}),
    .b(log2_val_a),
    .result(log2_a_full_w)
);

float16_adder log_add_b(
    .clk(clk),
    .rst_n(rst_n),

    .a({sign_b, exp_b, 10'b0}),
    .b(log2_val_b),
    .result(log2_b_full_w)
);

// pipeline for reduce cirtical path delay
always_ff @ (posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        log2_a_full_r <= 16'b0;
        log2_b_full_r <= 16'b0;
    end else begin
        log2_a_full_r <= log2_a_full_w;
        log2_b_full_r <= log2_b_full_w;
    end
end

// ========== Step 4: Add or Sub (Corresponding to Multiplication/Division) ===========
// modify sign of log2 real number b to fit mutiplication/division
assign log2_b_modified = (mul_or_div) ? {~log2_b_full_r[15], log2_b_full_r[14:0]} : log2_b_full_r;

// Instantiation of float16 adder for addition/subtraction (Corresponding to multiplication/division)
float16_adder log2_combiner(
    .clk(clk),
    .rst_n(rst_n),

    .a(log2_a_full_r),
    .b(log2_b_modified),
    .result(log2_combined)
);

// ========== Step 5: Get exp2 input ===========
// get the exponent & mantissa after log2 computation
assign log2_exp = log2_combined[14:10];
assign log2_mant = log2_combined[9:0];

// get the index for exp2 look up
assign exp2_idx = log2_mant[9:3];

always_ff @ (posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        exp2_val <= 16'b0;
    end else begin
        exp2_val <= (lut_wr_done) ? exp2_lut[exp2_idx] : 16'b0;
    end
end

// ========== Step 6: Final Exponent Adjust ===========
// get the exponent after bias
assign exp2_exp_final = exp2_val + 5'd15;

// get the final value after total computing
assign val_final = {sign_a ^ sign_b, exp2_exp_final, exp2_val[9:0]};

// ========== Step 7: Output result ===========
assign result = val_final;


endmodule