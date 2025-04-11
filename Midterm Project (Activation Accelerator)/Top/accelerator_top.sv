module accelerator_top (
    // Input Signal
    clk,
    rst_n,

    in_valid,
    in_mode_sel,
    in_data,

    lut_wr_en,
    lut_wr_addr,
    lut_data,
    // Output Signal
    out_valid,
    out_data
);

// Parameter
parameter DATA_WIDTH = 32;
parameter LUT_ADDR_WIDTH = 8;
parameter LUT_DEPTH = 256;
parameter EXP_BUF_SIZE = 8;

//---------------------------------------------------------------------
//   INPUT AND OUTPUT DECLARATION
//---------------------------------------------------------------------
input clk, rst_n;
input in_valid, in_mode_sel;
input [DATA_WIDTH-1:0] in_data;
input lut_wr_en;
input [LUT_ADDR_WIDTH-1:0] lut_wr_addr;
input [DATA_WIDTH-1:0] lut_data;
output logic out_valid;
output logic [DATA_WIDTH-1:0] out_data;
//---------------------------------------------------------------------
//   LOGIC DECLARATION
//---------------------------------------------------------------------

//---------------------------------------------------------------------
//   DESIGN PART
//---------------------------------------------------------------------



endmodule