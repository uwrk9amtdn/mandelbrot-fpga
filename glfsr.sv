module glfsr #(
    int               WIDTH = 3,
    logic [WIDTH-1:0] INIT = '1,
    logic [WIDTH-1:0] TAPS = 'b110
) (
    input              clk,
    input              rst,
    output [WIDTH-1:0] d
);

    logic [WIDTH-1:0] _d = INIT;
    assign d = _d;

    always_ff @(posedge clk) begin
        _d <= (_d >> 1) ^ (TAPS & {WIDTH{_d[0]}});
        if (rst) begin
            _d <= INIT;
        end
    end

endmodule