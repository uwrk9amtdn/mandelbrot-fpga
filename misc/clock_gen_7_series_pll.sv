module clock_gen_7series_pll #(
    int  N                     = 1,
    real INPUT_FREQ            = 200.0,
    real OUTPUT_FREQ       [N] = '{default: 200.0},
    real MAX_ERROR_PERCENT [N] = '{default: 0.0},
    real PLL_VCO_MIN           = 800.0,
    real PLL_VCO_MAX           = 1600.0,
    real PFD_MAX               = 450.0,
    real PFD_MIN               = 19.0
)(
    input          clk_in,
    output [N-1:0] clk_out,
    input          reset,
    output         locked
);
    if (N < 1 || N > 6) begin
        $fatal(1, "N must be between 1 and 6");
    end

    typedef struct {
        bit  valid;
        int  D1;
        int  M;
        int  D2[6];
        real max_error;
        real freq [6];
    } pll_config_t;

    // DIVCLK_DIVIDE  = (1-56)
    // CLKOUT0_DIVIDE = (1-128)
    // CLKFBOUT_MULT  = (2-64)

    // TODO: clocking wizard does not conform vco_max freq 1600 mhz for input_freq = 200.0 and output freq = 148.5
    function pll_config_t calc_best_config();
        pll_config_t best_cfg;
        pll_config_t cfg;
        real         vco_freq;
        real         out_freq;
        real         error_percent;
        int          d2;

        best_cfg.valid = 0;
        best_cfg.max_error = 1.0e6;

        for (int d1 = 1; d1 <= 56; d1++) begin
            if (INPUT_FREQ / d1 < PFD_MIN) begin
                break;
            end

            if (INPUT_FREQ / d1 > PFD_MAX) begin
                continue;
            end

            for (int m = 2; m <= 64; m++) begin

                vco_freq = (INPUT_FREQ / d1) * m;

                if (vco_freq > PLL_VCO_MAX || vco_freq < PLL_VCO_MIN) begin
                    continue;
                end

                cfg.valid     = 1;
                cfg.M         = m;
                cfg.max_error = 0;
                cfg.D1        = d1;
                cfg.D2        = '{default:1};

                for (int i = 0; i < N; i++) begin

                    d2 = int'(vco_freq / OUTPUT_FREQ[i]);

                    if (d2 < 1) d2 = 1;
                    if (d2 > 128) d2 = 128;

                    cfg.D2[i]   = d2;
                    out_freq    = vco_freq / d2;
                    cfg.freq[i] = out_freq;

                    error_percent = (out_freq - OUTPUT_FREQ[i]) / OUTPUT_FREQ[i] * 100.0;
                    if (error_percent < 0) error_percent = -error_percent;

                    if (error_percent > MAX_ERROR_PERCENT[i]) begin
                        cfg.valid = 0;
                    end

                    if (error_percent > cfg.max_error) begin
                        cfg.max_error = error_percent;
                    end
                end

                if ((cfg.valid || !best_cfg.valid) && (cfg.max_error < best_cfg.max_error)) begin
                    best_cfg = cfg;
                    if (cfg.valid && cfg.max_error == 0.0) begin
                        return best_cfg;
                    end
                end
            end
        end

        return best_cfg;
    endfunction

    localparam pll_config_t CFG = calc_best_config();

/*
    TODO: ERROR: [VRFC 10-2971] 'get_config_string' is not a valid constant function call
    function string get_config_string(pll_config_t cfg);
        string r;
        r = {r, $sformatf("D1 = %0d\nM = %0d\nD2 = { ", cfg.D1, cfg.M)};
        for (int i = 0; i < N; i++) begin
            r = {r, $sformatf("%0d, ", cfg.D2[i])};
        end
        r = {r, $sformatf("}\nmax_error = %%%.6f\nfreq = { ", cfg.max_error)};
        for (int i = 0; i < N; i++) begin
            r = {r, $sformatf("%.6f, ", cfg.freq[i])};
        end
        r = {r, "}\n"};
        return r;
    endfunction
*/

    if (!CFG.valid) begin
        // TODO: simplify this
        case (N)
            1: $fatal(1, "Could not find valid PLL configuration in specified error range. Best configuration was: %.6f", CFG.freq[0]);
            2: $fatal(1, "Could not find valid PLL configuration in specified error range. Best configuration was: %.6f, %.6f", CFG.freq[0], CFG.freq[1]);
            3: $fatal(1, "Could not find valid PLL configuration in specified error range. Best configuration was: %.6f, %.6f, %.6f", CFG.freq[0], CFG.freq[1], CFG.freq[2]);
            4: $fatal(1, "Could not find valid PLL configuration in specified error range. Best configuration was: %.6f, %.6f, %.6f, %.6f", CFG.freq[0], CFG.freq[1], CFG.freq[2], CFG.freq[3]);
            5: $fatal(1, "Could not find valid PLL configuration in specified error range. Best configuration was: %.6f, %.6f, %.6f, %.6f, %.6f", CFG.freq[0], CFG.freq[1], CFG.freq[2], CFG.freq[3], CFG.freq[4]);
            6: $fatal(1, "Could not find valid PLL configuration in specified error range. Best configuration was: %.6f, %.6f, %.6f, %.6f, %.6f, %.6f", CFG.freq[0], CFG.freq[1], CFG.freq[2], CFG.freq[3], CFG.freq[4], CFG.freq[5]);
        endcase
    end

    `ifndef SYNTHESIS
        initial begin
        string s;
            s = {s, "-------------------------\n"};
            s = {s, "PLL CLOCK CONFIGURATION:\n"};
            for (int i = 0; i < N; i++) begin
                s = {s, $sformatf("CLK %d : %.6fMHz\n", i, CFG.freq[i])};
            end
            s = {s, "-------------------------\n"};
            $info(s);
        end
    `endif

    wire clkfbin;
    wire clkfbout;
    wire pll_clk_out [6];

    PLLE2_BASE #(
        .BANDWIDTH            ("OPTIMIZED"),

        .CLKFBOUT_MULT        (CFG.M),

        .CLKFBOUT_PHASE       (0.000),

        .CLKIN1_PERIOD        (1000.0/INPUT_FREQ),

        .CLKOUT0_DIVIDE       (CFG.D2[0]),
        .CLKOUT1_DIVIDE       (CFG.D2[1]),
        .CLKOUT2_DIVIDE       (CFG.D2[2]),
        .CLKOUT3_DIVIDE       (CFG.D2[3]),
        .CLKOUT4_DIVIDE       (CFG.D2[4]),
        .CLKOUT5_DIVIDE       (CFG.D2[5]),

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

        .DIVCLK_DIVIDE        (CFG.D1)
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
        .PWRDWN              ('0),
        .RST                 (reset)
    );

    BUFG bufg (.I(clkfbout), .O(clkfbin));

    for (genvar i = 0; i < N; i++) begin : bufgce_gen
        BUFGCE bufgce (
            .I  (pll_clk_out[i]),
            .CE (locked),
            .O  (clk_out[i])
        );
    end

endmodule
