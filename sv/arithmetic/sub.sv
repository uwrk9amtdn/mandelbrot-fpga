module sub #(
    INT_BITS  = 2,
    FRAC_BITS = 4,
    LATENCY   = 1
)(
    input                                       clk,
    input        signed [INT_BITS:-FRAC_BITS]   a,
    input        signed [INT_BITS:-FRAC_BITS]   b,
    output logic signed [INT_BITS+1:-FRAC_BITS] q
);

    logic signed [INT_BITS+1:-FRAC_BITS] q_ [LATENCY:0];

    logic signed [INT_BITS+1:-FRAC_BITS] a_sub_b;

    always @* begin
        a_sub_b = a - b;
        q_[0] = a_sub_b;
        q = q_[LATENCY];
    end

    genvar i;

    generate
        for (i = 0; i < LATENCY; i++) begin
            always @(posedge clk) q_[i+1] <= q_[i];
        end
    endgenerate


endmodule