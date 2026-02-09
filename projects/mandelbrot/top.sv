module mandelbrot_top (
    input clk_p,
    input clk_n,

    logic                ddr3_rst_n;
    logic                ddr3_ck;
	logic                ddr3_ck_n;
    logic                ddr3_cke;
    logic                ddr3_cs_n;
    logic                ddr3_ras_n;
    logic                ddr3_cas_n;
    logic                ddr3_we_n;
    logic [DM_BITS-1:0]  ddr3_dm;
    logic [BA_BITS-1:0]  ddr3_ba;
    logic [ROW_BITS-1:0] ddr3_addr;
    wire  [DQ_BITS-1:0]  ddr3_dq;
    wire  [DQS_BITS-1:0] ddr3_dqs;
    wire  [DQS_BITS-1:0] ddr3_dqs_n;
    logic                ddr3_odt;
);


    mandelbrot_wrapper #(
        .FRAC_WIDTH    (8),
        .NCORES        (64),
        .ARBITER_SIZE  (4),
        .FB_START_ADDR (0)
    ) mandelbrot_wrapper0 (
        .clk              (),
        .rst              (),

        .s_ready          (),
        .s_valid          (),
        .s_max_it         (),
        .s_center_x       (),
        .s_center_y       (),
        .s_pixel_distance (),

        axi_intf mem,
    );

    uberddr3_wrapper_axi #(
        CLK_PERIOD_PS      (12_000),
        DDR3_CLK_PERIOD_PS (3_000)
    ) uberddr3_wrapper_axi0 (
        .clk                (),
        .rst                (),

        .ddr3_clk           (),
        .ref_clk            (), // 200 MHz

        .calib_complete     (),

        .s_axi              (),

        .ddr3               ()
    );

endmodule