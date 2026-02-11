module clock_gen_7series_pll #(
    int  N                     = 1,
    real INPUT_FREQ            = 200.0,
    real OUTPUT_FREQ       [N] = {200.0},
    real MAX_ERROR_PERCENT [N] = {0.0},
    real PLL_VCO_MIN           = 800.0,
    real PLL_VCO_MAX           = 1600.0,
    real PFD_MAX               = 450.0,
    real PFD_MIN               = 19.0
)(
    input  clk_in,
    output clk_out [N],
    input  reset,
    output locked
);
    if (N < 1 || N > 6) begin
        $error();
    end

    // DIVCLK_DIVIDE = 1
    if (INPUT_FREQ > PFD_MAX || INPUT_FREQ < PFD_MIN) begin
        $error();
    end

    typedef struct {
        bit  valid;
        int  M;
        int  D[N];
        real max_error;
    } pll_config_t;

    function pll_config_t calc_best_config();
        pll_config_t best_cfg;
        pll_config_t cfg;
        real         vco_freq;
        real         out_freq;
        real         error_percent;
        int          div;

        best_cfg.valid = 0;

        for (int m = 2; m <= 64; m++) begin

            vco_freq = INPUT_FREQ * m;

            if (vco_freq > PLL_VCO_MAX || vco_freq < PLL_VCO_MIN) begin
                continue;
            end

            cfg.valid     = 1;
            cfg.M         = m;
            cfg.max_error = 0;

            for (int i = 0; i < N; i++) begin

                div = int'(vco_freq / OUTPUT_FREQ[i]);

                if (div < 1) div = 1;
                if (div > 128) div = 128;

                cfg.D[i] = div;

                out_freq = vco_freq / div;

                error_percent = (out_freq - OUTPUT_FREQ[i]) / OUTPUT_FREQ[i] * 100.0;
                if (error_percent < 0) error_percent = -error_percent;

                if (error_percent > MAX_ERROR_PERCENT[i]) begin
                    cfg.valid = 0;
                    break;
                end

                if (error_percent > cfg.max_error) begin
                    cfg.max_error = error_percent;
                end
            end

            if (cfg.valid) begin
                if (cfg.max_error < best_cfg.max_error || best_cfg.valid == 0) begin
                    best_cfg.valid     = 1;
                    best_cfg.max_error = cfg.max_error;
                    best_cfg.M         = cfg.M;
                    best_cfg.D         = cfg.D;

                    if (cfg.max_error == 0.0) break;
                end
            end
        end

        return best_cfg;
    endfunction

    localparam pll_config_t CFG = calc_best_config();

    if (!CFG.valid) begin
        $error();
    end

    wire clkfbin;
    wire clkfbout;
    wire pll_clk_out [6];

    PLLE2_BASE #(
        .BANDWIDTH            ("OPTIMIZED"),

        .CLKFBOUT_MULT        (CFG.M),

        .CLKFBOUT_PHASE       (0.000),

        .CLKIN1_PERIOD        (1000.0/INPUT_FREQ),

        .CLKOUT0_DIVIDE       (CFG.D[0]),
        .CLKOUT1_DIVIDE       (N > 1 ? CFG.D[1] : 1),
        .CLKOUT2_DIVIDE       (N > 2 ? CFG.D[2] : 1),
        .CLKOUT3_DIVIDE       (N > 3 ? CFG.D[3] : 1),
        .CLKOUT4_DIVIDE       (N > 4 ? CFG.D[4] : 1),
        .CLKOUT5_DIVIDE       (N > 5 ? CFG.D[5] : 1),

        .CLKOUT0_DUTY_CYCLE   (0.500),
        .CLKOUT1_DUTY_CYCLE   (0.500),
        .CLKOUT2_DUTY_CYCLE   (0.500),
        .CLKOUT3_DUTY_CYCLE   (0.500),
        .CLKOUT4_DUTY_CYCLE   (0.500),
        .CLKOUT5_DUTY_CYCLE   (0.500),

        .CLKOUT0_PHASE        (0.000),
        .CLKOUT1_PHASE        (0.000),
        .CLKOUT2_PHASE        (0.000),
        .CLKOUT3_PHASE        (0.000),
        .CLKOUT4_PHASE        (0.000),
        .CLKOUT5_PHASE        (0.000),

        .DIVCLK_DIVIDE        (1)
    ) pll (
        .CLKFBIN             (clkfbin),
        .CLKFBOUT            (clkfbout),

        .CLKIN1              (clk_in),

        .CLKOUT0             (pll_clk_out[0]),
        .CLKOUT1             (pll_clk_out[1]),
        .CLKOUT2             (pll_clk_out[2]),
        .CLKOUT3             (pll_clk_out[3]),
        .CLKOUT4             (pll_clk_out[4]),
        .CLKOUT5             (pll_clk_out[5]),

        .LOCKED              (locked),
        .PWRDWN              (0),
        .RST                 (reset)
    );

    BUFG bufg (.I(clkfbout), .O(clkfbin));

    for (genvar i = 0; i < N; i++) begin
        BUFGCE bufgce (
            .I  (pll_clk_out[i]),
            .CE (locked),
            .O  (clk_out[i])
        );
    end

endmodule
