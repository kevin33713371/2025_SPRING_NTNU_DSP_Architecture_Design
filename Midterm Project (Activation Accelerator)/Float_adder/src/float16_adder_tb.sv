`timescale 1ns/1ps

module float16_adder_tb();

    // Parameter
    parameter FLOAT_LEN = 16;
    parameter EXP_LEN = 5;
    parameter MANT_LEN = 10;

    parameter NUM_TEST = 500;

    // General signal

    // Logic Declaration for Instantiation
    logic [FLOAT_LEN-1:0] a_in, b_in;
    logic [FLOAT_LEN-1:0] dut_out;
    shortreal golden_out;

    // Module Instantiation
    float16_adder F16_ADD_DUT(
        .a(a_in),
        .b(b_in),
        .result(dut_out)
    );

    //--------------------------------------------------
    //   CLK DECLARATION
    //--------------------------------------------------

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
                // Subnormal
                int shift = 113 - exp_fp32;
                exp_fp16 = 5'h00;
                mant_fp16 = (mant_fp32|23'h400000) >> (shift + 1);
            end
        end
        else begin
            // Normalized Number
            exp_fp16 = exp_fp32 - 112; // 127 - 15
            mant_fp16 = mant_fp32[22:13];
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
                exp_fp32 = 8'd127 - 15 - shift;
                mant_fp32 = mant_tmp[8:0] << 14;
            end
        end else begin
            // Normalized number
            exp_fp32 = exp_fp16 + 112; // 127 - 15
            mant_fp32 = mant_fp16 << 13;
        end

        fp32 = {sign, exp_fp32, mant_fp32};

        return $bitstoshortreal(fp32);
    endfunction

    // Golden reference adder (float adder and truncate [31:16])
    function automatic shortreal golden_adder;
        input shortreal a, b;
        shortreal sum;
        sum = a + b;
        return sum;
    endfunction

    // Produce random input
    real ra_real[NUM_TEST], rb_real[NUM_TEST];
    shortreal ra[NUM_TEST], rb[NUM_TEST];
    initial begin
        for(int i = 0; i < NUM_TEST; i++) begin
            ra_real[i] = ($urandom_range(0, 1) ? 1.0 : -1.0) * (($urandom() % 100000) / 1000.0);
            rb_real[i] = ($urandom_range(0, 1) ? 1.0 : -1.0) * (($urandom() % 100000) / 1000.0);
            ra[i] = ra_real[i];
            rb[i] = rb_real[i];
        end
    end

    // Simulation
    initial begin
        automatic int fail_count = 0;
        shortreal error, error_abs;

        for(int i = 0; i < NUM_TEST; i++) begin
            if(i == 0) begin
                fork
                    begin
                        a_in = float_to_fp16(ra[i]);
                        b_in = float_to_fp16(rb[i]);
                        golden_out = golden_adder(ra[i], rb[i]);
                    end
                    begin
                        #1;
                        error = fp16_to_float(dut_out) - golden_out;
                        error_abs = (error > 0) ? error : -error;
                        if((fp16_to_float(dut_out) - golden_out) > 0.2) begin
                            $display("MISMATCH at %0d", i);
                            $display("  a      = %f (0x%h)", ra[i], a_in);
                            $display("  b      = %f (0x%h)", rb[i], b_in);
                            $display("  DUT    = 0x%h (%.6f)", dut_out, fp16_to_float(dut_out));
                            $display("  GOLDEN = %.6f", golden_out);
                            $display("  ERROR = %.6f", error_abs);
                            fail_count++;
                        end else begin
                            $display("PASS at %0d", i);
                            $display("  a      = %f (0x%h)", ra[i], a_in);
                            $display("  b      = %f (0x%h)", rb[i], b_in);
                            $display("  DUT    = 0x%h (%.6f)", dut_out, fp16_to_float(dut_out));
                            $display("  GOLDEN = %.6f", golden_out);
                            $display("  ERROR = %.6f", error_abs);
                        end
                    end
                join
            end else begin
                #10;
                fork
                    begin
                        a_in = float_to_fp16(ra[i]);
                        b_in = float_to_fp16(rb[i]);
                        golden_out = golden_adder(ra[i], rb[i]);
                    end
                    begin
                        #1;
                        error = fp16_to_float(dut_out) - golden_out;
                        error_abs = (error > 0) ? error : -error;
                        if((fp16_to_float(dut_out) - golden_out) > 0.2) begin
                            $display("MISMATCH at %0d", i);
                            $display("  a      = %f (0x%h)", ra[i], a_in);
                            $display("  b      = %f (0x%h)", rb[i], b_in);
                            $display("  DUT    = 0x%h (%.6f)", dut_out, fp16_to_float(dut_out));
                            $display("  GOLDEN = %.6f", golden_out);
                            $display("  ERROR = %.6f", error_abs);
                            fail_count++;
                        end else begin
                            $display("PASS at %0d", i);
                            $display("  a      = %f (0x%h)", ra[i], a_in);
                            $display("  b      = %f (0x%h)", rb[i], b_in);
                            $display("  DUT    = 0x%h (%.6f)", dut_out, fp16_to_float(dut_out));
                            $display("  GOLDEN = %.6f", golden_out);
                            $display("  ERROR = %.6f", error_abs);
                        end
                    end
                join
            end
        end

        #10;
        $display("\n Test Finished. Total: %0d, Failures: %0d", NUM_TEST, fail_count);
        $finish;
    end


endmodule