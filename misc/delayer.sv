module delayer #(
    WIDTH = 32,
    DELAY = 2
)(
    input clk,
    input  [WIDTH-1:0] i,
    output [WIDTH-1:0] o
);

    logic [WIDTH-1:0] d [DELAY:0];
    assign d[0] = i;
    assign o = d[DELAY];

    always_ff @(posedge clk) begin
        for (int j = 0; j < DELAY; j++) begin
            d[j+1] <= d[j];
        end
    end

endmodule