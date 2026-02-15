`timescale 1ns/1ps

module tb;
    logic clk_p;
    logic clk_n;

    wire sda;
    wire scl;

    logic       pixel_clk;

    logic [7:0] r;
    logic [7:0] g;
    logic [7:0] b;
    logic       hsync;
    logic       vsync;
    logic       de;

    pullup(sda);
    pullup(scl);

    top top (
        .clk_p         (clk_p), // 200 MHz
        .clk_n         (clk_n),

        .sda           (sda),
        .scl           (scl),

        .pixel_clk     (pixel_clk),
        .r             (r),
        .g             (g),
        .b             (b),
        .hsync         (hsync),
        .vsync         (vsync),
        .de            (de),

        .ddr3_dq       (),
        .ddr3_dqs_n    (),
        .ddr3_dqs_p    (),
        .ddr3_addr     (),
        .ddr3_ba       (),
        .ddr3_ras_n    (),
        .ddr3_cas_n    (),
        .ddr3_we_n     (),
        .ddr3_reset_n  (),
        .ddr3_ck_p     (),
        .ddr3_ck_n     (),
        .ddr3_cke      (),
        .ddr3_cs_n     (),
        .ddr3_dm       (),
        .ddr3_odt      ()
    );


    initial begin
        clk_p = 1;
        clk_n = 0;

        top.max_it   = 100;
        top.center_x = 0;
        top.center_y = 0;
        top.xy_step  = 0;
        top.start    = 0;

        fork
            forever begin
                #2.5;
                clk_p <= ~clk_p;
                clk_n <= ~clk_n;
            end
            begin
                #100us;
                top.start <= 1;
                #100;
                top.start <= 0;
            end
        join_any
    end

endmodule