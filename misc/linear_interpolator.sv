module linear_interpolator #(
    bit SIGNED    = 1,
    int WIDTH     = 8,
    int PRECISION = 4
)(
    input                clk,
    input                rst,

    output               s_ready,
    input                s_valid,
    input [WIDTH-1:0]    s_a,
    input [WIDTH-1:0]    s_b,
    input [0:-PRECISION] s_,

    output [WIDTH-1:0] q

);

    // q = a + s * b;

endmodule