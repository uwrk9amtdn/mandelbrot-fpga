// q = a + alpha * (b - a)

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

    logic signed [WIDTH+1:0]          b_minus_a;

    logic signed [WIDTH+1:-PRECISION] alpha_times_b_minus_a;

    logic signed [WIDTH+2:-PRECISION] q;

    assign a     = SIGNED ? {s_a[WIDTH-1], s_a} : {1'b0, s_a};
    assign b     = SIGNED ? {s_b[WIDTH-1], s_b} : {1'b0, s_b};
    assign alpha = {1'b0, s_alpha};

    assign m_q   = q[WIDTH-1:0];

    always_ff @(posedge clk) begin
        a_reg     [0] <= a;
        b_reg     [0] <= b;
        alpha_reg [0] <= alpha;
        for (int i = 0; i < 2; i++) begin
            a_reg     [i+1] <= a_reg     [i];
            b_reg     [i+1] <= b_reg     [i];
            alpha_reg [i+1] <= alpha_reg [i];
        end

        b_minus_a             <= b_reg[0] - a_reg[0];
        alpha_times_b_minus_a <= b_minus_a * alpha_reg[1];
        q                     <= signed'({a_reg[2], PRECISION'(0)}) + alpha_times_b_minus_a;
    end
endmodule

// // q = a + alpha * (b - a)

// (* use_dsp = "yes" *)
// module linear_interpolator #(
//     bit SIGNED    = 1, // is a, b and q signed
//     int WIDTH     = 4, // data width
//     int PRECISION = 4  // alpha fraction bits
// )(
//     input  logic                 clk,
//     input  logic                 rst,

//     input  logic                 s_valid,
//     input  logic [WIDTH-1:0]     s_a,
//     input  logic [WIDTH-1:0]     s_b,
//     input  logic [-1:-PRECISION] s_alpha,

//     output logic                 m_valid,
//     output logic [WIDTH-1:0]     m_q
// );

//     logic signed [WIDTH:0]      a, b, a_, b_;
//     logic signed [0:-PRECISION] alpha, alpha_;

//     assign a     = SIGNED ? {s_a[WIDTH-1], s_a} : {1'b0, s_a};
//     assign b     = SIGNED ? {s_b[WIDTH-1], s_b} : {1'b0, s_b};
//     assign alpha = {1'b0, s_alpha};

//     delayer #(WIDTH+1, 3) d1 (clk, 1'b0, a, a_);
//     delayer #(WIDTH+1, 3) d2 (clk, 1'b0, b, b_);
//     delayer #(WIDTH+1, 3) d3 (clk, 1'b0, alpha, alpha_);
//     delayer #(WIDTH+1, 4) d4 (clk, rst, s_valid, m_valid);

//     logic signed [WIDTH+2:-PRECISION] q;

//     assign q = signed'({a_, PRECISION'(0)}) + alpha_ * (b_ - a_);

//     always_ff @(posedge clk) begin
//         m_q <= q[WIDTH-1:0];
//     end
// endmodule