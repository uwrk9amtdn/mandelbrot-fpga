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

    localparam int NCORES              = 16;
    localparam int FRAC_WIDTH          = 16;
    localparam int ARBITER_TREE_SANS   = 4;
    localparam int BURST_LENGTH        = 16;
    localparam int READER_BURST_LENGTH = 4;

    logic       clk;
    logic       ddr3_clk;
    logic       pixel_clk;

    logic       rst;

    logic       vio_rst;
    logic       adv7511_setup_error;
    logic       adv7511_setup_done;
    logic       ddr3_calib_complete;
    logic [3:0] cc_start_index;

    logic [15:0]          max_it;
    logic [2:-FRAC_WIDTH] center_x;
    logic [2:-FRAC_WIDTH] center_y;
    logic [2:-FRAC_WIDTH] xy_step;
    logic                 start;

    axi_intf #(
        .ID_WIDTH   (1),
        .ADDR_WIDTH (30),
        .DATA_WIDTH (16)
    ) ddr3_axi_16 ();

    generate : clk_gen
        logic clk_nobuf;

        IBUFDS ibufds (
            .I  (clk_p),
            .IB (clk_n),
            .O  (clk_nobuf)
        );

        BUFG bufg (
            .I (clk_nobuf),
            .O (clk)
        );

        clock_gen_7series_pll #(
            .N                 (1),
            .INPUT_FREQ        (200.0),
            .OUTPUT_FREQ       ({800.0}),
            .MAX_ERROR_PERCENT ({0.0})
        ) clk_gen0 (
            .clk_in  (clk),
            .clk_out ({ddr3_clk}),
            .reset   (0),
            .locked  ()
        );

        clock_gen_7series_pll #(
            .N                 (1),
            .INPUT_FREQ        (200.0),
            .OUTPUT_FREQ       ({148.5}),
            .MAX_ERROR_PERCENT ({0.015})
        ) clk_gen1 (
            .clk_in  (clk),
            .clk_out ({pixel_clk}),
            .reset   (0),
            .locked  ()
        );
    endgenerate

    generate : rst_gen
        logic rst_;
        assign rst = rst_ | vio_rst;
        logic [3:0] ctr;

        initial begin
            ctr  = 0;
            rst_ = 1;
        end

        always_ff @(posedge clk) begin
            if (ctr == 15) begin
                rst_ <= 0;
            end else begin
                ctr <= ctr + 1;
            end
        end
    endgenerate

    generate : i2c_gen
        logic sda_i;
        logic sda_o;
        logic scl_i;
        logic scl_o;

        xpm_cdc_single #(
            .DEST_SYNC_FF   (4),
            .INIT_SYNC_FF   (0),
            .SIM_ASSERT_CHK (0),
            .SRC_INPUT_REG  (0)
        ) sda_sync (
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
        ) scl_sync (
            .dest_out (scl_i),
            .dest_clk (clk),
            .src_clk  (),
            .src_in   (scl)
        );

        assign sda = sda_o == 0 ? 0 : 1'bz;
        assign scl = scl_o == 0 ? 0 : 1'bz;

        pullup(sda);
        pullup(scl);

        ac701_adv7511_setup #(
            .CLK_FREQ (200.0e6),
            .SCL_FREQ (100.0e3)
        ) adv7511_setup (
            .clk   (clk),
            .rst   (rst),

            .error (adv7511_setup_error),
            .done  (adv7511_setup_done),

            .sda_i (sda_i),
            .sda_o (sda_o),

            .scl_i (scl_i),
            .scl_o (scl_o)
        );
    endgenerate

    generate : ddr3_gen
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

        axi_intf #(
            .ID_WIDTH   (1),
            .ADDR_WIDTH (30),
            .DATA_WIDTH (512)
        ) ddr3_axi ();

        uberddr3_wrapper_axi #(
            CLK_PERIOD_PS      (5000),
            DDR3_CLK_PERIOD_PS (1250)
        ) uberddr3 (
            .clk            (clk),
            .rst            (rst),

            .ddr3_clk       (ddr3_clk),
            .ref_clk        (clk), // 200 MHz

            .calib_complete (ddr3_calib_complete),

            .s_axi          (ddr3_axi),

            .ddr3           (ddr3)
        );

        axi_wc #(
            .CONVERT_BURST        (1),
            .CONVERT_NARROW_BURST (0)
        ) (
            .clk (clk),
            .rst (rst),
            .s   (ddr3_axi_16),
            .m   (ddr3_axi)
        );
    endgenerate

    generate : display_gen
        axis_intf #(16) fifo_s ();
        axis_intf #(16) fifo_m ();

        axis_afifo #(
            .SYNC_STAGES (2),
            .DEPTH       (64)
        )(
            .s_clk (clk),
            .s_rst (rst),
            .m_clk (pixel_clk),
            .m_rst (0),

            .s (fifo_s),
            .m (fifo_m)
        );

        logic mr_s_valid;

        memory_reader #(
            .START_ADDR   (0),
            .AXI_ID       (0),
            .COUNT        (1920*1080),
            .BURST_LENGTH (READER_BURST_LENGTH)
        ) mr (
            .clk     (clk),
            .rst     (rst),

            .s_ready (),
            .s_valid (mr_s_valid),

            .m_axi   (ddr3_axi_16),
            .m_axis  (fifo_s)
        );

        logic vsync_synced;
        logic vsync_synced_d1;

        xpm_cdc_single #(
            .DEST_SYNC_FF   (4),
            .INIT_SYNC_FF   (0),
            .SIM_ASSERT_CHK (0),
            .SRC_INPUT_REG  (0)
        ) vsync_sync (
            .dest_out (vsync_synced),
            .dest_clk (clk),
            .src_clk  (pixel_clk),
            .src_in   (vsync)
        );

        always_ff @(posedge clk) begin
            vsync_synced_d1 <= vsync_synced;
            mr_s_valid      <= ~vsync_synced_d1 & vsync_synced;
            if (rst) begin
                mr_s_valid      <= 0;
                vsync_synced_d1 <= 0;
            end
        end

        axis_intf #(24) cc_rgb ();

        assign cc_rgb.ready = de;

        color_converter cc(
            .clk         (pixel_clk),
            .rst         ('0),

            .start_index (cc_start_index),

            .s_axis_it   (fifo_m),

            .m_axis_rgb  (cc_rgb)
        );

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
        ) display_driver (
            .clk   (pixel_clk),
            .addr  (),
            .x     (),
            .y     (),
            .rgb   (cc_rgb.data),

            .r     (r),
            .g     (g),
            .b     (b),
            .hsync (hsync),
            .vsync (vsync),
            .de    (de)
        );
    endgenerate

    generate : wrapper_gen
        logic start_d1;
        logic wrapper_s_valid;

        wrapper #(
            .X_RES             (1920),
            .Y_RES             (1080),
            .FRAC_WIDTH        (FRAC_WIDTH),
            .NCORES            (NCORES),
            .ARBITER_TREE_SANS (ARBITER_TREE_SANS),
            .BURST_LENGTH      (BURST_LENGTH),
            .FB_START_ADDR     (0),
            .AXI_ID            (0)
        ) wrapper (
            .clk          (clk),
            .rst          (rst),

            .s_ready      (),
            .s_valid      (wrapper_s_valid),
            .s_max_it     (max_it),
            .s_center_x   (center_x),
            .s_center_y   (center_y),
            .s_xy_step    (xy_step),

            .m_axi_mem    (ddr3_axi_16)
        );


        always_ff @(posedge clk) begin
            start_d1        <= start;
            wrapper_s_valid <= ~start_d1 & start;
            if (rst) begin
                start_d1         <= 0;
                wrapper_s_valid  <= 0;
            end
        end

    endgenerate

    vio_0 vio (
        .clk        (clk),

        .probe_in0  (adv7511_setup_error),
        .probe_in1  (adv7511_setup_done),
        .probe_in2  (ddr3_calib_complete),

        .probe_out0 (vio_rst),
        .probe_out1 (cc_start_index),
        .probe_out2 (max_it),
        .probe_out3 (center_x),
        .probe_out4 (center_y),
        .probe_out5 (xy_step),
        .probe_out6 (start)
    );

endmodule
