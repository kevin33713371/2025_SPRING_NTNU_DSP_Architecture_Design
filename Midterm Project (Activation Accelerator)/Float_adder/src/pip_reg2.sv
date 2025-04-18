module pip_reg2(
    // Input Signal
    clk,
    rst_n,
    sign_res_sec_w,
    exp_res_sec_w,
    mant_res_w,
    // Output Signal
    sign_res_sec_r,
    exp_res_sec_r,
    mant_res_r
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
input sign_res_sec_w;
input [EXP_LEN-1:0] exp_res_sec_w;
input [(MANT_LEN+7)-1:0] mant_res_w;
output logic sign_res_sec_r;
output logic [EXP_LEN-1:0] exp_res_sec_r;
output logic [(MANT_LEN+7)-1:0] mant_res_r;

//---------------------------------------------------------------------
//   LOGIC DECLARATION
//---------------------------------------------------------------------

//---------------------------------------------------------------------
//   DESIGN PART
//---------------------------------------------------------------------

always_ff @ (posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        sign_res_sec_r  <= 1'b0;
        exp_res_sec_r   <= 5'b0;
        mant_res_r      <= 10'b0;
    end else begin
        sign_res_sec_r  <= sign_res_sec_w;
        exp_res_sec_r   <= exp_res_sec_w;
        mant_res_r      <= mant_res_w;
    end
end

endmodule