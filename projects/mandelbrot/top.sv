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

    `ifndef SYNTHESIS
        `define MICRON_SIM 1
    `else
        `define MICRON_SIM 0
    `endif

    localparam int NCORES              = 128;
    localparam int FRAC_WIDTH          = 16;
    localparam int ARBITER_TREE_SANS   = 6;
    localparam int BURST_LENGTH        = 32;
    localparam int READER_BURST_LENGTH = 64;

    localparam real CLOCK_FREQ = 100.0;

    logic       sysclk;

    logic       ddr3_clk;
    logic       ddr3_clk_90;
    logic       ddr3_ctrl_clk;
    logic       ddr3_ctrl_rst;
    logic       ddr3_ref_clk;

    logic       clk;
    logic       rst;

    // ddr3_ctrl_clk

    axi_intf #(
        .ID_WIDTH   (4),
        .ADDR_WIDTH (30),
        .DATA_WIDTH (64)
    ) ddr3_axi_64 ();

    // clk
    logic [15:0]                 max_it;
    logic signed [2:-FRAC_WIDTH] center_x;
    logic signed [2:-FRAC_WIDTH] center_y;
    logic signed [2:-FRAC_WIDTH] xy_step;
    logic                        start;

    logic                        ddr3_calib_complete;
    logic                        adv7511_setup_error;
    logic                        adv7511_setup_done;
    logic [3:0]                  cc_start_index;

    begin : clk_block
        logic sysclk_nobuf;

        IBUFDS ibufds (
            .I  (clk_p),
            .IB (clk_n),
            .O  (sysclk_nobuf)
        );

        BUFG bufg (
            .I (sysclk_nobuf),
            .O (sysclk)
        );

        clock_gen_7series_pll #(
            .N               (4),
            .INPUT_FREQ      (200.0),
            .OUTPUT_FREQ     ('{100.0, 400.0, 400.0, 200.0}),
            .OUTPUT_PHASE    ('{0.0, 0.0, 90.0, 0.0}),
            .MAX_FREQ_ERROR  ('{default:0.0}),
            .MAX_PHASE_ERROR ('{default:0.0}),
            .VCO_MIN         (800.0),
            .VCO_MAX         (1866.0),
            .PFD_MIN         (19.0),
            .PFD_MAX         (500.0)  // speed grade -2
        ) clk_gen0 (
            .clk_in    (sysclk),
            .clk_out   ({ddr3_ctrl_clk, ddr3_clk, ddr3_clk_90, ddr3_ref_clk}),
            .reset     ('0),
            .locked    ()
        );

        clock_gen_7series_pll #(
            .N               (1),
            .INPUT_FREQ      (200.0),
            .OUTPUT_FREQ     ('{148.5}),
            .OUTPUT_PHASE    ('{0.0}),
            .MAX_FREQ_ERROR  ('{0.015}),
            .MAX_PHASE_ERROR ('{default:0.0}),
            .VCO_MIN         (800.0),
            .VCO_MAX         (1866.0),
            .PFD_MIN         (19.0),
            .PFD_MAX         (500.0)  // speed grade -2
        ) clk_gen1 (
            .clk_in    (sysclk),
            .clk_out   (pixel_clk),
            .reset     ('0),
            .locked    ()
        );

        clock_gen_7series_pll #(
            .N               (1),
            .INPUT_FREQ      (200.0),
            .OUTPUT_FREQ     ('{CLOCK_FREQ}),
            .OUTPUT_PHASE    ('{0.0}),
            .MAX_FREQ_ERROR  ('{default:0.0}),
            .MAX_PHASE_ERROR ('{default:0.0}),
            .VCO_MIN         (800.0),
            .VCO_MAX         (1866.0),
            .PFD_MIN         (19.0),
            .PFD_MAX         (500.0)  // speed grade -2
        ) clk_gen2 (
            .clk_in    (sysclk),
            .clk_out   (clk),
            .reset     ('0),
            .locked    ()
        );
        power_on_reset #(16) por_clk (clk, rst);
        power_on_reset #(16) por_ddr3_ctrl_clk (ddr3_ctrl_clk, ddr3_ctrl_rst);
    end

    begin : i2c_block
        logic sda_i;
        logic sda_o;
        logic scl_i;
        logic scl_o;

        cdc_single #(
            .SYNC_STAGES   (4),
            .INITIAL_VALUE (1'b1)
        ) sda_cdc (
            .clk (clk),
            .i   (sda),
            .o   (sda_i)
        );

        cdc_single #(
            .SYNC_STAGES   (4),
            .INITIAL_VALUE (1'b1)
        ) scl_cdc (
            .clk (clk),
            .i   (scl),
            .o   (scl_i)
        );

        assign sda = sda_o == 0 ? 0 : 1'bz;
        assign scl = scl_o == 0 ? 0 : 1'bz;

        pullup(sda);
        pullup(scl);

        ac701_adv7511_setup #(
            .CLK_FREQ (CLOCK_FREQ*1.0e6),
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
    end

    begin : ddr3_block
        logic calib_complete;

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
            .ID_WIDTH   (4),
            .ADDR_WIDTH (30),
            .DATA_WIDTH (512)
        ) ddr3_axi ();

        uberddr3_wrapper_axi #(
            .CLK_PERIOD_PS      (10000),
            .DDR3_CLK_PERIOD_PS (2500),
            .MICRON_SIM         (`MICRON_SIM)
        ) uberddr3 (
            .clk            (ddr3_ctrl_clk),
            .rst            (ddr3_ctrl_rst),

            .ddr3_clk       (ddr3_clk),
            .ddr3_clk_90    (ddr3_clk_90),
            .ref_clk        (ddr3_ref_clk), // 200 MHz

            .calib_complete (calib_complete),

            .s_axi          (ddr3_axi),

            .ddr3           (ddr3)
        );

        axi_wc #(
            .CONVERT_BURST        (1),
            .CONVERT_NARROW_BURST (0)
        ) wc (
            .clk (ddr3_ctrl_clk),
            .rst (ddr3_ctrl_rst),
            .s   (ddr3_axi_64),
            .m   (ddr3_axi)
        );

        cdc_single #(
            .SYNC_STAGES   (4),
            .INITIAL_VALUE (1'b0)
        ) calib_complete_cdc (
            .clk (clk),
            .i   (calib_complete),
            .o   (ddr3_calib_complete)
        );
    end

    begin : display_block
        axis_intf #(16, 0) fifo_s ();
        axis_intf #(16, 0) fifo_m ();

        logic mr_s_valid;

        logic vsync_synced;
        logic vsync_synced_d1;

        axis_intf #(24, 0) cc_rgb ();

        assign cc_rgb.ready = de;

        cdc_single #(
            .SYNC_STAGES   (4),
            .INITIAL_VALUE (1'b0)
        ) vsync_cdc (
            .clk (ddr3_ctrl_clk),
            .i   (vsync),
            .o   (vsync_synced)
        );

        always_ff @(posedge ddr3_ctrl_clk) begin
            vsync_synced_d1 <= vsync_synced;
            mr_s_valid      <= ~vsync_synced_d1 & vsync_synced;
            if (ddr3_ctrl_rst) begin
                mr_s_valid      <= 0;
                vsync_synced_d1 <= 0;
            end
        end

        memory_reader #(
            .START_ADDR   (0),
            .AXI_ID       (0),
            .COUNT        (1920*1080),
            .BURST_LENGTH (READER_BURST_LENGTH)
        ) mr (
            .clk     (ddr3_ctrl_clk),
            .rst     (ddr3_ctrl_rst),

            .s_ready (),
            .s_valid (mr_s_valid),

            .m_axi   (ddr3_axi_64),
            .m_axis  (fifo_s)
        );

        axis_afifo #(
            .SYNC_STAGES (2),
            .DEPTH       (64)
        ) afifo (
            .s_clk (ddr3_ctrl_clk),
            .s_rst (ddr3_ctrl_rst),
            .m_clk (pixel_clk),
            .m_rst ('0),

            .s (fifo_s),
            .m (fifo_m)
        );

        logic [3:0] cc_start_index_;
        cdc_multi #(4, 4) cdc0 (clk, pixel_clk, cc_start_index, cc_start_index_);

        color_converter cc(
            .clk         (pixel_clk),
            .rst         ('0),

            .start_index (cc_start_index_),

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
    end

    begin : wrapper_block
        logic start_d1;
        logic wrapper_s_valid;

        axis_intf #(32, 0) addr_fifo_s ();
        axis_intf #(32, 0) addr_fifo_m ();

        axis_intf #(64, 1) data_fifo_s ();
        axis_intf #(64, 1) data_fifo_m ();

        axis_afifo #(
            .SYNC_STAGES (2),
            .DEPTH       (4)
        ) addr_fifo (
            .s_clk (clk),
            .s_rst (rst),
            .m_clk (ddr3_ctrl_clk),
            .m_rst (ddr3_ctrl_rst),

            .s (addr_fifo_s),
            .m (addr_fifo_m)
        );

        axis_afifo #(
            .SYNC_STAGES (2),
            .DEPTH       (64)
        ) data_fifo (
            .s_clk (clk),
            .s_rst (rst),
            .m_clk (ddr3_ctrl_clk),
            .m_rst (ddr3_ctrl_rst),

            .s (data_fifo_s),
            .m (data_fifo_m)
        );

        wrapper #(
            .X_RES             (1920),
            .Y_RES             (1080),
            .FRAC_WIDTH        (FRAC_WIDTH),
            .NCORES            (NCORES),
            .ARBITER_TREE_SANS (ARBITER_TREE_SANS),
            .BURST_LENGTH      (BURST_LENGTH),
            .FB_START_ADDR     (0)
        ) wrapper (
            .clk          (clk),
            .rst          (rst),

            .s_ready      (),
            .s_valid      (wrapper_s_valid),
            .s_max_it     (max_it),
            .s_center_x   (center_x),
            .s_center_y   (center_y),
            .s_xy_step    (xy_step),

            .m_addr       (addr_fifo_s),
            .m_data       (data_fifo_s)
        );

        memory_writer #(
            .BURST_LENGTH (BURST_LENGTH),
            .AXI_ID       (0)
        ) memw (
            .clk    (ddr3_ctrl_clk),
            .rst    (ddr3_ctrl_rst),
            .s_addr (addr_fifo_m),
            .s_data (data_fifo_m),
            .m      (ddr3_axi_64)
        );

        rise_detector start_rd (clk, rst, start, wrapper_s_valid);
    end

    begin : vio_block
        logic [2:-FRAC_WIDTH] vio_xy_step;
        logic [2:-FRAC_WIDTH] vio_xy_step_set;
        logic                 vio_xy_step_shift_right;
        logic                 vio_xy_step_shift_left;

        logic [2:-FRAC_WIDTH] vio_center_x;
        logic                 vio_center_x_set;
        logic                 vio_center_x_move_right;
        logic                 vio_center_x_move_left;

        logic [2:-FRAC_WIDTH] vio_center_y;
        logic                 vio_center_y_set;
        logic                 vio_center_y_move_up;
        logic                 vio_center_y_move_down;

        logic                 vio_max_it;
        logic                 vio_start;

        logic [3:0]           vio_cc_start_index;

        logic                 vio_xy_step_set_rise;
        logic                 vio_xy_step_shift_right_rise;
        logic                 vio_xy_step_shift_left_rise;
        logic                 vio_center_x_set_rise;
        logic                 vio_center_x_move_right_rise;
        logic                 vio_center_x_move_left_rise;
        logic                 vio_center_y_set_rise;
        logic                 vio_center_y_move_up_rise;
        logic                 vio_center_y_move_down_rise;

        rise_detector r0(clk, rst, vio_xy_step_set,         vio_xy_step_set_rise);
        rise_detector r1(clk, rst, vio_xy_step_shift_right, vio_xy_step_shift_right_rise);
        rise_detector r2(clk, rst, vio_xy_step_shift_left,  vio_xy_step_shift_left_rise);

        rise_detector r3(clk, rst, vio_center_x_set,        vio_center_x_set_rise);
        rise_detector r4(clk, rst, vio_center_x_move_right, vio_center_x_move_right_rise);
        rise_detector r5(clk, rst, vio_center_x_move_left,  vio_center_x_move_left_rise);

        rise_detector r6(clk, rst, vio_center_y_set,       vio_center_y_set_rise);
        rise_detector r7(clk, rst, vio_center_y_move_up,   vio_center_y_move_up_rise);
        rise_detector r8(clk, rst, vio_center_y_move_down, vio_center_y_move_down_rise);

        logic signed [2:-FRAC_WIDTH] center_x_move_step;
        logic signed [2:-FRAC_WIDTH] center_y_move_step;

        constant_multiplier #(
            .INPUT_WIDTH     (3+FRAC_WIDTH),
            .CONSTANT_WIDTH  ($clog2(1920/8)+2),
            .OUTPUT_WIDTH    (3+FRAC_WIDTH),
            .SIGNED          (1),
            .CONSTANT        (1920/8),
            .LATENCY         (1)
        ) cmul_x (
            .clk       (clk),
            .rst       (rst),

            .s_valid   (1),
            .s_data    (xy_step),

            .m_valid   (),
            .m_data    (center_x_move_step)
        );

        constant_multiplier #(
            .INPUT_WIDTH     (3+FRAC_WIDTH),
            .CONSTANT_WIDTH  ($clog2(1080/8)+2),
            .OUTPUT_WIDTH    (3+FRAC_WIDTH),
            .SIGNED          (1),
            .CONSTANT        (1080/8),
            .LATENCY         (1)
        ) cmul_y (
            .clk       (clk),
            .rst       (rst),

            .s_valid   (1),
            .s_data    (xy_step),

            .m_valid   (),
            .m_data    (center_y_move_step)
        );

        always_ff @(posedge clk) begin
            if (vio_xy_step_set_rise) begin
                xy_step <= vio_xy_step;
            end

            if (vio_xy_step_shift_right_rise) begin
                xy_step <= xy_step >>> 1;
            end

            if (vio_xy_step_shift_left_rise) begin
                xy_step <= xy_step <<< 1;
            end

            if (vio_center_x_set_rise) begin
                center_x <= vio_center_x;
            end

            if (vio_center_x_move_left_rise) begin
                center_x <= center_x - center_x_move_step;
            end

            if (vio_center_x_move_right_rise) begin
                center_x <= center_x + center_x_move_step;
            end

            if (vio_center_y_set_rise) begin
                center_y <= vio_center_y;
            end

            if (vio_center_y_move_up_rise) begin
                center_y <= center_y + center_y_move_step;
            end

            if (vio_center_y_move_down_rise) begin
                center_y <= center_y - center_y_move_step;
            end

            if (rst) begin
                center_x <= 0;
                center_y <= 0;
                xy_step <= 0;
            end
        end

        vio_0 vio0 (
            .clk         (clk),

            .probe_in0   (adv7511_setup_error),
            .probe_in1   (adv7511_setup_done),
            .probe_in2   (ddr3_calib_complete),
            .probe_in3   (center_x),
            .probe_in4   (center_y),
            .probe_in5   (xy_step),

            .probe_out0  (vio_xy_step),
            .probe_out1  (vio_xy_step_set),
            .probe_out2  (vio_xy_step_shift_right),
            .probe_out3  (vio_xy_step_shift_left),

            .probe_out4  (vio_center_x),
            .probe_out5  (vio_center_x_set),
            .probe_out6  (vio_center_x_move_right),
            .probe_out7  (vio_center_x_move_left),

            .probe_out8  (vio_center_y),
            .probe_out9  (vio_center_y_set),
            .probe_out10 (vio_center_y_move_up),
            .probe_out11 (vio_center_y_move_down),

            .probe_out12 (max_it),
            .probe_out13 (start),
            .probe_out14 (cc_start_index)
        );
    end


endmodule
