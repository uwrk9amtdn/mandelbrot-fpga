module sum(
    input             clk,
    input      [31:0] a,
    input      [31:0] b,
    output reg [32:0] q
);

    always @(posedge clk) begin
        q <= signed'(a) + signed'(b);
    end

endmodule