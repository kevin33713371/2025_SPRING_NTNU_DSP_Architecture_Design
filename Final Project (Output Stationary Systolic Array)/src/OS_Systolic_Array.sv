`timescale 1ns/1ps

module OS_Systolic_Array # (
    parameter PE_IP_DATA_WIDTH = 8,
    parameter OP_FIFO_WIDTH = 256
)(
    // General Signals
    clk,
    rst_n,
    // Input Signals
    col_data_in_0,
    col_data_in_1,
    col_data_in_2,
    col_data_in_3,
    col_data_in_4,
    col_data_in_5,
    col_data_in_6,
    col_data_in_7,
    row_data_in_0,
    row_data_in_1,
    row_data_in_2,
    row_data_in_3,
    row_data_in_4,
    row_data_in_5,
    row_data_in_6,
    row_data_in_7,
    // Output Signals
    out_data_rd_en,
    fifo_data_out,
    // For debug
    rd_ptr
);

localparam PE_OP_DATA_WIDTH = 32;
localparam NUM_OF_ROW = 8;
localparam NUM_OF_COL = 8;

//---------------------------------------------------------------------
//   INPUT AND OUTPUT DECLARATION
//---------------------------------------------------------------------
input clk, rst_n;
input [PE_IP_DATA_WIDTH-1:0] col_data_in_0;
input [PE_IP_DATA_WIDTH-1:0] col_data_in_1;
input [PE_IP_DATA_WIDTH-1:0] col_data_in_2;
input [PE_IP_DATA_WIDTH-1:0] col_data_in_3;
input [PE_IP_DATA_WIDTH-1:0] col_data_in_4;
input [PE_IP_DATA_WIDTH-1:0] col_data_in_5;
input [PE_IP_DATA_WIDTH-1:0] col_data_in_6;
input [PE_IP_DATA_WIDTH-1:0] col_data_in_7;
input [PE_IP_DATA_WIDTH-1:0] row_data_in_0;
input [PE_IP_DATA_WIDTH-1:0] row_data_in_1;
input [PE_IP_DATA_WIDTH-1:0] row_data_in_2;
input [PE_IP_DATA_WIDTH-1:0] row_data_in_3;
input [PE_IP_DATA_WIDTH-1:0] row_data_in_4;
input [PE_IP_DATA_WIDTH-1:0] row_data_in_5;
input [PE_IP_DATA_WIDTH-1:0] row_data_in_6;
input [PE_IP_DATA_WIDTH-1:0] row_data_in_7;
input out_data_rd_en;
output logic [OP_FIFO_WIDTH-1:0] fifo_data_out;
// For Debug
output logic [2:0] rd_ptr;
//---------------------------------------------------------------------
//   LOGIC DECLARATION
//---------------------------------------------------------------------
// logic for column data input
logic [PE_IP_DATA_WIDTH-1:0] x1_new [NUM_OF_ROW];

// logic for row data input
logic [PE_IP_DATA_WIDTH-1:0] x2_new [NUM_OF_COL];

// logic for previous column data input
logic [PE_IP_DATA_WIDTH-1:0] x1_old [NUM_OF_ROW * NUM_OF_COL];

// logic for previous row data input
logic [PE_IP_DATA_WIDTH-1:0] x2_old [NUM_OF_ROW * NUM_OF_COL];

// For output
logic [PE_OP_DATA_WIDTH-1:0] pe_out_buf_w [NUM_OF_ROW][NUM_OF_COL];
logic [PE_OP_DATA_WIDTH-1:0] pe_out_buf_r [NUM_OF_ROW][NUM_OF_COL];
logic [OP_FIFO_WIDTH-1:0] fifo_data_out_w [NUM_OF_COL];
logic [OP_FIFO_WIDTH-1:0] fifo_data_out_r;

// Read pointer
// logic [2:0] rd_ptr;

// logic for input diagonal delay
// logic [PE_IP_DATA_WIDTH-1:0] col2_d1;
// logic [PE_IP_DATA_WIDTH-1:0] row2_d1;
// logic [PE_IP_DATA_WIDTH-1:0] col3_d1, col3_d2;
// logic [PE_IP_DATA_WIDTH-1:0] row3_d1, row3_d2;
// logic [PE_IP_DATA_WIDTH-1:0] col4_d1, col4_d2, col4_d3;
// logic [PE_IP_DATA_WIDTH-1:0] row4_d1, row4_d2, row4_d3;
// logic [PE_IP_DATA_WIDTH-1:0] col5_d1, col5_d2, col5_d3, col5_d4;
// logic [PE_IP_DATA_WIDTH-1:0] row5_d1, row5_d2, row5_d3, row5_d4;
// logic [PE_IP_DATA_WIDTH-1:0] col6_d1, col6_d2, col6_d3, col6_d4, col6_d5;
// logic [PE_IP_DATA_WIDTH-1:0] row6_d1, row6_d2, row6_d3, row6_d4, row6_d5;
// logic [PE_IP_DATA_WIDTH-1:0] col7_d1, col7_d2, col7_d3, col7_d4, col7_d5, col7_d6;
// logic [PE_IP_DATA_WIDTH-1:0] row7_d1, row7_d2, row7_d3, row7_d4, row7_d5, row7_d6;
// logic [PE_IP_DATA_WIDTH-1:0] col8_d1, col8_d2, col8_d3, col8_d4, col8_d5, col8_d6, col8_d7;
// logic [PE_IP_DATA_WIDTH-1:0] row8_d1, row8_d2, row8_d3, row8_d4, row8_d5, row8_d6, row8_d7;

//---------------------------------------------------------------------
//   DESIGN PART
//---------------------------------------------------------------------

// row/col delay for input
// always_ff @ (posedge clk or negedge rst_n) begin
//     if(!rst_n) begin
//         // Row/Column 0
//         x1_new[0]   <= '0;
//         x2_new[0]   <= '0;
//         // Row/Column 1
//         row2_d1     <= '0;
//         x1_new[1]   <= '0;
//         col2_d1     <= '0;
//         x2_new[1]   <= '0;
//         // Row/Column 2
//         row3_d1     <= '0;
//         row3_d2     <= '0;
//         x1_new[2]   <= '0;
//         col3_d1     <= '0;
//         col3_d2     <= '0;
//         x2_new[2]   <= '0;
//         // Row/Column 3
//         row4_d1     <= '0;
//         row4_d2     <= '0;
//         row4_d3     <= '0;
//         x1_new[3]   <= '0;
//         col4_d1     <= '0;
//         col4_d2     <= '0;
//         col4_d3     <= '0;
//         x2_new[3]   <= '0;
//         // Row/Column 4
//         row5_d1     <= '0;
//         row5_d2     <= '0;
//         row5_d3     <= '0;
//         row5_d4     <= '0;
//         x1_new[4]   <= '0;
//         col5_d1     <= '0;
//         col5_d2     <= '0;
//         col5_d3     <= '0;
//         col5_d4     <= '0;
//         x2_new[4]   <= '0;
//         // Row/Column 5
//         row6_d1     <= '0;
//         row6_d2     <= '0;
//         row6_d3     <= '0;
//         row6_d4     <= '0;
//         row6_d5     <= '0;
//         x1_new[5]   <= '0;
//         col6_d1     <= '0;
//         col6_d2     <= '0;
//         col6_d3     <= '0;
//         col6_d4     <= '0;
//         col6_d5     <= '0;
//         x2_new[5]   <= '0;
//         // Row/Column 6
//         row7_d1     <= '0;
//         row7_d2     <= '0;
//         row7_d3     <= '0;
//         row7_d4     <= '0;
//         row7_d5     <= '0;
//         row7_d6     <= '0;
//         x1_new[6]   <= '0;
//         col7_d1     <= '0;
//         col7_d2     <= '0;
//         col7_d3     <= '0;
//         col7_d4     <= '0;
//         col7_d5     <= '0;
//         col7_d6     <= '0;
//         x2_new[6]   <= '0;
//         // Row/Column 7
//         row8_d1     <= '0;
//         row8_d2     <= '0;
//         row8_d3     <= '0;
//         row8_d4     <= '0;
//         row8_d5     <= '0;
//         row8_d6     <= '0;
//         row8_d7     <= '0;
//         x1_new[7]   <= '0;
//         col8_d1     <= '0;
//         col8_d2     <= '0;
//         col8_d3     <= '0;
//         col8_d4     <= '0;
//         col8_d5     <= '0;
//         col8_d6     <= '0;
//         col8_d7     <= '0;
//         x2_new[7]   <= '0;
//     end else begin
//         // Row/Column 0
//         x1_new[0]   <= col_data_in_0;
//         x2_new[0]   <= row_data_in_0;
//         // Row/Column 1
//         row2_d1     <= col_data_in_1;
//         x1_new[1]   <= row2_d1;
//         col2_d1     <= row_data_in_1;
//         x2_new[1]   <= col2_d1;
//         // Row/Column 2
//         row3_d1     <= col_data_in_2;
//         row3_d2     <= row3_d1;
//         x1_new[2]   <= row3_d2;
//         col3_d1     <= row_data_in_2;
//         col3_d2     <= col3_d1;
//         x2_new[2]   <= col3_d2;
//         // Row/Column 3
//         row4_d1     <= col_data_in_3;
//         row4_d2     <= row4_d1;
//         row4_d3     <= row4_d2;
//         x1_new[3]   <= row4_d3;
//         col4_d1     <= row_data_in_3;
//         col4_d2     <= col4_d1;
//         col4_d3     <= col4_d2;
//         x2_new[3]   <= col4_d3;
//         // Row/Column 4
//         row5_d1     <= col_data_in_4;
//         row5_d2     <= row5_d1;
//         row5_d3     <= row5_d2;
//         row5_d4     <= row5_d3;
//         x1_new[4]   <= row5_d4;
//         col5_d1     <= row_data_in_4;
//         col5_d2     <= col5_d1;
//         col5_d3     <= col5_d2;
//         col5_d4     <= col5_d3;
//         x2_new[4]   <= col5_d4;
//         // Row/Column 5
//         row6_d1     <= col_data_in_5;
//         row6_d2     <= row6_d1;
//         row6_d3     <= row6_d2;
//         row6_d4     <= row6_d3;
//         row6_d5     <= row6_d4;
//         x1_new[5]   <= row6_d5;
//         col6_d1     <= row_data_in_5;
//         col6_d2     <= col6_d1;
//         col6_d3     <= col6_d2;
//         col6_d4     <= col6_d3;
//         col6_d5     <= col6_d4;
//         x2_new[5]   <= col6_d5;
//         // Row/Column 6
//         row7_d1     <= col_data_in_6;
//         row7_d2     <= row7_d1;
//         row7_d3     <= row7_d2;
//         row7_d4     <= row7_d3;
//         row7_d5     <= row7_d4;
//         row7_d6     <= row7_d5;
//         x1_new[6]   <= row7_d6;
//         col7_d1     <= row_data_in_6;
//         col7_d2     <= col7_d1;
//         col7_d3     <= col7_d2;
//         col7_d4     <= col7_d3;
//         col7_d5     <= col7_d4;
//         col7_d6     <= col7_d5;
//         x2_new[6]   <= col7_d6;
//         // Row/Column 7
//         row8_d1     <= col_data_in_7;
//         row8_d2     <= row8_d1;
//         row8_d3     <= row8_d2;
//         row8_d4     <= row8_d3;
//         row8_d5     <= row8_d4;
//         row8_d6     <= row8_d5;
//         row8_d7     <= row8_d6;
//         x1_new[7]   <= row8_d7;
//         col8_d1     <= row_data_in_7;
//         col8_d2     <= col8_d1;
//         col8_d3     <= col8_d2;
//         col8_d4     <= col8_d3;
//         col8_d5     <= col8_d4;
//         col8_d6     <= col8_d5;
//         col8_d7     <= col8_d6;
//         x2_new[7]   <= col8_d7;
//     end
// end

// input assignment
assign x1_new[0] = col_data_in_0;
assign x1_new[1] = col_data_in_1;
assign x1_new[2] = col_data_in_2;
assign x1_new[3] = col_data_in_3;
assign x1_new[4] = col_data_in_4;
assign x1_new[5] = col_data_in_5;
assign x1_new[6] = col_data_in_6;
assign x1_new[7] = col_data_in_7;
assign x2_new[0] = row_data_in_0;
assign x2_new[1] = row_data_in_1;
assign x2_new[2] = row_data_in_2;
assign x2_new[3] = row_data_in_3;
assign x2_new[4] = row_data_in_4;
assign x2_new[5] = row_data_in_5;
assign x2_new[6] = row_data_in_6;
assign x2_new[7] = row_data_in_7;

// Instantiation of PE

// PE_XX, First X is num of column, Second X is num of row

// Row 0
PE PE_00 (clk, rst_n, x1_new[0],  x2_new[0],  x1_old[0],  x2_old[0],  pe_out_buf_w[0][0]);
PE PE_01 (clk, rst_n, x1_old[0],  x2_new[1],  x1_old[1],  x2_old[1],  pe_out_buf_w[0][1]);
PE PE_02 (clk, rst_n, x1_old[1],  x2_new[2],  x1_old[2],  x2_old[2],  pe_out_buf_w[0][2]);
PE PE_03 (clk, rst_n, x1_old[2],  x2_new[3],  x1_old[3],  x2_old[3],  pe_out_buf_w[0][3]);
PE PE_04 (clk, rst_n, x1_old[3],  x2_new[4],  x1_old[4],  x2_old[4],  pe_out_buf_w[0][4]);
PE PE_05 (clk, rst_n, x1_old[4],  x2_new[5],  x1_old[5],  x2_old[5],  pe_out_buf_w[0][5]);
PE PE_06 (clk, rst_n, x1_old[5],  x2_new[6],  x1_old[6],  x2_old[6],  pe_out_buf_w[0][6]);
PE PE_07 (clk, rst_n, x1_old[6],  x2_new[7],  x1_old[7],  x2_old[7],  pe_out_buf_w[0][7]);

// Row 1
PE PE_10 (clk, rst_n, x1_new[ 1], x2_old[0],  x1_old[ 8], x2_old[ 8], pe_out_buf_w[1][0]);
PE PE_11 (clk, rst_n, x1_old[ 8], x2_old[1],  x1_old[ 9], x2_old[ 9], pe_out_buf_w[1][1]);
PE PE_12 (clk, rst_n, x1_old[ 9], x2_old[2],  x1_old[10], x2_old[10], pe_out_buf_w[1][2]);
PE PE_13 (clk, rst_n, x1_old[10], x2_old[3],  x1_old[11], x2_old[11], pe_out_buf_w[1][3]);
PE PE_14 (clk, rst_n, x1_old[11], x2_old[4],  x1_old[12], x2_old[12], pe_out_buf_w[1][4]);
PE PE_15 (clk, rst_n, x1_old[12], x2_old[5],  x1_old[13], x2_old[13], pe_out_buf_w[1][5]);
PE PE_16 (clk, rst_n, x1_old[13], x2_old[6],  x1_old[14], x2_old[14], pe_out_buf_w[1][6]);
PE PE_17 (clk, rst_n, x1_old[14], x2_old[7],  x1_old[15], x2_old[15], pe_out_buf_w[1][7]);

// Row 2
PE PE_20 (clk, rst_n, x1_new[ 2], x2_old[ 8], x1_old[16], x2_old[16], pe_out_buf_w[2][0]);
PE PE_21 (clk, rst_n, x1_old[16], x2_old[ 9], x1_old[17], x2_old[17], pe_out_buf_w[2][1]);
PE PE_22 (clk, rst_n, x1_old[17], x2_old[10], x1_old[18], x2_old[18], pe_out_buf_w[2][2]);
PE PE_23 (clk, rst_n, x1_old[18], x2_old[11], x1_old[19], x2_old[19], pe_out_buf_w[2][3]);
PE PE_24 (clk, rst_n, x1_old[19], x2_old[12], x1_old[20], x2_old[20], pe_out_buf_w[2][4]);
PE PE_25 (clk, rst_n, x1_old[20], x2_old[13], x1_old[21], x2_old[21], pe_out_buf_w[2][5]);
PE PE_26 (clk, rst_n, x1_old[21], x2_old[14], x1_old[22], x2_old[22], pe_out_buf_w[2][6]);
PE PE_27 (clk, rst_n, x1_old[22], x2_old[15], x1_old[23], x2_old[23], pe_out_buf_w[2][7]);

// Row 3
PE PE_30 (clk, rst_n, x1_new[ 3], x2_old[16], x1_old[24], x2_old[24], pe_out_buf_w[3][0]);
PE PE_31 (clk, rst_n, x1_old[24], x2_old[17], x1_old[25], x2_old[25], pe_out_buf_w[3][1]);
PE PE_32 (clk, rst_n, x1_old[25], x2_old[18], x1_old[26], x2_old[26], pe_out_buf_w[3][2]);
PE PE_33 (clk, rst_n, x1_old[26], x2_old[19], x1_old[27], x2_old[27], pe_out_buf_w[3][3]);
PE PE_34 (clk, rst_n, x1_old[27], x2_old[20], x1_old[28], x2_old[28], pe_out_buf_w[3][4]);
PE PE_35 (clk, rst_n, x1_old[28], x2_old[21], x1_old[29], x2_old[29], pe_out_buf_w[3][5]);
PE PE_36 (clk, rst_n, x1_old[29], x2_old[22], x1_old[30], x2_old[30], pe_out_buf_w[3][6]);
PE PE_37 (clk, rst_n, x1_old[30], x2_old[23], x1_old[31], x2_old[31], pe_out_buf_w[3][7]);

// Row 4
PE PE_40 (clk, rst_n, x1_new[ 4], x2_old[24], x1_old[32], x2_old[32], pe_out_buf_w[4][0]);
PE PE_41 (clk, rst_n, x1_old[32], x2_old[25], x1_old[33], x2_old[33], pe_out_buf_w[4][1]);
PE PE_42 (clk, rst_n, x1_old[33], x2_old[26], x1_old[34], x2_old[34], pe_out_buf_w[4][2]);
PE PE_43 (clk, rst_n, x1_old[34], x2_old[27], x1_old[35], x2_old[35], pe_out_buf_w[4][3]);
PE PE_44 (clk, rst_n, x1_old[35], x2_old[28], x1_old[36], x2_old[36], pe_out_buf_w[4][4]);
PE PE_45 (clk, rst_n, x1_old[36], x2_old[29], x1_old[37], x2_old[37], pe_out_buf_w[4][5]);
PE PE_46 (clk, rst_n, x1_old[37], x2_old[30], x1_old[38], x2_old[38], pe_out_buf_w[4][6]);
PE PE_47 (clk, rst_n, x1_old[38], x2_old[31], x1_old[39], x2_old[39], pe_out_buf_w[4][7]);

// Row 5
PE PE_50 (clk, rst_n, x1_new[ 5], x2_old[32], x1_old[40], x2_old[40], pe_out_buf_w[5][0]);
PE PE_51 (clk, rst_n, x1_old[40], x2_old[33], x1_old[41], x2_old[41], pe_out_buf_w[5][1]);
PE PE_52 (clk, rst_n, x1_old[41], x2_old[34], x1_old[42], x2_old[42], pe_out_buf_w[5][2]);
PE PE_53 (clk, rst_n, x1_old[42], x2_old[35], x1_old[43], x2_old[43], pe_out_buf_w[5][3]);
PE PE_54 (clk, rst_n, x1_old[43], x2_old[36], x1_old[44], x2_old[44], pe_out_buf_w[5][4]);
PE PE_55 (clk, rst_n, x1_old[44], x2_old[37], x1_old[45], x2_old[45], pe_out_buf_w[5][5]);
PE PE_56 (clk, rst_n, x1_old[45], x2_old[38], x1_old[46], x2_old[46], pe_out_buf_w[5][6]);
PE PE_57 (clk, rst_n, x1_old[46], x2_old[39], x1_old[47], x2_old[47], pe_out_buf_w[5][7]);

// Row 6
PE PE_60 (clk, rst_n, x1_new[ 6], x2_old[40], x1_old[48], x2_old[48], pe_out_buf_w[6][0]);
PE PE_61 (clk, rst_n, x1_old[48], x2_old[41], x1_old[49], x2_old[49], pe_out_buf_w[6][1]);
PE PE_62 (clk, rst_n, x1_old[49], x2_old[42], x1_old[50], x2_old[50], pe_out_buf_w[6][2]);
PE PE_63 (clk, rst_n, x1_old[50], x2_old[43], x1_old[51], x2_old[51], pe_out_buf_w[6][3]);
PE PE_64 (clk, rst_n, x1_old[51], x2_old[44], x1_old[52], x2_old[52], pe_out_buf_w[6][4]);
PE PE_65 (clk, rst_n, x1_old[52], x2_old[45], x1_old[53], x2_old[53], pe_out_buf_w[6][5]);
PE PE_66 (clk, rst_n, x1_old[53], x2_old[46], x1_old[54], x2_old[54], pe_out_buf_w[6][6]);
PE PE_67 (clk, rst_n, x1_old[54], x2_old[47], x1_old[55], x2_old[55], pe_out_buf_w[6][7]);

// Row 7
PE PE_70 (clk, rst_n, x1_new[ 7], x2_old[48], x1_old[56], x2_old[56], pe_out_buf_w[7][0]);
PE PE_71 (clk, rst_n, x1_old[56], x2_old[49], x1_old[57], x2_old[57], pe_out_buf_w[7][1]);
PE PE_72 (clk, rst_n, x1_old[57], x2_old[50], x1_old[58], x2_old[58], pe_out_buf_w[7][2]);
PE PE_73 (clk, rst_n, x1_old[58], x2_old[51], x1_old[59], x2_old[59], pe_out_buf_w[7][3]);
PE PE_74 (clk, rst_n, x1_old[59], x2_old[52], x1_old[60], x2_old[60], pe_out_buf_w[7][4]);
PE PE_75 (clk, rst_n, x1_old[60], x2_old[53], x1_old[61], x2_old[61], pe_out_buf_w[7][5]);
PE PE_76 (clk, rst_n, x1_old[61], x2_old[54], x1_old[62], x2_old[62], pe_out_buf_w[7][6]);
PE PE_77 (clk, rst_n, x1_old[62], x2_old[55], x1_old[63], x2_old[63], pe_out_buf_w[7][7]);

// output pipeline
always_ff @ (posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        pe_out_buf_r[0][0] <= '0;
        pe_out_buf_r[0][1] <= '0;
        pe_out_buf_r[0][2] <= '0;
        pe_out_buf_r[0][3] <= '0;
        pe_out_buf_r[0][4] <= '0;
        pe_out_buf_r[0][5] <= '0;
        pe_out_buf_r[0][6] <= '0;
        pe_out_buf_r[0][7] <= '0;
        pe_out_buf_r[1][0] <= '0;
        pe_out_buf_r[1][1] <= '0;
        pe_out_buf_r[1][2] <= '0;
        pe_out_buf_r[1][3] <= '0;
        pe_out_buf_r[1][4] <= '0;
        pe_out_buf_r[1][5] <= '0;
        pe_out_buf_r[1][6] <= '0;
        pe_out_buf_r[1][7] <= '0;
        pe_out_buf_r[2][0] <= '0;
        pe_out_buf_r[2][1] <= '0;
        pe_out_buf_r[2][2] <= '0;
        pe_out_buf_r[2][3] <= '0;
        pe_out_buf_r[2][4] <= '0;
        pe_out_buf_r[2][5] <= '0;
        pe_out_buf_r[2][6] <= '0;
        pe_out_buf_r[2][7] <= '0;
        pe_out_buf_r[3][0] <= '0;
        pe_out_buf_r[3][1] <= '0;
        pe_out_buf_r[3][2] <= '0;
        pe_out_buf_r[3][3] <= '0;
        pe_out_buf_r[3][4] <= '0;
        pe_out_buf_r[3][5] <= '0;
        pe_out_buf_r[3][6] <= '0;
        pe_out_buf_r[3][7] <= '0;
        pe_out_buf_r[4][0] <= '0;
        pe_out_buf_r[4][1] <= '0;
        pe_out_buf_r[4][2] <= '0;
        pe_out_buf_r[4][3] <= '0;
        pe_out_buf_r[4][4] <= '0;
        pe_out_buf_r[4][5] <= '0;
        pe_out_buf_r[4][6] <= '0;
        pe_out_buf_r[4][7] <= '0;
        pe_out_buf_r[5][0] <= '0;
        pe_out_buf_r[5][1] <= '0;
        pe_out_buf_r[5][2] <= '0;
        pe_out_buf_r[5][3] <= '0;
        pe_out_buf_r[5][4] <= '0;
        pe_out_buf_r[5][5] <= '0;
        pe_out_buf_r[5][6] <= '0;
        pe_out_buf_r[5][7] <= '0;
        pe_out_buf_r[6][0] <= '0;
        pe_out_buf_r[6][1] <= '0;
        pe_out_buf_r[6][2] <= '0;
        pe_out_buf_r[6][3] <= '0;
        pe_out_buf_r[6][4] <= '0;
        pe_out_buf_r[6][5] <= '0;
        pe_out_buf_r[6][6] <= '0;
        pe_out_buf_r[6][7] <= '0;
        pe_out_buf_r[7][0] <= '0;
        pe_out_buf_r[7][1] <= '0;
        pe_out_buf_r[7][2] <= '0;
        pe_out_buf_r[7][3] <= '0;
        pe_out_buf_r[7][4] <= '0;
        pe_out_buf_r[7][5] <= '0;
        pe_out_buf_r[7][6] <= '0;
        pe_out_buf_r[7][7] <= '0;
    end else begin
        pe_out_buf_r[0][0] <= pe_out_buf_w[0][0];
        pe_out_buf_r[0][1] <= pe_out_buf_w[0][1];
        pe_out_buf_r[0][2] <= pe_out_buf_w[0][2];
        pe_out_buf_r[0][3] <= pe_out_buf_w[0][3];
        pe_out_buf_r[0][4] <= pe_out_buf_w[0][4];
        pe_out_buf_r[0][5] <= pe_out_buf_w[0][5];
        pe_out_buf_r[0][6] <= pe_out_buf_w[0][6];
        pe_out_buf_r[0][7] <= pe_out_buf_w[0][7];
        pe_out_buf_r[1][0] <= pe_out_buf_w[1][0];
        pe_out_buf_r[1][1] <= pe_out_buf_w[1][1];
        pe_out_buf_r[1][2] <= pe_out_buf_w[1][2];
        pe_out_buf_r[1][3] <= pe_out_buf_w[1][3];
        pe_out_buf_r[1][4] <= pe_out_buf_w[1][4];
        pe_out_buf_r[1][5] <= pe_out_buf_w[1][5];
        pe_out_buf_r[1][6] <= pe_out_buf_w[1][6];
        pe_out_buf_r[1][7] <= pe_out_buf_w[1][7];
        pe_out_buf_r[2][0] <= pe_out_buf_w[2][0];
        pe_out_buf_r[2][1] <= pe_out_buf_w[2][1];
        pe_out_buf_r[2][2] <= pe_out_buf_w[2][2];
        pe_out_buf_r[2][3] <= pe_out_buf_w[2][3];
        pe_out_buf_r[2][4] <= pe_out_buf_w[2][4];
        pe_out_buf_r[2][5] <= pe_out_buf_w[2][5];
        pe_out_buf_r[2][6] <= pe_out_buf_w[2][6];
        pe_out_buf_r[2][7] <= pe_out_buf_w[2][7];
        pe_out_buf_r[3][0] <= pe_out_buf_w[3][0];
        pe_out_buf_r[3][1] <= pe_out_buf_w[3][1];
        pe_out_buf_r[3][2] <= pe_out_buf_w[3][2];
        pe_out_buf_r[3][3] <= pe_out_buf_w[3][3];
        pe_out_buf_r[3][4] <= pe_out_buf_w[3][4];
        pe_out_buf_r[3][5] <= pe_out_buf_w[3][5];
        pe_out_buf_r[3][6] <= pe_out_buf_w[3][6];
        pe_out_buf_r[3][7] <= pe_out_buf_w[3][7];
        pe_out_buf_r[4][0] <= pe_out_buf_w[4][0];
        pe_out_buf_r[4][1] <= pe_out_buf_w[4][1];
        pe_out_buf_r[4][2] <= pe_out_buf_w[4][2];
        pe_out_buf_r[4][3] <= pe_out_buf_w[4][3];
        pe_out_buf_r[4][4] <= pe_out_buf_w[4][4];
        pe_out_buf_r[4][5] <= pe_out_buf_w[4][5];
        pe_out_buf_r[4][6] <= pe_out_buf_w[4][6];
        pe_out_buf_r[4][7] <= pe_out_buf_w[4][7];
        pe_out_buf_r[5][0] <= pe_out_buf_w[5][0];
        pe_out_buf_r[5][1] <= pe_out_buf_w[5][1];
        pe_out_buf_r[5][2] <= pe_out_buf_w[5][2];
        pe_out_buf_r[5][3] <= pe_out_buf_w[5][3];
        pe_out_buf_r[5][4] <= pe_out_buf_w[5][4];
        pe_out_buf_r[5][5] <= pe_out_buf_w[5][5];
        pe_out_buf_r[5][6] <= pe_out_buf_w[5][6];
        pe_out_buf_r[5][7] <= pe_out_buf_w[5][7];
        pe_out_buf_r[6][0] <= pe_out_buf_w[6][0];
        pe_out_buf_r[6][1] <= pe_out_buf_w[6][1];
        pe_out_buf_r[6][2] <= pe_out_buf_w[6][2];
        pe_out_buf_r[6][3] <= pe_out_buf_w[6][3];
        pe_out_buf_r[6][4] <= pe_out_buf_w[6][4];
        pe_out_buf_r[6][5] <= pe_out_buf_w[6][5];
        pe_out_buf_r[6][6] <= pe_out_buf_w[6][6];
        pe_out_buf_r[6][7] <= pe_out_buf_w[6][7];
        pe_out_buf_r[7][0] <= pe_out_buf_w[7][0];
        pe_out_buf_r[7][1] <= pe_out_buf_w[7][1];
        pe_out_buf_r[7][2] <= pe_out_buf_w[7][2];
        pe_out_buf_r[7][3] <= pe_out_buf_w[7][3];
        pe_out_buf_r[7][4] <= pe_out_buf_w[7][4];
        pe_out_buf_r[7][5] <= pe_out_buf_w[7][5];
        pe_out_buf_r[7][6] <= pe_out_buf_w[7][6];
        pe_out_buf_r[7][7] <= pe_out_buf_w[7][7];
    end
end

// fifo_data_out_w
assign fifo_data_out_w[0] = {pe_out_buf_r[7][0], pe_out_buf_r[6][0], pe_out_buf_r[5][0], pe_out_buf_r[4][0], pe_out_buf_r[3][0], pe_out_buf_r[2][0], pe_out_buf_r[1][0], pe_out_buf_r[0][0]};
assign fifo_data_out_w[1] = {pe_out_buf_r[7][1], pe_out_buf_r[6][1], pe_out_buf_r[5][1], pe_out_buf_r[4][1], pe_out_buf_r[3][1], pe_out_buf_r[2][1], pe_out_buf_r[1][1], pe_out_buf_r[0][1]};
assign fifo_data_out_w[2] = {pe_out_buf_r[7][2], pe_out_buf_r[6][2], pe_out_buf_r[5][2], pe_out_buf_r[4][2], pe_out_buf_r[3][2], pe_out_buf_r[2][2], pe_out_buf_r[1][2], pe_out_buf_r[0][2]};
assign fifo_data_out_w[3] = {pe_out_buf_r[7][3], pe_out_buf_r[6][3], pe_out_buf_r[5][3], pe_out_buf_r[4][3], pe_out_buf_r[3][3], pe_out_buf_r[2][3], pe_out_buf_r[1][3], pe_out_buf_r[0][3]};
assign fifo_data_out_w[4] = {pe_out_buf_r[7][4], pe_out_buf_r[6][4], pe_out_buf_r[5][4], pe_out_buf_r[4][4], pe_out_buf_r[3][4], pe_out_buf_r[2][4], pe_out_buf_r[1][4], pe_out_buf_r[0][4]};
assign fifo_data_out_w[5] = {pe_out_buf_r[7][5], pe_out_buf_r[6][5], pe_out_buf_r[5][5], pe_out_buf_r[4][5], pe_out_buf_r[3][5], pe_out_buf_r[2][5], pe_out_buf_r[1][5], pe_out_buf_r[0][5]};
assign fifo_data_out_w[6] = {pe_out_buf_r[7][6], pe_out_buf_r[6][6], pe_out_buf_r[5][6], pe_out_buf_r[4][6], pe_out_buf_r[3][6], pe_out_buf_r[2][6], pe_out_buf_r[1][6], pe_out_buf_r[0][6]};
assign fifo_data_out_w[7] = {pe_out_buf_r[7][7], pe_out_buf_r[6][7], pe_out_buf_r[5][7], pe_out_buf_r[4][7], pe_out_buf_r[3][7], pe_out_buf_r[2][7], pe_out_buf_r[1][7], pe_out_buf_r[0][7]};

// fifo_data_out
always_ff @ (posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        fifo_data_out_r <= '0;
    end else begin
        if(out_data_rd_en) begin
            fifo_data_out_r <= fifo_data_out_w[rd_ptr];
        end else begin
            fifo_data_out_r <= fifo_data_out;
        end
    end
end

assign fifo_data_out = fifo_data_out_r;

// rd_ptr
always_ff @ (posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        rd_ptr <= '0;
    end else begin
        if(out_data_rd_en) begin
            rd_ptr <= rd_ptr + 1;
        end else begin
            rd_ptr <= rd_ptr;
        end
    end
end

endmodule