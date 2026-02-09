module single_iteration #(
    FRAC_WIDTH = 32
)(
    input clk,

    input  signed [2:-FRAC_WIDTH] s_a,
    input  signed [2:-FRAC_WIDTH] s_b,
    input  signed [2:-FRAC_WIDTH] s_a2,
    input  signed [2:-FRAC_WIDTH] s_b2,
    input  signed [2:-FRAC_WIDTH] s_c,
    input  signed [2:-FRAC_WIDTH] s_d,

    output signed [2:-FRAC_WIDTH] m_a,
    output signed [2:-FRAC_WIDTH] m_b,
    output signed [2:-FRAC_WIDTH] m_a2,
    output signed [2:-FRAC_WIDTH] m_b2,
    output                        m_stop
);

    localparam LATENCY = 4;

    // logic signed [5:-FRAC_WIDTH] a_mul_a;
    // logic signed [5:-FRAC_WIDTH] b_mul_b;
    // logic signed [3:-FRAC_WIDTH] a2_add_b2;
    // logic signed [3:-FRAC_WIDTH] a2_sub_b2;
    // logic signed [3:-FRAC_WIDTH] a2_sub_b2_add_c;
    // logic signed [5:-FRAC_WIDTH] a_mul_b;
    // logic signed [3:-FRAC_WIDTH] a_mul_b_mul_2_add_d;
    // logic signed [2:-FRAC_WIDTH] a_mul_b_mul_2;

    // mul_dsp mul1 #(.INT_BITS(2), .FRAC_WIDTH(FRAC_WIDTH), .LATENCY(MUL_LATENCY))     (clk, a, a, a_mul_a);
    // mul_dsp mul2 #(.INT_BITS(2), .FRAC_WIDTH(FRAC_WIDTH), .LATENCY(MUL_LATENCY))     (clk, b, b, b_mul_b);
    // mul_dsp mul3 #(.INT_BITS(2), .FRAC_WIDTH(FRAC_WIDTH), .LATENCY(MUL_LATENCY))     (clk, b, b, b_mul_b);
    // add     add1 #(.INT_BITS(2), .FRAC_WIDTH(FRAC_WIDTH), .LATENCY(ADD_SUB_LATENCY)) (clk, a2, b2, a2_add_b2);
    // add     add2 #(.INT_BITS(2), .FRAC_WIDTH(FRAC_WIDTH), .LATENCY(ADD_SUB_LATENCY)) (clk, a2_sub_b2[2:-FRAC_WIDTH], c, a2_sub_b2_add_c);
    // sub     sub1 #(.INT_BITS(2), .FRAC_WIDTH(FRAC_WIDTH), .LATENCY(ADD_SUB_LATENCY)) (clk, a2, b2, a2_sub_b2);


    // always @(posedge clk) begin
    //     a2_minus_b2 <= a2 - b2;
    //     a2_minus_b2_plus_c <= a2_minus_b2 + c;
    // end

endmodule