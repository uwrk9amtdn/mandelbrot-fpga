`timescale 1ns/1ps

module top;

    reg clk;
    reg rst;

    wire sda;
    wire scl;

    pullup(sda);
    pullup(scl);

    wire       pixel_clk;
    wire [7:0] r;
    wire [7:0] g;
    wire [7:0] b;
    wire       hsync;
    wire       vsync;
    wire       de;

    wire [63:0] ddr3_dq;
    wire [7:0]  ddr3_dqs_n;
    wire [7:0]  ddr3_dqs_p;
    wire [13:0] ddr3_addr;
    wire [2:0]  ddr3_ba;
    wire        ddr3_ras_n;
    wire        ddr3_cas_n;
    wire        ddr3_we_n;
    wire        ddr3_reset_n;
    wire [0:0]  ddr3_ck_p;
    wire [0:0]  ddr3_ck_n;
    wire [0:0]  ddr3_cke;
    wire [0:0]  ddr3_cs_n;
    wire [7:0]  ddr3_dm;
    wire [0:0]  ddr3_odt;

    display_test display_test0 (
        .clk_p        (clk),
        .clk_n        (~clk),

        .sda          (sda),
        .scl          (scl),

        .pixel_clk    (pixel_clk),
        .r            (r),
        .g            (g),
        .b            (b),
        .hsync        (hsync),
        .vsync        (vsync),
        .de           (de),

        .ddr3_dq      (ddr3_dq),
        .ddr3_dqs_n   (ddr3_dqs_n),
        .ddr3_dqs_p   (ddr3_dqs_p),
        .ddr3_addr    (ddr3_addr),
        .ddr3_ba      (ddr3_ba),
        .ddr3_ras_n   (ddr3_ras_n),
        .ddr3_cas_n   (ddr3_cas_n),
        .ddr3_we_n    (ddr3_we_n),
        .ddr3_reset_n (ddr3_reset_n),
        .ddr3_ck_p    (ddr3_ck_p),
        .ddr3_ck_n    (ddr3_ck_n),
        .ddr3_cke     (ddr3_cke),
        .ddr3_cs_n    (ddr3_cs_n),
        .ddr3_dm      (ddr3_dm),
        .ddr3_odt     (ddr3_odt)
    );

    ddr3_model ddr3_model0 (
        .dq      (ddr3_dq),
        .dqs_n   (ddr3_dqs_n),
        .dqs     (ddr3_dqs_p),
        .addr    (ddr3_addr),
        .ba      (ddr3_ba),
        .ras_n   (ddr3_ras_n),
        .cas_n   (ddr3_cas_n),
        .we_n    (ddr3_we_n),
        .rst_n   (ddr3_reset_n),
        .ck      (ddr3_ck_p),
        .ck_n    (ddr3_ck_n),
        .cke     (ddr3_cke),
        .cs_n    (ddr3_cs_n),
        .dm_tdqs (ddr3_dm),
        .tdqs_n  (),
        .odt     (ddr3_odt)
    );

    initial begin
        rst = 0;
        clk = 0;

        forever #2.5 clk <= ~clk;
    end

endmodule