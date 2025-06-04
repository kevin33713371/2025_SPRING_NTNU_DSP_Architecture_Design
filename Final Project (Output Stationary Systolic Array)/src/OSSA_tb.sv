`timescale 1ns/1ps
`define clk_period 10

module OSSA_tb();

    // Parameter
    parameter PE_IP_DATA_WIDTH = 8;
    parameter OP_FIFO_WIDTH = 256;
    parameter ROW_A = 8;
    parameter COL_A = 8;
    parameter COL_B = 8;

    // General Signal
    logic clk, rst_n;

    // Logic Declaration for Instantiation
    logic [PE_IP_DATA_WIDTH-1:0] col_data_in_0;
    logic [PE_IP_DATA_WIDTH-1:0] col_data_in_1;
    logic [PE_IP_DATA_WIDTH-1:0] col_data_in_2;
    logic [PE_IP_DATA_WIDTH-1:0] col_data_in_3;
    logic [PE_IP_DATA_WIDTH-1:0] col_data_in_4;
    logic [PE_IP_DATA_WIDTH-1:0] col_data_in_5;
    logic [PE_IP_DATA_WIDTH-1:0] col_data_in_6;
    logic [PE_IP_DATA_WIDTH-1:0] col_data_in_7;
    logic [PE_IP_DATA_WIDTH-1:0] row_data_in_0;
    logic [PE_IP_DATA_WIDTH-1:0] row_data_in_1;
    logic [PE_IP_DATA_WIDTH-1:0] row_data_in_2;
    logic [PE_IP_DATA_WIDTH-1:0] row_data_in_3;
    logic [PE_IP_DATA_WIDTH-1:0] row_data_in_4;
    logic [PE_IP_DATA_WIDTH-1:0] row_data_in_5;
    logic [PE_IP_DATA_WIDTH-1:0] row_data_in_6;
    logic [PE_IP_DATA_WIDTH-1:0] row_data_in_7;
    logic out_data_rd_en;
    logic [OP_FIFO_WIDTH-1:0] fifo_data_out;

    // For Debug
    logic [2:0] rd_ptr;

    // Module Instantiation
    OS_Systolic_Array OSSA_DUT(
        .*
    );

    //--------------------------------------------------
    //   CLK DECLARATION
    //--------------------------------------------------
    initial clk = 1'b0;
	always #(`clk_period/2) clk = ~clk;

    //--------------------------------------------------
    //   FUNCTION OR TASK DECLARATION
    //--------------------------------------------------

    // Produce Matrix input/output
    logic [7:0] A [ROW_A][COL_A];
    logic [7:0] B [COL_A][COL_B];
    logic [31:0] C [ROW_A][COL_B];
    logic [7:0] padding_diagonal_A [ROW_A][COL_A + ROW_A - 1];
    logic [7:0] padding_diagonal_B [COL_A + ROW_A - 1][COL_B];
    // logic [63:0] in_data_0_buf [COL_A + ROW_A - 1];
    // logic [63:0] in_data_1_buf [COL_A + ROW_A - 1];
    initial begin
        // Generate A matrix
        for(int i = 0; i < ROW_A; i++) begin
            for(int j = 0; j < COL_A; j++) begin
                A[i][j] = $urandom() % 255;
            end
        end
        // Generate B matrix
        for(int i = 0; i < COL_A; i++) begin
            for(int j = 0; j < COL_B; j++) begin
                B[i][j] = $urandom() % 255;
            end
        end
        // Generate C matrix
        for(int i = 0; i < ROW_A; i++) begin
            for(int j = 0; j < COL_B; j++) begin
                automatic int acc = 0;
                for(int k = 0; k < COL_A; k++) begin
                    acc += A[i][k] * B[k][j];
                end
                C[i][j] = acc;
            end
        end
        // Transform A matrix to diagonal format
        // * * * * * * * * * * * * * * * * 0 0 0 0 0 0 0 <- row 0
        // 0 * * * * * * * * * * * * * * * * 0 0 0 0 0 0 <- row 1
        // 0 0 * * * * * * * * * * * * * * * * 0 0 0 0 0 <- row 2
        // 0 0 0 * * * * * * * * * * * * * * * * 0 0 0 0 <- row 3
        // 0 0 0 0 * * * * * * * * * * * * * * * * 0 0 0 <- row 4
        // 0 0 0 0 0 * * * * * * * * * * * * * * * * 0 0 <- row 5
        // 0 0 0 0 0 0 * * * * * * * * * * * * * * * * 0 <- row 6
        // 0 0 0 0 0 0 0 * * * * * * * * * * * * * * * * <- row 7
        for(int i = 0; i < ROW_A; i++) begin
            for(int j = 0; j < COL_A + ROW_A - 1; j++) begin
                automatic int k = j - i;
                if(k >= 0 && k < COL_A) begin
                    padding_diagonal_A[i][j] = A[i][k];
                end else begin
                    padding_diagonal_A[i][j] = 8'd0;
                end
            end
        end
        // Transform B matrix to diagonal format
        // * 0 0 0 0 0 0 0 <- row 0
        // * * 0 0 0 0 0 0 <- row 1
        // * * * 0 0 0 0 0 <- row 2
        // * * * * 0 0 0 0 <- row 3
        // * * * * * 0 0 0 <- row 4
        // * * * * * * 0 0 <- row 5
        // * * * * * * 0 0 <- row 6
        // * * * * * * * * <- row 7
        // * * * * * * * * <- row 8
        // * * * * * * * * <- row 9
        // * * * * * * * * <- row 10
        // * * * * * * * * <- row 11
        // * * * * * * * * <- row 12
        // * * * * * * * * <- row 13
        // * * * * * * * * <- row 14
        // * * * * * * * * <- row 15
        // 0 * * * * * * * <- row 16
        // 0 0 * * * * * * <- row 17
        // 0 0 0 * * * * * <- row 18
        // 0 0 0 0 * * * * <- row 19
        // 0 0 0 0 0 * * * <- row 20
        // 0 0 0 0 0 0 * * <- row 21
        // 0 0 0 0 0 0 0 * <- row 22
        for(int i = 0; i < COL_A + ROW_A - 1; i++) begin
            for(int j = 0; j < COL_B; j++) begin
                automatic int k = i - j;
                if(k >=0 && k < COL_A) begin
                    padding_diagonal_B[i][j] = B[k][j];
                end else begin
                    padding_diagonal_B[i][j] = 8'd0;
                end
            end
        end
        // Transform diagonal form A matrix to in_data_0_buf for in_data_0 fifo input
        // for(int i = 0; i < COL_A + ROW_A - 1; i++) begin
        //     in_data_0_buf[i][7:0]   = padding_diagonal_A[0][i];
        //     in_data_0_buf[i][15:8]  = padding_diagonal_A[1][i];
        //     in_data_0_buf[i][23:16] = padding_diagonal_A[2][i];
        //     in_data_0_buf[i][31:24] = padding_diagonal_A[3][i];
        //     in_data_0_buf[i][39:32] = padding_diagonal_A[4][i];
        //     in_data_0_buf[i][47:40] = padding_diagonal_A[5][i];
        //     in_data_0_buf[i][55:48] = padding_diagonal_A[6][i];
        //     in_data_0_buf[i][63:56] = padding_diagonal_A[7][i];
        // end
        // Transform diagonal form A matrix to in_data_0_buf for in_data_0 fifo input
        // for(int i = 0; i < COL_A + ROW_A - 1; i++) begin
        //     in_data_1_buf[i][7:0]   = padding_diagonal_B[i][0];
        //     in_data_1_buf[i][15:8]  = padding_diagonal_B[i][1];
        //     in_data_1_buf[i][23:16] = padding_diagonal_B[i][2];
        //     in_data_1_buf[i][31:24] = padding_diagonal_B[i][3];
        //     in_data_1_buf[i][39:32] = padding_diagonal_B[i][4];
        //     in_data_1_buf[i][47:40] = padding_diagonal_B[i][5];
        //     in_data_1_buf[i][55:48] = padding_diagonal_B[i][6];
        //     in_data_1_buf[i][63:56] = padding_diagonal_B[i][7];
        // end
    end

    // task: display input data
    // task display_input;
    //     begin
    //         for(int i = 0; i < COL_A + ROW_A - 1; i++) begin
    //             $display("column FIFO input data %d = %h", i, in_data_0_buf[i]);
    //         end
    //         for(int i = 0; i < COL_A + ROW_A - 1; i++) begin
    //             $display("row FIFO input data %d = %h", i, in_data_1_buf[i]);
    //         end
    //     end
    // endtask

    // task: write task
    task write_task;
        begin
            for(int i = 0; i < COL_A + ROW_A - 1; i++) begin
                if(i == 0) begin
                    col_data_in_0 <= padding_diagonal_A[0][i];
                    col_data_in_1 <= padding_diagonal_A[1][i];
                    col_data_in_2 <= padding_diagonal_A[2][i];
                    col_data_in_3 <= padding_diagonal_A[3][i];
                    col_data_in_4 <= padding_diagonal_A[4][i];
                    col_data_in_5 <= padding_diagonal_A[5][i];
                    col_data_in_6 <= padding_diagonal_A[6][i];
                    col_data_in_7 <= padding_diagonal_A[7][i];

                    row_data_in_0 <= padding_diagonal_B[i][0];
                    row_data_in_1 <= padding_diagonal_B[i][1];
                    row_data_in_2 <= padding_diagonal_B[i][2];
                    row_data_in_3 <= padding_diagonal_B[i][3];
                    row_data_in_4 <= padding_diagonal_B[i][4];
                    row_data_in_5 <= padding_diagonal_B[i][5];
                    row_data_in_6 <= padding_diagonal_B[i][6];
                    row_data_in_7 <= padding_diagonal_B[i][7];
                end else begin
                    #(`clk_period);
                    col_data_in_0 <= padding_diagonal_A[0][i];
                    col_data_in_1 <= padding_diagonal_A[1][i];
                    col_data_in_2 <= padding_diagonal_A[2][i];
                    col_data_in_3 <= padding_diagonal_A[3][i];
                    col_data_in_4 <= padding_diagonal_A[4][i];
                    col_data_in_5 <= padding_diagonal_A[5][i];
                    col_data_in_6 <= padding_diagonal_A[6][i];
                    col_data_in_7 <= padding_diagonal_A[7][i];

                    row_data_in_0 <= padding_diagonal_B[i][0];
                    row_data_in_1 <= padding_diagonal_B[i][1];
                    row_data_in_2 <= padding_diagonal_B[i][2];
                    row_data_in_3 <= padding_diagonal_B[i][3];
                    row_data_in_4 <= padding_diagonal_B[i][4];
                    row_data_in_5 <= padding_diagonal_B[i][5];
                    row_data_in_6 <= padding_diagonal_B[i][6];
                    row_data_in_7 <= padding_diagonal_B[i][7];
                end
            end
        end
    endtask

    task read_task;
        begin
            out_data_rd_en = 1'b1;
            repeat (8) #(`clk_period);
            out_data_rd_en = 1'b0;
        end
    endtask

    task check_task;
        begin
            for(int i = 0; i < 8; i++) begin
                if(i == 0) begin
                    if(fifo_data_out[31:0] == C[0][i]) begin
                        $display("Column %d, Row 0, PASS!", i);
                    end else begin
                        $display("Column %d, Row 0, Failed..., Golden Answer = %h, Your Answer = %h", i, C[0][i], fifo_data_out[31:0]);
                    end
                    if(fifo_data_out[63:32] == C[1][i]) begin
                        $display("Column %d, Row 1, PASS!", i);
                    end else begin
                        $display("Column %d, Row 1, Failed..., Golden Answer = %h, Your Answer = %h", i, C[1][i], fifo_data_out[63:32]);
                    end
                    if(fifo_data_out[95:64] == C[2][i]) begin
                        $display("Column %d, Row 2, PASS!", i);
                    end else begin
                        $display("Column %d, Row 2, Failed..., Golden Answer = %h, Your Answer = %h", i, C[2][i], fifo_data_out[95:64]);
                    end
                    if(fifo_data_out[127:96] == C[3][i]) begin
                        $display("Column %d, Row 3, PASS!", i);
                    end else begin
                        $display("Column %d, Row 3, Failed..., Golden Answer = %h, Your Answer = %h", i, C[3][i], fifo_data_out[127:96]);
                    end
                    if(fifo_data_out[159:128] == C[4][i]) begin
                        $display("Column %d, Row 4, PASS!", i);
                    end else begin
                        $display("Column %d, Row 4, Failed..., Golden Answer = %h, Your Answer = %h", i, C[4][i], fifo_data_out[159:128]);
                    end
                    if(fifo_data_out[191:160] == C[5][i]) begin
                        $display("Column %d, Row 5, PASS!", i);
                    end else begin
                        $display("Column %d, Row 5, Failed..., Golden Answer = %h, Your Answer = %h", i, C[5][i], fifo_data_out[191:160]);
                    end
                    if(fifo_data_out[223:192] == C[6][i]) begin
                        $display("Column %d, Row 6, PASS!", i);
                    end else begin
                        $display("Column %d, Row 6, Failed..., Golden Answer = %h, Your Answer = %h", i, C[6][i], fifo_data_out[223:192]);
                    end
                    if(fifo_data_out[255:224] == C[7][i]) begin
                        $display("Column %d, Row 7, PASS!", i);
                    end else begin
                        $display("Column %d, Row 7, Failed..., Golden Answer = %h, Your Answer = %h", i, C[7][i], fifo_data_out[255:224]);
                    end
                end else begin
                    #(`clk_period);
                    if(fifo_data_out[31:0] == C[0][i]) begin
                        $display("Column %d, Row 0, PASS!", i);
                    end else begin
                        $display("Column %d, Row 0, Failed..., Golden Answer = %h, Your Answer = %h", i, C[0][i], fifo_data_out[31:0]);
                    end
                    if(fifo_data_out[63:32] == C[1][i]) begin
                        $display("Column %d, Row 1, PASS!", i);
                    end else begin
                        $display("Column %d, Row 1, Failed..., Golden Answer = %h, Your Answer = %h", i, C[1][i], fifo_data_out[63:32]);
                    end
                    if(fifo_data_out[95:64] == C[2][i]) begin
                        $display("Column %d, Row 2, PASS!", i);
                    end else begin
                        $display("Column %d, Row 2, Failed..., Golden Answer = %h, Your Answer = %h", i, C[2][i], fifo_data_out[95:64]);
                    end
                    if(fifo_data_out[127:96] == C[3][i]) begin
                        $display("Column %d, Row 3, PASS!", i);
                    end else begin
                        $display("Column %d, Row 3, Failed..., Golden Answer = %h, Your Answer = %h", i, C[3][i], fifo_data_out[127:96]);
                    end
                    if(fifo_data_out[159:128] == C[4][i]) begin
                        $display("Column %d, Row 4, PASS!", i);
                    end else begin
                        $display("Column %d, Row 4, Failed..., Golden Answer = %h, Your Answer = %h", i, C[4][i], fifo_data_out[159:128]);
                    end
                    if(fifo_data_out[191:160] == C[5][i]) begin
                        $display("Column %d, Row 5, PASS!", i);
                    end else begin
                        $display("Column %d, Row 5, Failed..., Golden Answer = %h, Your Answer = %h", i, C[5][i], fifo_data_out[191:160]);
                    end
                    if(fifo_data_out[223:192] == C[6][i]) begin
                        $display("Column %d, Row 6, PASS!", i);
                    end else begin
                        $display("Column %d, Row 6, Failed..., Golden Answer = %h, Your Answer = %h", i, C[6][i], fifo_data_out[223:192]);
                    end
                    if(fifo_data_out[255:224] == C[7][i]) begin
                        $display("Column %d, Row 7, PASS!", i);
                    end else begin
                        $display("Column %d, Row 7, Failed..., Golden Answer = %h, Your Answer = %h", i, C[7][i], fifo_data_out[255:224]);
                    end
                end
            end
        end
    endtask

    // Simulation
    initial begin
        // Initialization of signal
        rst_n = 1'b1;
        out_data_rd_en = 1'b0;

        // System Reset
		// Tip: When you create a test bench,
		// remember that the GSR pulse occurs automatically in the post-synthesis and post-implementation timing simulation.
		// This holds all registers in reset for the first 100 ns of the simulation.
		#100;

		//為了讓rst_n的negedge不要跟clk的posedge衝突
		//讓rst_n在clk的第二個negedge啟動
		// #(`clk_period/2);
		#(`clk_period);
		rst_n = 1'b0;
		#(`clk_period);
		rst_n = 1'b1;

        // fork
        //     begin
        //         write_task;
        //     end
        //     begin
        //         repeat (COL_A + 2 * ROW_A - 2) #(`clk_period);
        //         check_task;
        //     end
        // join

        write_task;

        #(`clk_period);
        col_data_in_7 = 8'd0;
        row_data_in_7 = 8'd0;

        #(`clk_period);
        // repeat (ROW_A - 3) #(`clk_period);

        fork
            begin
                read_task;
            end
            begin
                #(`clk_period);
                check_task;
            end
        join

        $display("Simulation Done!");
        #(`clk_period);
        #(`clk_period);
        $finish;
    end

endmodule
