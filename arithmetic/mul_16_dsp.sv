module mul_16_dsp #(
    int INPUT_LATENCY  = 1,
    int OUTPUT_LATENCY = 1
)(
    input clk,

    input  logic signed [15:0] a,
    input  logic signed [15:0] b,

    output logic signed [31:0] q
);

    logic signed [15:0] a_reg [INPUT_LATENCY:0];
    logic signed [15:0] b_reg [INPUT_LATENCY:0];

    logic signed [31:0] q_reg [OUTPUT_LATENCY:0];

    assign a_reg[0] = a;
    assign b_reg[0] = b;

    assign q_reg[0] = a_reg[INPUT_LATENCY] * b_reg[INPUT_LATENCY];

    assign q = q_reg[OUTPUT_LATENCY];

    always @(posedge clk) begin
        for (int i = 1; i < INPUT_LATENCY + 1; i++) begin
            a_reg[i] <= a_reg[i - 1];
            b_reg[i] <= b_reg[i - 1];
        end

        for (int i = 1; i < OUTPUT_LATENCY + 1; i++) begin
            q_reg[i] <= q_reg[i - 1];
        end
    end

endmodule