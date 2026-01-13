module mul #(
    N = 4
)(
    input clk,
    input rst,

    input [N-1:0] in_a,
    input [N-1:0] in_b,
    input         in_valid,

    output logic           out_valid,
    output logic [2*N-1:0] out_q
);

    localparam int S = $clog2(N);

    logic [2*N-1:0] x [S:0][N-1:0];
    logic v [S:0];

    always @* begin
        for (int i = 0; i < N; i++) begin
            x[0][i] = in_b[i] ? (in_a << i) : 0;
        end

        v[0] = in_valid;

        out_valid = v[S];
        out_q = x[S][0];
    end

    genvar i, j;

    generate
        for (i = 0; i < S; i++) begin
            for (j = 0; j < (N >> (i + 1)); j++) begin
                always @(posedge clk) begin
                    x[i+1][j] <= x[i][2*j] + x[i][2*j+1];
                end
            end

            always @(posedge clk) begin
                v[i+1] <= v[i];
                if (rst) begin
                    v[i+1] <= 0;
                end
            end
        end
    endgenerate
endmodule