`timescale 1ns/1ps

module tb;
    logic       clk_p;
    logic       clk_n;

    wire        sda;
    wire        scl;

    logic       pixel_clk;
    logic [7:0] r;
    logic [7:0] g;
    logic [7:0] b;
    logic       hsync;
    logic       vsync;
    logic       de;

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

    pullup(sda);
    pullup(scl);

    top top (.*);

    for (genvar i = 0; i < 64 / 8; i++) begin: mem_gen
        ddr3_model ddr3_model(
            .rst_n   (ddr3_reset_n),
            .ck      (ddr3_ck_p),
            .ck_n    (ddr3_ck_n),
            .cke     (ddr3_cke),
            .cs_n    (ddr3_cs_n),
            .ras_n   (ddr3_ras_n),
            .cas_n   (ddr3_cas_n),
            .we_n    (ddr3_we_n),
            .dm_tdqs (ddr3_dm[i]),
            .ba      (ddr3_ba),
            .addr    (ddr3_addr),
            .dq      (ddr3_dq[i*8+:8]),
            .dqs     (ddr3_dqs_p[i]),
            .dqs_n   (ddr3_dqs_n[i]),
            .tdqs_n  (),
            .odt     (ddr3_odt)
        );
    end

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