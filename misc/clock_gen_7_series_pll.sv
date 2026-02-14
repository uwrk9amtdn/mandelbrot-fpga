module clock_gen_7series_pll #(
    int  N                   = 1,
    real INPUT_FREQ          = 200.0,             // MHz
    real OUTPUT_FREQ     [N] = '{default: 200.0}, // MHz
    real OUTPUT_PHASE    [N] = '{default: 0.0},   // Degree
    real MAX_FREQ_ERROR  [N] = '{default: 0.0},   // Percent
    real MAX_PHASE_ERROR [N] = '{default: 0.0},   // Percent
    real VCO_MIN             = 800.0,             // MHz
    real VCO_MAX             = 1600.0,            // MHz
    real PFD_MIN             = 19.0,              // MHz
    real PFD_MAX             = 450.0              // MHz
)(
    input          clk_in,
    output [0:N-1] clk_out,
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
        real P[6];
        real max_freq_error;
        real max_phase_error;
        real freq [6];
        real phase [6];
    } pll_config_t;

    // DIVCLK_DIVIDE  = (1-56)
    // CLKOUT0_DIVIDE = (1-128)
    // CLKFBOUT_MULT  = (2-64)

    // frequency accuracy is prioritized
    function pll_config_t calc_best_config();
        pll_config_t best_cfg;
        pll_config_t cfg;
        real         vco_freq;
        real         out_freq;
        real         freq_error;
        real         phase_error;
        real         out_phase;
        real         phase_step;
        int          d2;

        best_cfg.valid = 0;
        best_cfg.max_freq_error = 1.0e6;
        best_cfg.max_phase_error = 1.0e6;

        for (int d1 = 1; d1 <= 56; d1++) begin
            if (INPUT_FREQ / d1 < PFD_MIN) begin
                break;
            end

            if (INPUT_FREQ / d1 > PFD_MAX) begin
                continue;
            end

            for (int m = 64; m >= 2; m--) begin

                vco_freq = (INPUT_FREQ / d1) * m;

                if (vco_freq > VCO_MAX) begin
                    continue;
                end

                if (vco_freq < VCO_MIN) begin
                    break;
                end

                cfg.valid           = 1;
                cfg.M               = m;
                cfg.max_freq_error  = 0;
                cfg.max_phase_error = 0;
                cfg.D1              = d1;
                cfg.D2              = '{default:128};
                cfg.P               = '{default:0.0};

                for (int i = 0; i < N; i++) begin

                    d2 = int'(vco_freq / OUTPUT_FREQ[i]);

                    if (d2 < 1) d2 = 1;
                    if (d2 > 128) d2 = 128;

                    cfg.D2[i]   = d2;
                    out_freq    = vco_freq / d2;
                    cfg.freq[i] = out_freq;

                    phase_step   = 360.0 / (8.0 * d2);
                    out_phase    = (int'(OUTPUT_PHASE[i] / phase_step)) * phase_step;
                    cfg.phase[i] = out_phase;
                    cfg.P[i]     = out_phase;

                    freq_error = (out_freq - OUTPUT_FREQ[i]) / OUTPUT_FREQ[i] * 100.0;
                    if (freq_error < 0) freq_error = -freq_error;

                    phase_error = (out_phase - OUTPUT_PHASE[i]) / OUTPUT_PHASE[i] * 100.0;
                    if (phase_error < 0) phase_error = -phase_error;

                    if (freq_error > MAX_FREQ_ERROR[i]) begin
                        cfg.valid = 0;
                    end

                    if (phase_error > MAX_PHASE_ERROR[i]) begin
                        cfg.valid = 0;
                    end

                    if (freq_error > cfg.max_freq_error) begin
                        cfg.max_freq_error = freq_error;
                    end

                    if (phase_error > cfg.max_phase_error) begin
                        cfg.max_phase_error = phase_error;
                    end
                end

                if ((cfg.valid || !best_cfg.valid) &&
                    (
                        (cfg.max_freq_error < best_cfg.max_freq_error) ||
                        ((cfg.max_freq_error - best_cfg.max_freq_error < 0.00001) && (cfg.max_phase_error < best_cfg.max_phase_error))
                    )
                ) begin
                    best_cfg = cfg;
                end
            end
        end

        return best_cfg;
    endfunction

    localparam pll_config_t CFG = calc_best_config();

    if (!CFG.valid) begin
        $fatal(1, "Could not find a valid PLL configuration in the specified error range. Best configuration was: Freq: {%f, %f, %f, %f, %f, %f}, Phase: {%f, %f, %f, %f, %f, %f}",
            CFG.freq[0], CFG.freq[1], CFG.freq[2], CFG.freq[3], CFG.freq[4], CFG.freq[5],
            CFG.phase[0], CFG.phase[1], CFG.phase[2], CFG.phase[3], CFG.phase[4], CFG.phase[5]
        );
    end

    `ifndef SYNTHESIS
        initial begin
            $info("PLL CLOCK CONFIGURATION: Freq: {%f, %f, %f, %f, %f, %f}, Phase: {%f, %f, %f, %f, %f, %f}",
                CFG.freq[0], CFG.freq[1], CFG.freq[2], CFG.freq[3], CFG.freq[4], CFG.freq[5],
                CFG.phase[0], CFG.phase[1], CFG.phase[2], CFG.phase[3], CFG.phase[4], CFG.phase[5]
            );
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

        .CLKOUT0_PHASE        (CFG.P[0]),
        .CLKOUT1_PHASE        (CFG.P[1]),
        .CLKOUT2_PHASE        (CFG.P[2]),
        .CLKOUT3_PHASE        (CFG.P[3]),
        .CLKOUT4_PHASE        (CFG.P[4]),
        .CLKOUT5_PHASE        (CFG.P[5]),

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
