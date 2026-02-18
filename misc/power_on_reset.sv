module power_on_reset #(
    int CLOCK_CYCLE = 16
)(
    input  logic clk,
    output logic rst
);
    logic [$clog2(CLOCK_CYCLE)-1:0] c = 0;

    logic rst_reg = 1;
    assign rst = rst_reg;

    always_ff @(posedge clk) begin
        if (c == CLOCK_CYCLE-1) begin
            rst_reg <= 0;
        end else begin
            c <= c + 1;
        end
    end

endmodule