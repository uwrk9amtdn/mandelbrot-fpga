module mul_dsp #(
    INT_BITS  = 2,
    FRAC_BITS = 4,
    LATENCY   = 1
)(
    input                                         clk,
    input        signed [INT_BITS:-FRAC_BITS]     a,
    input        signed [INT_BITS:-FRAC_BITS]     b,
    output logic signed [2*INT_BITS+1:-FRAC_BITS] q
);

    logic signed [2*INT_BITS+1:-FRAC_BITS] q_ [LATENCY:0];

    logic signed [2*INT_BITS+1:-2*FRAC_BITS] a_mul_b;

    always @* begin
        (* USE_DSP = "TRUE" *) a_mul_b = a * b;
        q_[0] = a_mul_b[2*INT_BITS+1:-FRAC_BITS];
        q = q_[LATENCY];
    end

    genvar i;

    generate
        for (i = 0; i < LATENCY; i++) begin
            always @(posedge clk) q_[i+1] <= q_[i];
        end
    endgenerate

endmodule