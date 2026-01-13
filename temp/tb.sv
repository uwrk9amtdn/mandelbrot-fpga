`timescale 1ns/1ns

module tb;

    reg clk = 1;

    wire [31:0] addr;
    reg  [23:0] rgb = 0;
    wire [7:0]  r;
    wire [7:0]  g;
    wire [7:0]  b;
    wire        hsync;
    wire        vsync;
    wire        de;

    display_driver #(
        .active_pixels_h (10),
        .front_porch_h   (10),
        .sync_width_h    (10),
        .back_porch_h    (10),
        .sync_polarity_h (1),

        .active_pixels_v (10),
        .front_porch_v   (10),
        .sync_width_v    (10),
        .back_porch_v    (10),
        .sync_polarity_v (1)
    ) dut (
        .clk   (clk),
        .addr  (addr),
        .rgb   (rgb),

        .r     (r),
        .g     (g),
        .b     (b),
        .hsync (hsync),
        .vsync (vsync),
        .de    (de)
    );

    initial begin
        $dumpfile("a.vcd");
        $dumpvars;
        fork
            forever #5 clk = ~clk;

            #5ms $finish;
        join
    end

endmodule