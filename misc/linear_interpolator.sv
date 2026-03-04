// q = a + alpha * (b - a)

(* use_dsp = "yes" *)
module linear_interpolator #(
    int INPUT_LATENCY  = 1,
    int OUTPUT_LATENCY = 1,
    bit SIGNED         = 1, // is a and b signed
    int WIDTH          = 8, // data width
    int PRECISION      = 4  // alpha fraction bits
)(
    input                clk,

    input [WIDTH-1:0]    a,
    input [WIDTH-1:0]    b,
    input [-1:-PRECISION] alpha,

    output [WIDTH-1:0] q,
);

    logic [WIDTH-1:0]    a_reg;
    logic [WIDTH-1:0]    b_reg;
    logic [0:-PRECISION] alpha_reg;
    logic [WIDTH-1:0]    q_reg;

    if (SIGNED) begin

    end

    if (!SIGNED) begin
        always_comb begin
            q_ = a_ + alpha_ * (b_ - a_);
        end
    end

    generate
        logic

        assign a_       = a_reg[INPUT_LATENCY];
        assign b_       = b_reg[INPUT_LATENCY];
        assign alpha_   = alpha_reg[INPUT_LATENCY];
        assign q_reg[0] = q_;

        if (SIGNED) begin
            q_ = a_ + alpha_ + (b_ - a_);
        end
        else begin

        end
    endgenerate

    always @(posedge clk) begin
        for (int i = 0; i < INPUT_LATENCY + 1; i++) begin
            a_reg     [i] <= a_reg     [i - 1];
            b_reg     [i] <= b_reg     [i - 1];
            alpha_reg [i] <= alpha_reg [i - 1];
        end

        for (int i = 1; i < OUTPUT_LATENCY + 1; i++) begin
            q_reg[i] <= q_reg[i - 1];
        end
    end




    always_comb begin
        if (SIGNED) begin
            q_reg = signed'(s_a) + signed'({1'b0, s_alpha}) * (signed'(s_b) - signed'(s_a));
        end else begin
            q_reg = s_a + s_alpha * (s_b - s_a);
        end
    end

    always_ff @(posedge clk) begin

    end

endmodule

module linear_interpolation(
	input clk,
	input [3:0] a, b,
	input [-1:-4] alpha,
	output reg [3:0] q
);
	wire [7:0] q_;

	assign q_ = (a << 4) + (b - a) * alpha;

	always @(posedge clk) begin
		q <= q_[7:3];
	end
endmodule