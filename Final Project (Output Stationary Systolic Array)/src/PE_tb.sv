`timescale 1ns/1ps
`define clk_period 10

module PE_tb();
    // Parameter
    parameter IP_DATA_WIDTH = 8;
    parameter OP_DATA_WIDTH = 32;

    // General Signal
    logic clk, rst_n;

    // Logic Declaration for Instantiation
    logic [IP_DATA_WIDTH-1:0] in_data_0, in_data_1;
    logic [IP_DATA_WIDTH-1:0] out_data_0, out_data_1;
    logic [OP_DATA_WIDTH-1:0] pe_out_reg;
    // For debug
    // logic [OP_DATA_WIDTH-1:0] pe_val;

    // Module Instantiation
    PE PE_DUT(
        .*
    );

    //--------------------------------------------------
    //   CLK DECLARATION
    //--------------------------------------------------
    initial clk = 1'b0;
	always #(`clk_period/2) clk = ~clk;

    // Simulation
    initial begin
        // Initialization of signal
        rst_n = 1'b1;

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

        // #(`clk_period);
		in_data_0 = 8'd1;
        in_data_1 = 8'd1;
        #(`clk_period);
		in_data_0 = 8'd2;
        in_data_1 = 8'd2;
        #(`clk_period);
		in_data_0 = 8'd3;
        in_data_1 = 8'd3;
        #(`clk_period);
		in_data_0 = 8'd4;
        in_data_1 = 8'd4;
        #(`clk_period);
		in_data_0 = 8'd5;
        in_data_1 = 8'd5;
        #(`clk_period);
		in_data_0 = 8'd6;
        in_data_1 = 8'd6;
        #(`clk_period);
		in_data_0 = 8'd7;
        in_data_1 = 8'd7;
        #(`clk_period);
		in_data_0 = 8'd8;
        in_data_1 = 8'd8;

        #(`clk_period);
        if(pe_out_reg == 204) begin
            $display("PASS!");
        end else begin
            $display("Failed..., Golden Answer = 204, Your Answer = %d", pe_out_reg);
        end

        #(`clk_period);
        #(`clk_period);
        $finish;
    end

endmodule