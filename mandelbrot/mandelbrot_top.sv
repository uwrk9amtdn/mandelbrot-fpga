module mandelbrot_top();


    localparam int N = 64;

    generate
        for (genvar i = 0; i < N; i++) begin
            axis_rr_arbiter #(4) (clk, rst, );
        end
    endgenerate


endmodule