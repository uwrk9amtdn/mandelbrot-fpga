// q = a + alpha * (b - a)

(* use_dsp = "yes" *)
module linear_interpolator #(
    bit SIGNED    = 1, // is a, b and q signed
    int WIDTH     = 4, // data width
    int PRECISION = 4  // alpha fraction bits
)(
    input  logic                 clk,

    input  logic [WIDTH-1:0]     a,
    input  logic [WIDTH-1:0]     b,
    input  logic [-1:-PRECISION] alpha,

    output logic [WIDTH-1:0]     q
);

    logic signed [WIDTH:0]            a_;
    logic signed [WIDTH:0]            b_;
    logic signed [0:-PRECISION]       alpha_;
    logic signed [WIDTH+1:-PRECISION] alpha_times_b_minus_a;

    assign a_                    = SIGNED ? {a[WIDTH-1], a} : {1'b0, a};
    assign b_                    = SIGNED ? {b[WIDTH-1], b} : {1'b0, b};
    assign alpha_                = {1'b0, alpha};
    assign alpha_times_b_minus_a = alpha_ * (b_ - a_);

    always_ff @(posedge clk) begin
        q <= a_ + alpha_times_b_minus_a[WIDTH-1:0];
    end

endmodule