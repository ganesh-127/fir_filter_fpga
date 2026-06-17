`timescale 1ns / 1ps
//------------------------------------------------------
// mac_unit.sv
// 3-stage pipelined Multiply-Accumulate Unit
// Stage 1: Register inputs  (helps input-side timing)
// Stage 2: Multiply         (now operates on registered inputs)
// Stage 3: Accumulate
//
// UPDATED: Added input register stage to fix timing closure.
// Previous 2-stage version failed at 100MHz with
// WNS = -1.278ns, TNS = -21ns (8 identical failing paths,
// one per MAC instance in the generate loop).
// This 3-stage version breaks the combinational path so
// each stage fits within a single 10ns clock period.
//
// NOTE: Total pipeline latency per tap increases from
// 2 cycles to 3 cycles. Update LATENCY in your testbench:
//   localparam LATENCY = TAPS * 3 + 1;   // was TAPS * 2 + 1
//------------------------------------------------------
module mac_unit #(
    parameter integer DATA_WIDTH  = 16,
    parameter integer COEFF_WIDTH = 16,
    parameter integer ACC_WIDTH   = 36
)(
    input  logic                          clk,
    input  logic                          rst_n,
    input  logic                          valid_in,
    input  logic signed [DATA_WIDTH-1:0]  data_in,
    input  logic signed [COEFF_WIDTH-1:0] coeff_in,
    input  logic signed [ACC_WIDTH-1:0]   acc_in,
    output logic signed [ACC_WIDTH-1:0]   acc_out,
    output logic                          valid_out
);

    // --------------------------------------------------------
    // Stage 1: Register inputs
    // Breaks the path between upstream logic and the multiplier,
    // giving the multiplier a full clean clock period to work in.
    // --------------------------------------------------------
    logic signed [DATA_WIDTH-1:0]  data_r;
    logic signed [COEFF_WIDTH-1:0] coeff_r;
    logic signed [ACC_WIDTH-1:0]   acc_r;
    logic                          valid_s0;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_r   <= '0;
            coeff_r  <= '0;
            acc_r    <= '0;
            valid_s0 <= 1'b0;
        end else begin
            data_r   <= data_in;
            coeff_r  <= coeff_in;
            acc_r    <= acc_in;
            valid_s0 <= valid_in;
        end
    end

    // --------------------------------------------------------
    // Stage 2: Multiply
    // Operates on registered inputs from Stage 1 — isolated,
    // single-operation combinational path before next register.
    // --------------------------------------------------------
    logic signed [DATA_WIDTH+COEFF_WIDTH-1:0] mult_reg;
    logic signed [ACC_WIDTH-1:0]              acc_pass;
    logic                                      valid_s1;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mult_reg <= '0;
            acc_pass <= '0;
            valid_s1 <= 1'b0;
        end else begin
            mult_reg <= data_r * coeff_r;
            acc_pass <= acc_r;        // carry partial sum forward alongside
            valid_s1 <= valid_s0;
        end
    end

    // --------------------------------------------------------
    // Stage 3: Accumulate
    // Sign-extends the multiply result to ACC_WIDTH and adds
    // it to the partial sum carried through the pipeline.
    // --------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            acc_out   <= '0;
            valid_out <= 1'b0;
        end else begin
            acc_out   <= acc_pass + {{(ACC_WIDTH-(DATA_WIDTH+COEFF_WIDTH)){mult_reg[DATA_WIDTH+COEFF_WIDTH-1]}},
                                      mult_reg};
            valid_out <= valid_s1;
        end
    end

endmodule