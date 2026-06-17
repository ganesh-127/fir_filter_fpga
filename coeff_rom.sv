`timescale 1ns / 1ps
module coeff_rom #(
    parameter integer TAPS        = 8,
    parameter integer COEFF_WIDTH = 16,
    parameter integer ADDR_WIDTH  = 3
)(
    input  logic                          clk,
    input  logic [ADDR_WIDTH-1:0]         addr,
    output logic signed [COEFF_WIDTH-1:0] coeff_out
);
    // Asynchronous read — simpler, no 1-cycle delay issue
    logic signed [COEFF_WIDTH-1:0] rom [0:TAPS-1];

    initial begin
        rom[0] = 16'sd46;
        rom[1] = 16'sd203;
        rom[2] = 16'sd502;
        rom[3] = 16'sd795;
        rom[4] = 16'sd795;
        rom[5] = 16'sd502;
        rom[6] = 16'sd203;
        rom[7] = 16'sd46;
    end

    // CHANGED: Asynchronous read to avoid address-data mismatch
    assign coeff_out = rom[addr];

endmodule