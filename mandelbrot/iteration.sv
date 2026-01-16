module mandelbrot_iterator #(
    FRAC_BITS = 32,
    MUL_LATENCY = 2,
    ADD_SUB_LATENCY = 2
)(
    input clk,

    input  signed [2:-FRAC_BITS] a,
    input  signed [2:-FRAC_BITS] b,
    input  signed [2:-FRAC_BITS] a2,
    input  signed [2:-FRAC_BITS] b2,
    input  signed [2:-FRAC_BITS] c,
    input  signed [2:-FRAC_BITS] d,

    output signed [2:-FRAC_BITS] a_n,
    output signed [2:-FRAC_BITS] b_n,
    output signed [2:-FRAC_BITS] a2_n,
    output signed [2:-FRAC_BITS] b2_n,

    output finish
);

    localparam TOTAL_LATENCY = MUL_LATENCY + ADD_SUB_LATENCY;

    logic signed [5:-FRAC_BITS] a_mul_a;
    logic signed [5:-FRAC_BITS] b_mul_b;
    logic signed [3:-FRAC_BITS] a2_add_b2;
    logic signed [3:-FRAC_BITS] a2_sub_b2;
    logic signed [3:-FRAC_BITS] a2_sub_b2_add_c;
    logic signed [5:-FRAC_BITS] a_mul_b;
    logic signed [3:-FRAC_BITS] a_mul_b_mul_2_add_d;
    logic signed [2:-FRAC_BITS] a_mul_b_mul_2;

    mul_dsp mul1 #(.INT_BITS(2), .FRAC_BITS(FRAC_BITS), .LATENCY())(clk, a, a, a_mul_a);
    mul_dsp mul2 #(.INT_BITS(2), .FRAC_BITS(FRAC_BITS), .LATENCY())(clk, b, b, b_mul_b);
    mul_dsp mul3 #(.INT_BITS(2), .FRAC_BITS(FRAC_BITS), .LATENCY())(clk, b, b, b_mul_b);
    add     add1 #(.INT_BITS(2), .FRAC_BITS(FRAC_BITS), .LATENCY())(clk, a2, b2, a2_add_b2);
    add     add2 #(.INT_BITS(2), .FRAC_BITS(FRAC_BITS), .LATENCY())(clk, a2_sub_b2[2:-FRAC_BITS], c, a2_sub_b2_add_c);
    sub     sub1 #(.INT_BITS(2), .FRAC_BITS(FRAC_BITS), .LATENCY())(clk, a2, b2, a2_sub_b2);


    always @(posedge clk) begin

        a2_minus_b2 <= a2 - b2;
        a2_minus_b2_plus_c <= a2_minus_b2 + c;



    end

endmodule