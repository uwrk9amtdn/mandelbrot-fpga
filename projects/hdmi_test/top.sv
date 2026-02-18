module top(

    input clk_p, // 200 MHz
    input clk_n,

    inout sda,
    inout scl,

    output        pixel_clk,
    output [7:0]  r,
    output [7:0]  g,
    output [7:0]  b,
    output        hsync,
    output        vsync,
    output        de
);

    logic sysclk;
    logic clk;
    logic rst;
    logic vio_rst;
    logic adv7511_setup_error;
    logic adv7511_setup_done;

    logic [23:0] c0;
    logic [23:0] c1;
    logic [23:0] c2;
    logic [23:0] c3;

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

        assign clk = sysclk;
    end

    begin : rst_block
        logic [3:0] ctr;
        logic       rst_;
        assign rst = rst_ | vio_rst;
        initial begin
            ctr  <= 0;
            rst_ <= 1;
        end

        always @(posedge clk) begin
            if (ctr != 4'hf) begin
                ctr  <= ctr + 1;
                rst_ <= 0;
            end
        end
    end

    begin : i2c_block
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
    end

    begin : display_block

        logic [23:0] rgb;

        logic [23:0] c0_synced;
        logic [23:0] c1_synced;
        logic [23:0] c2_synced;
        logic [23:0] c3_synced;

        cdc_multi #(4, 24) c0_cdc (clk, pixel_clk, c0, c0_synced);
        cdc_multi #(4, 24) c1_cdc (clk, pixel_clk, c1, c1_synced);
        cdc_multi #(4, 24) c2_cdc (clk, pixel_clk, c2, c2_synced);
        cdc_multi #(4, 24) c3_cdc (clk, pixel_clk, c3, c3_synced);

        logic [31:0] y;

        always_comb begin
            case (y[5:4])
                2'b00: rgb = c0_synced;
                2'b01: rgb = c1_synced;
                2'b10: rgb = c2_synced;
                2'b11: rgb = c3_synced;
            endcase
        end

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
            .y     (y),
            .rgb   (rgb),

            .r     (r),
            .g     (g),
            .b     (b),
            .hsync (hsync),
            .vsync (vsync),
            .de    (de)
        );
    end

    vio_0 vio (
        .clk        (clk),
        .probe_in0  (adv7511_setup_error),
        .probe_in1  (adv7511_setup_done),
        .probe_out0 (vio_rst),
        .probe_out1 (c0),
        .probe_out2 (c1),
        .probe_out3 (c2),
        .probe_out4 (c3)
    );

endmodule