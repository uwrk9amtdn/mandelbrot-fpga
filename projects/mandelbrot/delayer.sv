module delayer #(
    DELAY      = 2,
    DATA_WIDTH = 32
)(
    input clk,
    input  [DATA_WIDTH-1:0] i,
    output [DATA_WIDTH-1:0] o
);

    logic [DATA_WIDTH-1:0] d [DELAY:0];
    assign d[0] = i;
    assign o = d[DELAY];

    always_ff @(posedge clk) begin
        for (int i = 1; i < DELAY; i++) begin
            d[i] <= d[i-1];
        end
    end

endmodule