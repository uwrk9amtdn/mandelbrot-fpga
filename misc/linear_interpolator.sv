// q = a + alpha * (b - a)
// TODO: round to nearest

(* use_dsp = "yes" *)
module linear_interpolator #(
    bit SIGNED    = 1, // is a, b and q signed
    int WIDTH     = 4, // data width
    int PRECISION = 4  // alpha fraction bits
)(
    input  logic                 clk,
    input  logic                 rst,

    input  logic                 s_valid,
    input  logic [WIDTH-1:0]     s_a,
    input  logic [WIDTH-1:0]     s_b,
    input  logic [-1:-PRECISION] s_alpha,

    output logic                 m_valid,
    output logic [WIDTH-1:0]     m_q
);

    logic signed [WIDTH:0]            a;
    logic signed [WIDTH:0]            b;
    logic signed [0:-PRECISION]       alpha;

    logic signed [WIDTH:0]            a_reg     [3];
    logic signed [WIDTH:0]            b_reg     [3];
    logic signed [0:-PRECISION]       alpha_reg [3];
    logic                             valid_reg [3];

    logic signed [WIDTH+1:0]          b_minus_a;

    logic signed [WIDTH+1:-PRECISION] alpha_times_b_minus_a;

    logic signed [WIDTH+2:-PRECISION] q;

    assign a     = SIGNED ? {s_a[WIDTH-1], s_a} : {1'b0, s_a};
    assign b     = SIGNED ? {s_b[WIDTH-1], s_b} : {1'b0, s_b};
    assign alpha = {1'b0, s_alpha};

    assign m_q     = q[WIDTH-1:0];
    assign m_valid = valid_reg[2];

    always_ff @(posedge clk) begin
        a_reg     [0] <= a;
        b_reg     [0] <= b;
        alpha_reg [0] <= alpha;
        valid_reg [0] <= s_valid;
        for (int i = 0; i < 2; i++) begin
            a_reg     [i+1] <= a_reg     [i];
            b_reg     [i+1] <= b_reg     [i];
            alpha_reg [i+1] <= alpha_reg [i];
            valid_reg [i+1] <= valid_reg [i];
        end

        b_minus_a             <= b_reg[0] - a_reg[0];
        alpha_times_b_minus_a <= b_minus_a * alpha_reg[1];
        q                     <= signed'({a_reg[2], PRECISION'(0)}) + alpha_times_b_minus_a;
    end
endmodule


`ifdef TESTBENCH

`timescale 1ns/1ps
module tb;

    logic         clk;
    logic         rst;

    logic         s_valid;
    logic [7:0]   s_a;
    logic [7:0]   s_b;
    logic [-1:-8] s_alpha;

    logic         m_valid;
    logic [7:0]   m_q;

    linear_interpolator #(
        .SIGNED    (1),
        .WIDTH     (8),
        .PRECISION (8)
    ) li ( .* );

    function logic [7:0] calc(logic [7:0] a, logic [7:0] b, logic [-1:-8] alpha);
        return signed'(a) + (signed'(b) - signed'(a)) * signed'({1'b0, alpha});
    endfunction

    property p;
        logic [7:0] a, b;
        logic [-1:-8] alpha;

        @(posedge clk) disable iff ($sampled(rst))
        (s_valid, a = s_a, b = s_b, alpha = s_alpha) |-> ##4 (m_valid && m_q == calc(a, b, alpha), $display("a = %0d, b = %0d, alpha = %.2f, q = %d", signed'(a), signed'(b), signed'(alpha) / 256.0, signed'(m_q)))
    endproperty

    assert property (p);

    initial begin
        clk     <= 0;
        rst     <= 0;
        s_valid <= 0;
        s_a     <= 0;
        s_b     <= 0;
        s_alpha <= 0;

        fork
            forever #5 clk <= ~clk;
            repeat (100) begin
                @(posedge clk);
                s_valid <= $urandom;
                s_a     <= $urandom;
                s_b     <= $urandom;
                s_alpha <= $urandom;
            end
        join_any

        $finish;

    end

endmodule

`endif