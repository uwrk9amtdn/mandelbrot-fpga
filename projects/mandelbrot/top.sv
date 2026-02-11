module top (
    input         clk_p, // 200 MHz
    input         clk_n,

    inout         sda,
    inout         scl,

    output        pixel_clk,
    output [7:0]  r,
    output [7:0]  g,
    output [7:0]  b,
    output        hsync,
    output        vsync,
    output        de,

    inout  [63:0] ddr3_dq,
    inout  [7:0]  ddr3_dqs_n,
    inout  [7:0]  ddr3_dqs_p,
    output [13:0] ddr3_addr,
    output [2:0]  ddr3_ba,
    output        ddr3_ras_n,
    output        ddr3_cas_n,
    output        ddr3_we_n,
    output        ddr3_reset_n,
    output [0:0]  ddr3_ck_p,
    output [0:0]  ddr3_ck_n,
    output [0:0]  ddr3_cke,
    output [0:0]  ddr3_cs_n,
    output [7:0]  ddr3_dm,
    output [0:0]  ddr3_odt
);

    /////////

    wire clk;
    wire clk_nobuf;
    wire clk_wiz_out [2];
    wire clk_wiz_locked;

    IBUFDS ibufds_i0 (
        .I  (clk_p),
        .IB (clk_n),
        .O  (clk_nobuf)
    );

    BUFG bufg_i0 (
        .I (clk_nobuf),
        .O (clk)
    );

    clock_gen_7series_pll #(
        .N                 (2),
        .INPUT_FREQ        (200.0),
        .OUTPUT_FREQ       ({800.0, 148.5}),
        .MAX_ERROR_PERCENT ({0.0, 0.0})
    ) clk_gen_i0 (
        .clk_in  (clk),
        .clk_out ({ddr3_clk, pixel_clk}),
        .reset   (0),
        .locked  ()
    );

    clk_wiz_0 clk_wiz_0_i0(
        .clk_out1 (clk_wiz_out[0]),
        .clk_out2 (clk_wiz_out[1]),
        .locked   (clk_wiz_locked),
        .clk_in1  (clk)
    );

    BUFGCE bufgce_i0 (
        .I  (clk_wiz_out [0]),
        .CE (clk_wiz_locked),
        .O  (pixel_clk)
    );

    BUFGCE bufgce_i1 (
        .I  (clk_wiz_out [1]),
        .CE (clk_wiz_locked),
        .O  (ddr3_clk)
    );

    //////////

    wire sda_i;
    wire sda_o;
    wire scl_i;
    wire scl_o;

    xpm_cdc_single #(
        .DEST_SYNC_FF   (4),
        .INIT_SYNC_FF   (0),
        .SIM_ASSERT_CHK (0),
        .SRC_INPUT_REG  (0)
    ) sda_sync_i0 (
       .dest_out (sda_i),
       .dest_clk (clk),
       .src_clk  (),
       .src_in   (sda)
    );

    xpm_cdc_single #(
        .DEST_SYNC_FF   (4),
        .INIT_SYNC_FF   (0),
        .SIM_ASSERT_CHK (0),
        .SRC_INPUT_REG  (0)
    ) scl_sync_i0 (
       .dest_out (scl_i),
       .dest_clk (clk),
       .src_clk  (),
       .src_in   (scl)
    );

    assign sda = sda_o == 0 ? 0 : 1'bz;
    assign scl = scl_o == 0 ? 0 : 1'bz;

    pullup(sda);
    pullup(scl);

    wire rst;
    wire adv7511_setup_error;
    wire adv7511_setup_done;

    ac701_adv7511_setup #(
        .CLK_FREQ (200.0e6),
        .SCL_FREQ (100.0e3)
    ) ac701_adv7511_setup_i0 (
        .clk   (clk),
        .rst   (rst),

        .error (adv7511_setup_error),
        .done  (adv7511_setup_done),

        .sda_i (sda_i),
        .sda_o (sda_o),

        .scl_i (scl_i),
        .scl_o (scl_o)
    );

    //////////

    wire [23:0] rgb;

    axi #(
        .ID_WIDTH   (1),
        .ADDR_WIDTH (30),
        .DATA_WIDTH (32)
    ) axi0();

    axi #(
        .ID_WIDTH   (1),
        .ADDR_WIDTH (30),
        .DATA_WIDTH (32)
    ) axi1();

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
        .clk   (pixel_clk),
        .addr  (),
        .x     (),
        .y     (),
        .rgb   (rgb),

        .r     (r),
        .g     (g),
        .b     (b),
        .hsync (hsync),
        .vsync (vsync),
        .de    (de)
    );

    wrapper #(
        .X_RES         (1920),
        .Y_RES         (1080),
        .FRAC_WIDTH    (16),
        .NCORES        (8),
        .ARBITER_SIZE  (4),
        .BURST_SIZE    (16),
        .FB_START_ADDR (0),
        .AXI_ID        (1)
    )(
        .clk          (clk),
        .rst          (),

        .s_ready      (),
        .s_valid      (),
        .s_max_it     (),
        .s_center_x   (),
        .s_center_y   (),
        .s_xy_step    (),

        axi_intf m_axi_mem
    );

    axi_intf #(

    ) ddr3_axi ();

    ddr3_intf #(
        .DM_BITS  (8),
        .BA_BITS  (3),
        .ROW_BITS (14),
        .COL_BITS (10),
        .DQ_BITS  (64),
        .DQS_BITS (8)
    ) ddr3 ();

    assign ddr3_reset_n = ddr3.rst_n;
    assign ddr3_ck_p    = ddr3.ck;
    assign ddr3_ck_n    = ddr3.ck_n;
    assign ddr3_cke     = ddr3.cke;
    assign ddr3_cs_n    = ddr3.cs_n;
    assign ddr3_ras_n   = ddr3.ras_n;
    assign ddr3_cas_n   = ddr3.cas_n;
    assign ddr3_we_n    = ddr3.we_n;
    assign ddr3_dm      = ddr3.dm;
    assign ddr3_ba      = ddr3.ba;
    assign ddr3_addr    = ddr3.addr;
    alias  ddr3_dq      = ddr3.dq;
    alias  ddr3_dqs_p   = ddr3.dqs;
    alias  ddr3_dqs_n   = ddr3.dqs_n;
    assign ddr3_odt     = ddr3.odt;

    uberddr3_wrapper_axi #(
        CLK_PERIOD_PS      (5000),
        DDR3_CLK_PERIOD_PS (1250)
    ) uberddr3 (
        .clk                (clk),
        .rst                (rst),

        .ddr3_clk           (ddr3_clk),
        .ref_clk            (clk), // 200 MHz

        .calib_complete     (ddr3_calib_complete),

        .s_axi              (),

        .ddr3               (ddr3)
    );

    axi_intf #()

    axi_wc #(
        .CONVERT_BURST        (1),
        .CONVERT_NARROW_BURST (0)
    ) wc (
        .clk (),
        .rst (),

        .s (),
        .m ()
    );

endmodule