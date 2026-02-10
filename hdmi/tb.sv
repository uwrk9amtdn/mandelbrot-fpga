`timescale 1ns/1ns

module tb;

    wire sda;
    wire scl;

    reg clk;
    reg rst;

    wire sda_i;
    wire sda_o;
    wire scl_i;
    wire scl_o;

    wire error;
    wire done;

    assign sda = sda_o == 0 ? 0 : 1'bz;
    assign scl = scl_o == 0 ? 0 : 1'bz;

    assign sda_i = sda;
    assign scl_i = scl;

    pullup(sda);
    pullup(scl);

    ac701_adv7511_setup #(
        .CLK_FREQ (200.0e6),
        .SCL_FREQ (100.0e3)
    ) ac701_adv7511_setup_i0 (
        .clk   (clk),
        .rst   (rst),

        .error (error),
        .done  (done),

        .sda_i (sda_i),
        .sda_o (sda_o),

        .scl_i (scl_i),
        .scl_o (scl_o)
    );

    wire [31:0] addr;
    wire [31:0] x;
    wire [31:0] y;
    wire [23:0] rgb;

    wire [7:0] r,g,b;
    wire hsync, vsync, de;

    display_driver #(
        .active_pixels_h (1920),
        .front_porch_h   (88),
        .sync_width_h    (44),
        .back_porch_h    (148),
        .sync_polarity_h (1),

        .active_pixels_v (1080),
        .front_porch_v   (4),
        .sync_width_v    (5),
        .back_porch_v    (36),
        .sync_polarity_v (1)
    ) display_driver_i0 (
        .clk   (clk),
        .addr  (addr),
        .x     (x),
        .y     (y),
        .rgb   (rgb),

        .r     (r),
        .g     (g),
        .b     (b),
        .hsync (hsync),
        .vsync (vsync),
        .de    (de)
    );

    assign rgb = x[6:0] > 2**6 - 1 ? 24'hff0000 : 24'h00ff00;

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars;

        clk = 0;
        rst = 1;
        fork
            forever #5 clk = ~clk;
            #20 rst = 0;
            #20ms $finish;
            begin

            end
        join
    end

endmodule