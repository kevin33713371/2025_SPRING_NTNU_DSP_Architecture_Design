`timescale 1ns/1ps
`define clk_period 10

module log_scale_mul_tb();

    // Parameter
    parameter FLOAT_LEN = 16;
    parameter EXP_LEN = 5;
    parameter MANT_LEN = 10;
    parameter LUT_SIZE = 128;

    parameter NUM_TEST = 1000;

    // General signal
    logic clk, rst_n;

    // Logic Declaration for Instantiation
    logic [FLOAT_LEN-1:0] a_in, b_in;
    // logic mul_or_div;
    logic lut_wr_en;
    logic [MANT_LEN-1:0] log2_lut_data_in;
    logic [FLOAT_LEN-1:0] exp2_lut_data_in;
    logic [FLOAT_LEN-1:0] dut_out;

    // For debug
    // logic lut_wr_done;

    // Module Instantiation
    log_scale_mul LOG_MUL(
        .clk(clk),
        .rst_n(rst_n),
        .a(a_in),
        .b(b_in),
        // .mul_or_div(mul_or_div),
        .lut_wr_en(lut_wr_en),
        .log2_lut_data_in(log2_lut_data_in),
        .exp2_lut_data_in(exp2_lut_data_in),
        .result(dut_out)
        // .lut_wr_done(lut_wr_done)
    );

    //--------------------------------------------------
    //   CLK DECLARATION
    //--------------------------------------------------
    initial clk = 1'b0;
	always #(`clk_period/2) clk = ~clk;

    //--------------------------------------------------
    //   FUNCTION OR TASK DECLARATION
    //--------------------------------------------------
    // function: float -> float16
    function automatic logic [15:0] float_to_fp16;
        input shortreal val;
        logic [31:0] val_bits;
        logic sign;
        logic [7:0] exp_fp32;
        logic [22:0] mant_fp32;
        logic [4:0] exp_fp16;
        logic [9:0] mant_fp16;

        logic lsb, guard_bit, round_bit, sticky_bit;
        logic round_up;
        logic [MANT_LEN-1:0] mant_truncated;
        logic [(MANT_LEN+1)-1:0] mant_round;
        logic [24:0] sub_mant;

        val_bits = $shortrealtobits(val);

        sign = val_bits[31];
        exp_fp32 = val_bits[30:23];
        mant_fp32 = val_bits[22:0];

        if(exp_fp32 == 8'hFF) begin
            // Inf or NaN
            exp_fp16 = 5'h1F;
            mant_fp16 = (mant_fp32 == 0) ? 10'h000 : 10'h200;
        end
        else if(exp_fp32 > 142) begin // 127 + 15 = 142
            // Overflow: set to inf
            exp_fp16 = 5'h1F;
            mant_fp16 = 10'h000;
        end
        else if(exp_fp32 < 113) begin // 127 - 14 = 113
            // Underflow (denormals or zero)
            if(exp_fp32 < 103) begin
                // Too small, becomes zero
                exp_fp16 = 5'h00;
                mant_fp16 = 10'h000;
            end else begin
                // Subnormal number (no exponent)
                int shift = 113 - exp_fp32;
                exp_fp16 = 5'h00;
                sub_mant = {1'b1, mant_fp32} >> (shift);
                guard_bit = sub_mant[0];
                round_bit = 0;
                sticky_bit = 0;
                mant_truncated = sub_mant[10:1];
                round_up = guard_bit && (mant_truncated[0]);
                mant_fp16 = (round_up) ? mant_truncated + 1 : mant_truncated;
            end
        end
        else begin
            // Normalized Number
            exp_fp16 = exp_fp32 - 112; // 127 - 15
            mant_truncated = mant_fp32[22:13];
            lsb = mant_fp32[13];
            guard_bit = mant_fp32[12];
            round_bit = mant_fp32[11];
            sticky_bit = | mant_fp32[10:0];
            round_up = ((guard_bit && round_bit) || (guard_bit && ~round_bit && sticky_bit) || (lsb && guard_bit && ~round_bit && ~sticky_bit));

            if(round_up) begin
                mant_round = mant_truncated + 1;

                // Handle mantissa overflow
                if(mant_round == 11'h400) begin // overflow -> carry into exponent
                    mant_round = 11'h000;
                    exp_fp16 = exp_fp16 + 1;
                    if(exp_fp16 == 5'h1F) begin
                        // overflow to inf
                        mant_round = 11'h000;
                    end
                end
            end else begin
                mant_round = {1'b0, mant_truncated};
            end

            mant_fp16 = mant_round[9:0];
        end

        return {sign, exp_fp16, mant_fp16};
    endfunction

    // function: float16 -> float
    function automatic shortreal fp16_to_float;
        input logic [15:0] fp16;
        logic sign;
        logic [4:0] exp_fp16;
        logic [9:0] mant_fp16;
        logic [7:0] exp_fp32;
        logic [22:0] mant_fp32;
        logic [31:0] fp32;

        sign = fp16[15];
        exp_fp16 = fp16[14:10];
        mant_fp16 = fp16[9:0];

        if (exp_fp16 == 5'h1F) begin
            // Inf or NaN
            exp_fp32 = 8'hFF;
            mant_fp32 = (mant_fp16 == 0) ? 23'h000000 : 23'h400000;
        end else if (exp_fp16 == 5'h00) begin
            // Subnormal or zero
            if (mant_fp16 == 0) begin
                // Zero
                exp_fp32 = 8'h00;
                mant_fp32 = 23'h000000;
            end else begin
                // Subnormal: normalize it
                int shift = 0;
                logic [9:0] mant_tmp = mant_fp16;
                while (mant_tmp[9] == 0) begin
                    mant_tmp <<= 1;
                    shift++;
                end
                mant_tmp = mant_tmp & 10'h3FF; // Remove implicit 1
                exp_fp32 = 8'd127 - 14 - shift; // Bias: 127 for fp32, 15 for fp16
                mant_fp32 = {mant_tmp[8:0], 14'b0}; // align to 23 bits
            end
        end else begin
            // Normalized number
            exp_fp32 = exp_fp16 + 112; // 127 - 15
            mant_fp32 = {mant_fp16, 13'b0}; // align to 23 bits (10-bit mant to 23-bit)
        end

        fp32 = {sign, exp_fp32, mant_fp32};

        return $bitstoshortreal(fp32);
    endfunction

    // Produce random input & output
    real ra_real[NUM_TEST], rb_real[NUM_TEST];
    shortreal ra[NUM_TEST], rb[NUM_TEST];
    logic [FLOAT_LEN-1:0] ra_fp16[NUM_TEST], rb_fp16[NUM_TEST];
    shortreal golden_result[NUM_TEST];
    initial begin
        for(int i = 0; i < NUM_TEST; i++) begin
            ra_real[i] = ($urandom_range(0, 1) ? 1.0 : -1.0) * (($urandom() % 10000) / 1000.0);
            rb_real[i] = ($urandom_range(0, 1) ? 1.0 : -1.0) * (($urandom() % 10000) / 1000.0);
            ra[i] = ra_real[i];
            rb[i] = rb_real[i];
            ra_fp16[i] = float_to_fp16(ra[i]);
            rb_fp16[i] = float_to_fp16(rb[i]);
            golden_result[i] = ra[i] * rb[i];
        end
    end

    // Load exponent and log data from txt file
    logic [FLOAT_LEN-1:0] exp2_lut_128 [0:LUT_SIZE-1];
    logic [MANT_LEN-1:0] log2_lut_128 [0:LUT_SIZE-1];
    initial begin
        $readmemh("exp2_lut_128_new.txt", exp2_lut_128);
        $readmemh("log2_lut_128_new.txt", log2_lut_128);
    end

    // integer for writing lut data
    integer wr_lut_i;

    // task: write lut data
    task write_lut_data;
        begin
            for(wr_lut_i = 0; wr_lut_i < LUT_SIZE; wr_lut_i = wr_lut_i + 1) begin
                #(`clk_period);
                lut_wr_en = 1'b1;
                log2_lut_data_in = log2_lut_128[wr_lut_i];
                exp2_lut_data_in = exp2_lut_128[wr_lut_i];
            end

            #(`clk_period);
            lut_wr_en = 1'b0;
        end
    endtask

    // integer for writing data
    integer wr_i;

    // task: write data
    task write_data;
        begin
            for(wr_i = 0; wr_i < NUM_TEST; wr_i = wr_i + 1) begin
                #(`clk_period);
                a_in = ra_fp16[wr_i];
                b_in = rb_fp16[wr_i];
            end
        end
    endtask

    // integer for golden check
    integer ch_i;

    // task: golden answer check
    task golden_check;
        begin
            automatic int fail_count = 0;
            shortreal error, error_abs, golden_abs, error_rate;

            // wait two cycle for pipeline output
            #(`clk_period);
            #(`clk_period);
            #(`clk_period);
            #(`clk_period);
            for(ch_i = 4; ch_i < NUM_TEST + 4; ch_i = ch_i + 1) begin
                #(`clk_period);

                error = fp16_to_float(dut_out) - golden_result[ch_i - 4];
                error_abs = (error > 0) ? error : -error;
                golden_abs = (golden_result[ch_i - 4] > 0) ? golden_result[ch_i - 4] : -golden_result[ch_i - 4];
                error_rate = error_abs/golden_abs;

                if(error_abs > 0.019 * golden_abs) begin
                    $display("MISMATCH at %0d", ch_i - 4);
                    $display("  a      = %f (0x%h)", ra[ch_i - 4], a_in);
                    $display("  b      = %f (0x%h)", rb[ch_i - 4], b_in);
                    $display("  DUT    = 0x%h (%.6f)", dut_out, fp16_to_float(dut_out));
                    $display("  GOLDEN = %.6f", golden_result[ch_i - 4]);
                    $display("  ERROR = %.6f", error_abs);
                    $display("  ERROR RATE = %.6f", error_rate);
                    fail_count++;
                end else begin
                    $display("PASS at %0d", ch_i - 4);
                    $display("  a      = %f (0x%h)", ra[ch_i - 4], a_in);
                    $display("  b      = %f (0x%h)", rb[ch_i - 4], b_in);
                    $display("  DUT    = 0x%h (%.6f)", dut_out, fp16_to_float(dut_out));
                    $display("  GOLDEN = %.6f", golden_result[ch_i - 4]);
                    $display("  ERROR = %.6f", error_abs);
                    $display("  ERROR RATE = %.6f", error_rate);
                end
            end

            #(`clk_period);
            $display("\n Test Finished. Total: %0d, Failures: %0d", NUM_TEST, fail_count);
        end
    endtask

    // Simulation
    initial begin
        // Initialization of signal
        rst_n = 1'b1;
        lut_wr_en = 1'b0;
        // mul_or_div = 1'b0;

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

        write_lut_data;

        fork
            begin
                write_data;
            end
            // begin
            //     mul_or_div_control;
            // end
            begin
                golden_check;
            end
        join

        $finish;
    end

endmodule