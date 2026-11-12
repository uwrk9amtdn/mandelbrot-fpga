(* use_dsp = "true" *)
module mul_dsp #(
    int WIDTH   = 8,
    int LATENCY = 1,
    bit SIGNED  = 0
)(
    input  logic               clk,
    input  logic [WIDTH-1:0]   a,
    input  logic [WIDTH-1:0]   b,
    output logic [2*WIDTH-1:0] q
);

    if (LATENCY < 2) begin
        $error();
    end

    logic [2*WIDTH-1:0] q_reg [LATENCY-1:0];

    logic [WIDTH-1:0] a_reg;
    logic [WIDTH-1:0] b_reg;

    if (SIGNED) begin
        assign q_reg[0] = signed'(a_reg) * signed'(b_reg);
    end else begin
        assign q_reg[0] = a_reg * b_reg;;
    end

    assign q = q_reg[LATENCY-1];

    always_ff @(posedge clk) begin
        a_reg <= a;
        b_reg <= b;
        for (int i = 0; i < LATENCY-1; i++) begin
            q_reg[i+1] <= q_reg[i];
        end
    end

endmodule