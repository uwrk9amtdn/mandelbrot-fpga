// q = a + alpha * (b - a)
module linear_interpolator #(
    bit SIGNED    = 1, // is a and b signed
    int WIDTH     = 8, // data width
    int PRECISION = 4  // alpha fraction bits
)(
    input                clk,
    input                rst,

    output               s_ready,
    input                s_valid,
    input [WIDTH-1:0]    s_a,
    input [WIDTH-1:0]    s_b,
    input [0:-PRECISION] s_alpha,

    input              m_ready,
    output             m_valid
    output [WIDTH-1:0] m_q,
);

    logic [WIDTH-1:0] q_reg;

    always_comb begin
        if (SIGNED) begin
            q_reg = signed'(s_a) + signed'({1'b0, s_alpha}) * (signed'(s_b) - signed'(s_a));
        end else begin
            q_reg = s_a + s_alpha * (s_b - s_a);
        end
    end

    always_ff @(posedge clk) begin

        if (rst) begin

        end
    end

endmodule