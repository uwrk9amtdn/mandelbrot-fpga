// TODO

module clock_gen_7series_pll #(
    parameter int  N = 1,
    parameter real INPUT_FREQ = 200.0,
    parameter real OUTPUT_FREQ [N] = '{200.0},
    parameter real MAX_ERROR_PERCENT [N] = '{0.0},
    parameter real PLL_VCO_MIN = 800.0,
    parameter real PLL_VCO_MAX = 1600.0
)(
    input  wire logic clk_in,
    output wire logic [N-1:0] clk_out,
    input  wire logic reset,
    output wire logic locked
);

    // ---------------------------------------------------------
    // Validation
    // ---------------------------------------------------------
    if (N < 1 || N > 6) begin : gen_param_err
        $error("Parameter N must be between 1 and 6.");
    end

    // ---------------------------------------------------------
    // Types & Logic
    // ---------------------------------------------------------
    typedef struct {
        bit  valid;
        int  M;
        int  D[6];
        real max_error;
        real vco_freq;
    } pll_config_t;

    function automatic void sort_candidates(inout pll_config_t arr[64]);
        pll_config_t temp;
        bit swap;
        for (int i = 0; i < 64; i++) begin
            for (int j = 0; j < 63; j++) begin
                swap = 0;
                if (!arr[j].valid && arr[j+1].valid) begin
                    swap = 1;
                end
                else if (arr[j].valid == arr[j+1].valid) begin
                    if (arr[j+1].max_error < arr[j].max_error - 0.00001) begin
                        swap = 1;
                    end
                    else if ((arr[j+1].max_error >= arr[j].max_error - 0.00001) &&
                             (arr[j+1].max_error <= arr[j].max_error + 0.00001)) begin
                        if (arr[j+1].vco_freq < arr[j].vco_freq) swap = 1;
                    end
                end

                if (swap) begin
                    temp = arr[j]; arr[j] = arr[j+1]; arr[j+1] = temp;
                end
            end
        end
    endfunction

    function automatic pll_config_t[64] find_all_configs();
        pll_config_t candidates[64];
        pll_config_t current;
        real vco, out_f, err;
        int  div_val;

        for (int k = 0; k < 64; k++) begin
            candidates[k].valid = 0;
            candidates[k].max_error = 100000.0;
            candidates[k].M = 0;
            for(int d=0; d<6; d++) candidates[k].D[d] = 1;
        end

        for (int m = 2; m <= 64; m++) begin
            vco = INPUT_FREQ * real'(m);

            if (vco < PLL_VCO_MIN || vco > PLL_VCO_MAX) continue;

            current.M = m;
            current.vco_freq = vco;
            current.max_error = 0.0;
            current.valid = 1;

            for (int i = 0; i < N; i++) begin
                div_val = int'(vco / OUTPUT_FREQ[i]);
                if (div_val < 1)   div_val = 1;
                if (div_val > 128) div_val = 128;

                current.D[i] = div_val;

                out_f = vco / real'(div_val);
                err = (out_f - OUTPUT_FREQ[i]) / OUTPUT_FREQ[i] * 100.0;
                if (err < 0) err = -err;

                if (err > current.max_error) current.max_error = err;

                if (err > MAX_ERROR_PERCENT[i]) begin
                    current.valid = 0;
                end
            end
            candidates[m-2] = current;
        end
        sort_candidates(candidates);
        return candidates;
    endfunction

    // ---------------------------------------------------------
    // Elaboration & Reporting
    // ---------------------------------------------------------
    localparam pll_config_t CANDIDATES[64] = find_all_configs();
    localparam pll_config_t BEST = CANDIDATES[0];

    // Synthesis-time reporting using generate
    generate
        if (!BEST.valid) begin : gen_fail_report
            $info("----------------------------------------------------------------");
            $info("PLL CONFIG FAILURE: Could not meet constraints for Input=%.2f MHz", INPUT_FREQ);
            $info("Listing top 5 closest configurations:");

            for (genvar i = 0; i < 5; i++) begin : loop_print
                if (CANDIDATES[i].M > 0) begin
                     $info("Rank %0d: M=%0d | VCO=%.2f | MaxErr=%.4f%%",
                           i+1, CANDIDATES[i].M, CANDIDATES[i].vco_freq, CANDIDATES[i].max_error);
                end
            end
            $info("----------------------------------------------------------------");

            // $error stops synthesis after elaboration completes (allowing $info to print)
            $error("Synthesis Halted: No valid PLL configuration found within error margins.");
        end
    endgenerate

    // ---------------------------------------------------------
    // Instantiation
    // ---------------------------------------------------------
    wire clkfb;
    wire pll_clk_out [6];

    PLLE2_BASE #(
        .BANDWIDTH("OPTIMIZED"),
        .CLKFBOUT_MULT(BEST.M),
        .CLKIN1_PERIOD(1000.0 / INPUT_FREQ),
        .CLKOUT0_DIVIDE(BEST.D[0]),
        .CLKOUT1_DIVIDE(N > 1 ? BEST.D[1] : 1),
        .CLKOUT2_DIVIDE(N > 2 ? BEST.D[2] : 1),
        .CLKOUT3_DIVIDE(N > 3 ? BEST.D[3] : 1),
        .CLKOUT4_DIVIDE(N > 4 ? BEST.D[4] : 1),
        .CLKOUT5_DIVIDE(N > 5 ? BEST.D[5] : 1),
        .DIVCLK_DIVIDE(1)
    ) pll_inst (
        .CLKFBIN(clkfb), .CLKFBOUT(clkfb),
        .CLKIN1(clk_in), .RST(reset), .LOCKED(locked), .PWRDWN(1'b0),
        .CLKOUT0(pll_clk_out[0]), .CLKOUT1(pll_clk_out[1]),
        .CLKOUT2(pll_clk_out[2]), .CLKOUT3(pll_clk_out[3]),
        .CLKOUT4(pll_clk_out[4]), .CLKOUT5(pll_clk_out[5])
    );

    for (genvar i = 0; i < N; i++) begin : gen_out
        BUFGCE bufg (.I(pll_clk_out[i]), .CE(locked), .O(clk_out[i]));
    end

endmodule