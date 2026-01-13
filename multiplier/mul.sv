module mul #(
    N = 256
)(
    input clk,
    input rst,

    input [N-1:0] in_a,
    input [N-1:0] in_b,
    input         in_valid,

    output logic           out_valid,
    output logic [2*N-1:0] out_q
);

    logic [N-1:0]   a_reg [N:0];
    logic [N-1:0]   b_reg [N:0];
    logic [2*N-1:0] t_reg [N:0];
    logic           v_reg [N:0];

    always @* begin
        t_reg[0] = 0;
        a_reg[0] = in_a;
        b_reg[0] = in_b;
        v_reg[0] = in_valid;

        out_valid = v_reg[N];
        out_q     = t_reg[N];
    end

    always @(posedge clk) begin

        for (int i = 0; i < N; i++) begin
            t_reg[i+1] <= t_reg[i] + (b_reg[i][i] ? a_reg[i] << i : 0);
            a_reg[i+1] <= a_reg[i];
            b_reg[i+1] <= b_reg[i];
            v_reg[i+1] <= v_reg[i];

            if (rst) begin
                v_reg[i+1] <= 0;
            end
        end
    end

endmodule