module display_test(
    input         clk_p,
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

    wire clk;
    wire clk_nobuf;
    wire clk_wiz_out;
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

    clk_wiz_0 clk_wiz_0_i0(
        .clk_out1 (clk_wiz_out),
        .locked   (clk_wiz_locked),
        .clk_in1  (clk)
    );

    BUFGCE bufgce_i0 (
        .I  (clk_wiz_out),
        .CE (clk_wiz_locked),
        .O  (pixel_clk)
    );

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

    framebuffer_reader #(
        .WIDTH        (1920),
        .HEIGHT       (1080),
        .BURST_LENGTH (128),
        .BASE_ADDR    (0)
    ) fb_reader0 (
        .clk       (clk),
        .rst       (rst),

        .m_axi_ram (axi0.master),

        .pixel_clk (pixel_clk),
        .rgb       (rgb),
        .vsync     (vsync),
        .de        (de)
    );

    axi4_async_fifo #(
        .ADDR_WIDTH (32),
        .DATA_WIDTH (32),
        .ID_WIDTH   (1)
    ) axi4_async_fifo0 (
        .s_axi_clk (clk),
        .m_axi_clk (axi1_clk),

        .aresetn   (~(rst | axi1_rst)),

        .s_axi     (axi0.slave),
        .m_axi     (axi1.master)
    );

    mig_wrapper mig_wrapper0 (
        .sys_clk             (clk), // 200 MHz
        .sys_rst             (rst),

        .init_calib_complete (init_calib_complete),

        .s_axi_clk           (axi1_clk),
        .s_axi_rst           (axi1_rst),
        .s_axi               (axi1.slave),

        .* // ddr
    );

    xpm_cdc_single #(
        .DEST_SYNC_FF   (4),
        .INIT_SYNC_FF   (0),
        .SIM_ASSERT_CHK (0),
        .SRC_INPUT_REG  (0)
    ) init_calib_complete_sync (
       .dest_out (init_calib_complete_synced),
       .dest_clk (clk),
       .src_clk  (ax1_clk),
       .src_in   (init_calib_complete)
    );

    // vio_0 vio (
    //     .clk        (clk),
    //     .probe_in0  (adv7511_setup_error),
    //     .probe_in1  (adv7511_setup_done),
    //     .probe_in2  (init_calib_complete_synced),
    //     .probe_out0 (rst)
    // );

endmodule