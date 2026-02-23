module top(
    input  logic clk_p, // 200 MHz
    input  logic clk_n,

    inout  logic [63:0] ddr3_dq,
    inout  logic [7:0]  ddr3_dqs_n,
    inout  logic [7:0]  ddr3_dqs_p,
    output logic [13:0] ddr3_addr,
    output logic [2:0]  ddr3_ba,
    output logic        ddr3_ras_n,
    output logic        ddr3_cas_n,
    output logic        ddr3_we_n,
    output logic        ddr3_reset_n,
    output logic [0:0]  ddr3_ck_p,
    output logic [0:0]  ddr3_ck_n,
    output logic [0:0]  ddr3_cke,
    output logic [0:0]  ddr3_cs_n,
    output logic [7:0]  ddr3_dm,
    output logic [0:0]  ddr3_odt
);

    logic clk;

    logic ddr3_ctrl_clk;
    logic ddr3_ctrl_rst;

    logic ddr3_clk;
    logic ddr3_clk_90;
    logic ddr3_ref_clk;

    axi_intf #(
        .ID_WIDTH   (4),
        .ADDR_WIDTH (30),
        .DATA_WIDTH (512)
    ) ddr3_axi ();

    begin : clk_block
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
            .clk_in    (clk),
            .clk_out   ({ddr3_ctrl_clk, ddr3_clk, ddr3_clk_90, ddr3_ref_clk}),
            .reset     ('0),
            .locked    ()
        );
    end

    begin : rst_block
        power_on_reset por(ddr3_ctrl_clk, ddr3_ctrl_rst);
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
        ) ddr3 (
            .rst_n (ddr3_reset_n),
            .ck    (ddr3_ck_p),
            .ck_n  (ddr3_ck_n),
            .cke   (ddr3_cke),
            .cs_n  (ddr3_cs_n),
            .ras_n (ddr3_ras_n),
            .cas_n (ddr3_cas_n),
            .we_n  (ddr3_we_n),
            .dm    (ddr3_dm),
            .ba    (ddr3_ba),
            .addr  (ddr3_addr),
            .dq    (ddr3_dq),
            .dqs   (ddr3_dqs_p),
            .dqs_n (ddr3_dqs_n),
            .odt   (ddr3_odt)
        );

        uberddr3_wrapper_axi #(
            .CLK_PERIOD_PS      (10000),
            .DDR3_CLK_PERIOD_PS (2500),
            .MICRON_SIM         (1)
        ) uberddr3 (
            .clk            (ddr3_ctrl_clk),
            .rst            (ddr3_ctrl_rst),

            .ddr3_clk       (ddr3_clk),
            .ddr3_clk_90    (ddr3_clk_90),
            .ref_clk        (ddr3_ref_clk),

            .calib_complete (calib_complete),

            .s_axi          (ddr3_axi),

            .ddr3           (ddr3)
        );
    end

endmodule