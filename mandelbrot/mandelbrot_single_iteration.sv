module mandelbrot_single_iteration #(
    FRAC_BITS       = 32,
    MUL_LATENCY     = 2,
    ADD_SUB_LATENCY = 2
)(
    input clk,

    input  signed [2:-FRAC_BITS] s_a,
    input  signed [2:-FRAC_BITS] s_b,
    input  signed [2:-FRAC_BITS] s_a2,
    input  signed [2:-FRAC_BITS] s_b2,
    input  signed [2:-FRAC_BITS] s_c,
    input  signed [2:-FRAC_BITS] s_d,

    output signed [2:-FRAC_BITS] m_a,
    output signed [2:-FRAC_BITS] m_b,
    output signed [2:-FRAC_BITS] m_a2,
    output signed [2:-FRAC_BITS] m_b2,
    output                       m_stop
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

    mul_dsp mul1 #(.INT_BITS(2), .FRAC_BITS(FRAC_BITS), .LATENCY(MUL_LATENCY))     (clk, a, a, a_mul_a);
    mul_dsp mul2 #(.INT_BITS(2), .FRAC_BITS(FRAC_BITS), .LATENCY(MUL_LATENCY))     (clk, b, b, b_mul_b);
    mul_dsp mul3 #(.INT_BITS(2), .FRAC_BITS(FRAC_BITS), .LATENCY(MUL_LATENCY))     (clk, b, b, b_mul_b);
    add     add1 #(.INT_BITS(2), .FRAC_BITS(FRAC_BITS), .LATENCY(ADD_SUB_LATENCY)) (clk, a2, b2, a2_add_b2);
    add     add2 #(.INT_BITS(2), .FRAC_BITS(FRAC_BITS), .LATENCY(ADD_SUB_LATENCY)) (clk, a2_sub_b2[2:-FRAC_BITS], c, a2_sub_b2_add_c);
    sub     sub1 #(.INT_BITS(2), .FRAC_BITS(FRAC_BITS), .LATENCY(ADD_SUB_LATENCY)) (clk, a2, b2, a2_sub_b2);


    always @(posedge clk) begin
        a2_minus_b2 <= a2 - b2;
        a2_minus_b2_plus_c <= a2_minus_b2 + c;
    end

endmodule