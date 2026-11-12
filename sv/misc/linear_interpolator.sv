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

    output logic                 s_ready,
    input  logic                 s_valid,
    input  logic [WIDTH-1:0]     s_a,
    input  logic [WIDTH-1:0]     s_b,
    input  logic [-1:-PRECISION] s_alpha,

    input  logic                 m_ready,
    output logic                 m_valid,
    output logic [WIDTH-1:0]     m_q
);

    logic signed [WIDTH:0]            a;
    logic signed [WIDTH:0]            b;
    logic signed [0:-PRECISION]       alpha;

    logic signed [WIDTH:0]            a_reg     [3];
    logic signed [WIDTH:0]            b_reg     [1];
    logic signed [0:-PRECISION]       alpha_reg [2];
    logic                             valid_reg [3];

    logic signed [WIDTH+1:0]          b_minus_a;

    logic signed [WIDTH+1:-PRECISION] alpha_times_b_minus_a;

    logic signed [WIDTH+2:-PRECISION] q;

    assign a     = SIGNED ? {s_a[WIDTH-1], s_a} : {1'b0, s_a};
    assign b     = SIGNED ? {s_b[WIDTH-1], s_b} : {1'b0, s_b};
    assign alpha = {1'b0, s_alpha};

    assign m_q = q[WIDTH-1:0];

    assign s_ready = m_ready | ~m_valid;

    always_ff @(posedge clk) begin
        if (s_ready) begin
            a_reg[0] <= a;
            a_reg[1] <= a_reg[0];
            a_reg[2] <= a_reg[1];

            b_reg[0] <= b;

            alpha_reg[0] <= alpha;
            alpha_reg[1] <= alpha_reg[0];

            valid_reg[0] <= s_valid;
            valid_reg[1] <= valid_reg[0];
            valid_reg[2] <= valid_reg[1];

            b_minus_a             <= b_reg[0] - a_reg[0];
            alpha_times_b_minus_a <= b_minus_a * alpha_reg[1];
            q                     <= signed'({a_reg[2], {PRECISION{1'b0}}}) + alpha_times_b_minus_a;
            m_valid               <= valid_reg[2];
        end

        if (rst) begin
            m_valid      <= 0;
            valid_reg[0] <= 0;
            valid_reg[1] <= 0;
            valid_reg[2] <= 0;
        end
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

    function int calc(real a, real b, real alpha);
        return $rtoi($floor(a + (b - a) * alpha));
    endfunction

    property p;
        int a, b, alpha;
        @(posedge clk) disable iff ($sampled(rst))
        (s_valid, a = signed'(s_a), b = signed'(s_b), alpha = s_alpha) |->
            ##4 (m_valid, $display("a = %0d, b = %0d, alpha = %.2f, q = %0d, q_exp = %0d", a, b, alpha / 256.0, signed'(m_q), calc(a, b, alpha / 256.0)))
            ##0 signed'(m_q) == calc(a, b, alpha / 256.0)
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
            repeat (10000) begin
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