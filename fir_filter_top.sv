`timescale 1ns / 1ps
module fir_filter_top #(
    parameter integer TAPS        = 8,
    parameter integer DATA_WIDTH  = 16,
    parameter integer COEFF_WIDTH = 16,
    parameter integer ACC_WIDTH   = 36
)(
    input  logic                          clk,
    input  logic                          rst_n,
    input  logic                          valid_in,
    input  logic signed [DATA_WIDTH-1:0]  x_in,
    output logic                          valid_out,
    output logic signed [DATA_WIDTH-1:0]  y_out
);

    // --------------------------------------------------------
    // Delay Line
    // --------------------------------------------------------
    logic signed [DATA_WIDTH-1:0] delay_line [0:TAPS-1];
    logic valid_delay;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < TAPS; i++)
                delay_line[i] <= '0;
            valid_delay <= 1'b0;
        end else begin
            delay_line[0] <= x_in;
            valid_delay   <= valid_in;
            for (int i = 1; i < TAPS; i++)
                delay_line[i] <= delay_line[i-1];
        end
    end

    // --------------------------------------------------------
    // FIX: Each tap gets its OWN coefficient directly
    // Previous version had ONE rom address for ALL taps — WRONG
    // Now each tap[i] always reads coeff[i] directly
    // --------------------------------------------------------
    logic signed [COEFF_WIDTH-1:0] coeff [0:TAPS-1];

    // Instantiate ROM for each tap with fixed address
    genvar c;
    generate
        for (c = 0; c < TAPS; c = c + 1) begin : gen_coeff
            coeff_rom #(
                .TAPS       (TAPS),
                .COEFF_WIDTH(COEFF_WIDTH),
                .ADDR_WIDTH (3)
            ) u_rom (
                .clk      (clk),
                .addr     (c[2:0]),      // FIXED address per tap
                .coeff_out(coeff[c])
            );
        end
    endgenerate

    // --------------------------------------------------------
    // Pipelined MAC Chain
    // --------------------------------------------------------
    logic signed [ACC_WIDTH-1:0] acc_chain   [0:TAPS];
    logic                        valid_chain [0:TAPS];

    assign acc_chain[0]   = '0;
    assign valid_chain[0] = valid_delay;

    genvar tap;
    generate
        for (tap = 0; tap < TAPS; tap = tap + 1) begin : gen_mac
            mac_unit #(
                .DATA_WIDTH (DATA_WIDTH),
                .COEFF_WIDTH(COEFF_WIDTH),
                .ACC_WIDTH  (ACC_WIDTH)
            ) u_mac (
                .clk      (clk),
                .rst_n    (rst_n),
                .valid_in (valid_chain[tap]),
                .data_in  (delay_line[TAPS-1-tap]),
                .coeff_in (coeff[tap]),          // FIX: each tap its own coeff
                .acc_in   (acc_chain[tap]),
                .acc_out  (acc_chain[tap+1]),
                .valid_out(valid_chain[tap+1])
            );
        end
    endgenerate

    // --------------------------------------------------------
    // Output
    // --------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            y_out     <= '0;
            valid_out <= 1'b0;
        end else begin
            y_out     <= acc_chain[TAPS][DATA_WIDTH+COEFF_WIDTH-2 : COEFF_WIDTH-1];
            valid_out <= valid_chain[TAPS];
        end
    end

endmodule