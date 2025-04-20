module pip_reg1(
    // Input Signal
    clk,
    rst_n,
    sign_cmp_w,
    mant_cmp_w,
    sign_res_fir_w,
    exp_res_fir_w,
    m1_shifted_w,
    m2_shifted_w,
    // Output Signal
    sign_cmp_r,
    mant_cmp_r,
    sign_res_fir_r,
    exp_res_fir_r,
    m1_shifted_r,
    m2_shifted_r
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
input sign_cmp_w, mant_cmp_w, sign_res_fir_w;
input [EXP_LEN-1:0] exp_res_fir_w;
input [(MANT_LEN+6)-1:0] m1_shifted_w, m2_shifted_w;
output logic sign_cmp_r, mant_cmp_r, sign_res_fir_r;
output logic [EXP_LEN-1:0] exp_res_fir_r;
output logic [(MANT_LEN+6)-1:0] m1_shifted_r, m2_shifted_r;

//---------------------------------------------------------------------
//   LOGIC DECLARATION
//---------------------------------------------------------------------

//---------------------------------------------------------------------
//   DESIGN PART
//---------------------------------------------------------------------

always_ff @ (posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        sign_cmp_r      <= 1'b0;
        mant_cmp_r      <= 1'b0;
        sign_res_fir_r  <= 1'b0;
        exp_res_fir_r   <= 5'b0;
        m1_shifted_r    <= 10'b0;
        m2_shifted_r    <= 10'b0;
    end else begin
        sign_cmp_r      <= sign_cmp_w;
        mant_cmp_r      <= mant_cmp_w;
        sign_res_fir_r  <= sign_res_fir_w;
        exp_res_fir_r   <= exp_res_fir_w;
        m1_shifted_r    <= m1_shifted_w;
        m2_shifted_r    <= m2_shifted_w;
    end
end

endmodule