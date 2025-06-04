`timescale 1ns/1ps

module PE #(
    parameter IP_DATA_WIDTH = 8,
    parameter OP_DATA_WIDTH = 32
) (
    // General Signals
    clk,
    rst_n,
    // Input Signals
    in_data_0,
    in_data_1,
    // Output Signals
    out_data_0,
    out_data_1,
    pe_out_reg
    // For Debug
    // pe_val
);

//---------------------------------------------------------------------
//   INPUT AND OUTPUT DECLARATION
//---------------------------------------------------------------------
input clk, rst_n;
input [IP_DATA_WIDTH-1:0] in_data_0, in_data_1;
output logic [IP_DATA_WIDTH-1:0] out_data_0, out_data_1;
output logic [OP_DATA_WIDTH-1:0] pe_out_reg;
// for debug
// output logic [OP_DATA_WIDTH-1:0] pe_val;
//---------------------------------------------------------------------
//   LOGIC DECLARATION
//---------------------------------------------------------------------
logic [IP_DATA_WIDTH-1:0] out_data_0_r, out_data_1_r;
logic [OP_DATA_WIDTH-1:0] pe_val;
logic [OP_DATA_WIDTH-1:0] pe_out_reg_r;
//---------------------------------------------------------------------
//   DESIGN PART
//---------------------------------------------------------------------

always_ff @ (posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        out_data_0_r <= 8'h00;
        out_data_1_r <= 8'h00;
    end else begin
        out_data_0_r <= in_data_0;
        out_data_1_r <= in_data_1;
    end
end

always_ff @ (posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        pe_out_reg_r <= 32'h00000000;
    end else begin
        pe_out_reg_r <= pe_val;
    end
end

assign pe_val = pe_out_reg_r + in_data_0 * in_data_1;
assign out_data_0 = out_data_0_r;
assign out_data_1 = out_data_1_r;
assign pe_out_reg = pe_out_reg_r;

endmodule