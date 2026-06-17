`timescale 1ns / 1ps
module tb_fir_filter;

    parameter integer TAPS        = 8;
    parameter integer DATA_WIDTH  = 16;
    parameter integer COEFF_WIDTH = 16;

    logic clk, rst_n, valid_in, valid_out;
    logic signed [DATA_WIDTH-1:0] x_in, y_out;

    // DUT
    fir_filter_top #(
        .TAPS       (TAPS),
        .DATA_WIDTH (DATA_WIDTH),
        .COEFF_WIDTH(COEFF_WIDTH)
    ) dut (
        .clk      (clk),
        .rst_n    (rst_n),
        .valid_in (valid_in),
        .x_in     (x_in),
        .valid_out(valid_out),
        .y_out    (y_out)
    );

    // 100 MHz clock
    initial clk = 0;
    always #5 clk = ~clk;

    // Pipeline latency = TAPS*2 (2 stages per MAC) + 1 output reg
    localparam LATENCY = TAPS * 3 + 1;

    initial begin
        // ---- Reset ----
        rst_n    = 1'b0;
        valid_in = 1'b0;
        x_in     = 16'sd0;
        repeat(10) @(posedge clk);  // hold reset longer
        @(negedge clk);             // release on negedge to avoid setup issues
        rst_n = 1'b1;
        repeat(3) @(posedge clk);

        // ================================================
        // TEST 1: Impulse — send ONE sample then zeros
        // Expected: coefficients appear one by one at output
        // ================================================
        $display("\n=== TEST 1: Impulse Response ===");
        @(negedge clk);
        valid_in = 1'b1;
        x_in     = 16'sd1000;    // impulse value

        @(negedge clk);
        x_in     = 16'sd0;       // back to zero

        // FIX: Keep valid_in HIGH for TAPS cycles
        // so all delay line positions are filled
        repeat(TAPS - 1) @(negedge clk);
        valid_in = 1'b0;

        // Wait for pipeline to drain
        repeat(LATENCY + 5) @(posedge clk);

        // ================================================
        // TEST 2: DC Input — constant value
        // Expected: output = input * sum(coefficients)
        // sum = 46+203+502+795+795+502+203+46 = 3092
        // so y = 100 * 3092 / 32768 ≈ 9 (after Q scaling)
        // ================================================
        $display("\n=== TEST 2: DC Input ===");
        repeat(TAPS * 4) begin
            @(negedge clk);
            valid_in = 1'b1;
            x_in     = 16'sd100;
        end
        repeat(LATENCY) @(posedge clk);
        valid_in = 1'b0;
        repeat(5) @(posedge clk);

        // ================================================
        // TEST 3: Step Input — ramp up
        // ================================================
        $display("\n=== TEST 3: Step Input ===");
        repeat(TAPS * 3) begin
            @(negedge clk);
            valid_in = 1'b1;
            x_in     = 16'sd5000;
        end
        repeat(LATENCY) @(posedge clk);
        valid_in = 1'b0;
        repeat(5) @(posedge clk);

        // ================================================
        // TEST 4: High Frequency alternating
        // Low-pass should attenuate — output near zero
        // ================================================
        $display("\n=== TEST 4: High Freq (should attenuate) ===");
        repeat(TAPS * 4) begin
            @(negedge clk);
            valid_in = 1'b1;
            x_in     = 16'sd5000;
            @(negedge clk);
            x_in     = -16'sd5000;
        end
        repeat(LATENCY) @(posedge clk);
        valid_in = 1'b0;
        repeat(5) @(posedge clk);

        $display("\n=== ALL TESTS COMPLETE ===");
        $finish;
    end

    // Monitor — print every valid output
    always @(posedge clk) begin
        if (rst_n && valid_out)
            $display("T=%0t ns | x_in=%0d | y_out=%0d",
                      $time, $signed(x_in), $signed(y_out));
    end

    // Basic assertions
    always @(posedge clk) begin
        if (rst_n && valid_out) begin
            if ($isunknown(y_out))
                $error("T=%0t: y_out is X!", $time);
        end
        if (!rst_n && y_out !== '0)
            $error("T=%0t: y_out not zero during reset!", $time);
    end

endmodule