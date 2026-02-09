module top (
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
    wrapper #(
        .FRAC_WIDTH    (8),
        .NCORES        (64),
        .ARBITER_SIZE  (4),
        .FB_START_ADDR (0)
    ) wrapper0 (
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

module mandelbrot(
    input clk,

    // pixel clock domain
    input        pixel_clk, // 148.5 MHz
    output [7:0] r,
    output [7:0] g,
    output [7:0] b,
    output       hsync,
    output       vsync
);

    reg         we;
    reg  [31:0] addr;
    reg  [23:0] rgb;
    wire        sync;

    display_driver #(
        .active_pixels_h (1920),
        .front_porch_h   (88),
        .sync_width_h    (44),
        .back_porch_h    (148),

        .active_pixels_v (1080),
        .front_porch_v   (4),
        .sync_width_v    (5),
        .back_porch_v    (36)
    ) dpy (
        .clk  (clk),
        .we   (we),
        .addr (addr),
        .rgb  (rgb),
        .sync (sync),

        .pixel_clk (pixel_clk), // 148.5 MHz
        .r         (r),
        .g         (g),
        .b         (b),
        .hsync     (hsync),
        .vsync     (vsync)
    );

    typedef enum tstate {WAIT_SYNC, UPDATE} state;

    reg [$clog2(dpy.active_pixels_h)-1:0] px;
    reg [$clog2(dpy.active_pixels_v)-1:0] py;

    always_ff @(posedge clk) begin
        case (state);
            WAIT_SYNC: begin
                px   <= 0;
                py   <= 0;
                addr <= 0;
                if (sync) state <= UPDATE;
            end

            UPDATE: begin

            end
        endcase
    end

endmodule