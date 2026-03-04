import cfg::SI_LATENCY;

// verilator lint_off UNUSEDSIGNAL

module single_iteration #(
    FRAC_WIDTH = 32
)(
    input clk,

    input  logic signed [2:-FRAC_WIDTH] s_a,
    input  logic signed [2:-FRAC_WIDTH] s_b,
    input  logic signed [2:-FRAC_WIDTH] s_c,
    input  logic signed [2:-FRAC_WIDTH] s_d,

    output logic signed [2:-FRAC_WIDTH] m_a,
    output logic signed [2:-FRAC_WIDTH] m_b,
    output logic                        m_stop
);

    localparam L = SI_LATENCY - 2;

    if (SI_LATENCY < 3) begin
        $error();
    end

    logic signed [5:-2*FRAC_WIDTH] a2;
    logic signed [5:-2*FRAC_WIDTH] b2;
    logic signed [5:-2*FRAC_WIDTH] ab;
    logic signed [2:-FRAC_WIDTH]   c;
    logic signed [2:-FRAC_WIDTH]   d;

    mul_dsp #(3+FRAC_WIDTH, L, 1) m0 (clk, s_a, s_a, a2);
    mul_dsp #(3+FRAC_WIDTH, L, 1) m1 (clk, s_b, s_b, b2);
    mul_dsp #(3+FRAC_WIDTH, L, 1) m2 (clk, s_a, s_b, ab);

    delayer #(3+FRAC_WIDTH, L + 1) d0 (clk, s_c, c);
    delayer #(3+FRAC_WIDTH, L + 1) d1 (clk, s_d, d);

    logic signed [6:-2*FRAC_WIDTH] a2_plus_b2;
    logic signed [6:-2*FRAC_WIDTH] a2_minus_b2;
    logic signed [6:-2*FRAC_WIDTH] ab_times_2;

    always_ff @(posedge clk) begin
        a2_plus_b2  <= a2 + b2;
        a2_minus_b2 <= a2 - b2;
        ab_times_2  <= ab << 1;
        m_a         <= a2_minus_b2[2:-FRAC_WIDTH] + c;
        m_b         <= ab_times_2[2:-FRAC_WIDTH] + d;
        m_stop      <= |a2_plus_b2[6:2];
    end

endmodule

/*
(* use_dsp = "yes" *) module single_iteration #(
    parameter int FRAC_WIDTH = 32
)(
    input  logic clk,

    input  logic signed [2:-FRAC_WIDTH] s_a,
    input  logic signed [2:-FRAC_WIDTH] s_b,
    input  logic signed [2:-FRAC_WIDTH] s_c,
    input  logic signed [2:-FRAC_WIDTH] s_d,

    output logic signed [2:-FRAC_WIDTH] m_a,
    output logic signed [2:-FRAC_WIDTH] m_b,
    output logic                        m_stop
);

    // =========================================================================
    // STAGE 1: Input Registers (Maps to DSP48 A-REG and B-REG)
    // =========================================================================
    logic signed [2:-FRAC_WIDTH] a_stg1, b_stg1, c_stg1, d_stg1;

    always_ff @(posedge clk) begin
        a_stg1 <= s_a;
        b_stg1 <= s_b;
        c_stg1 <= s_c;
        d_stg1 <= s_d;
    end

    // =========================================================================
    // STAGE 2: Multipliers (Maps to DSP48 M-REG or P-REG)
    // =========================================================================
    // Full 70-bit precision to keep the DSP fast.
    logic signed [5:-2*FRAC_WIDTH] a2_stg2;
    logic signed [5:-2*FRAC_WIDTH] b2_stg2;
    logic signed [5:-2*FRAC_WIDTH] ab_stg2;

    // We must delay 'c' and 'd' to keep them aligned with the multiply pipeline
    logic signed [2:-FRAC_WIDTH]   c_stg2, d_stg2;

    always_ff @(posedge clk) begin
        a2_stg2 <= a_stg1 * a_stg1;
        b2_stg2 <= b_stg1 * b_stg1;
        ab_stg2 <= a_stg1 * b_stg1;

        c_stg2  <= c_stg1;
        d_stg2  <= d_stg1;
    end

    // =========================================================================
    // STAGE 3: Fabric Adders & Stop Logic
    // =========================================================================
    logic signed [2:-FRAC_WIDTH] a_stg3;
    logic signed [2:-FRAC_WIDTH] b_stg3;
    logic                        stop_stg3;

    logic signed [6:-2*FRAC_WIDTH] a2_add_b2_stg2_comb;

    always_comb begin
        // Combinational add for the stop condition
        a2_add_b2_stg2_comb = a2_stg2 + b2_stg2;
    end

    always_ff @(posedge clk) begin
        // 1. We use signed'() to prevent the "Unsigned Slicing Trap"
        a_stg3 <= signed'(a2_stg2[2:-FRAC_WIDTH]) - signed'(b2_stg2[2:-FRAC_WIDTH]) + c_stg2;

        // 2. We shift the slice index by 1 to effectively multiply by 2
        //    WITHOUT losing the LSB precision bit.
        //    Index 1 corresponds to bit [2] shifted left once.
        b_stg3 <= signed'(ab_stg2[1:-(FRAC_WIDTH+1)]) + d_stg2;

        // 3. Stop logic
        stop_stg3 <= |a2_add_b2_stg2_comb[6:2];
    end

    // =========================================================================
    // STAGE 4: Final Latency Pad (To meet LATENCY = 4)
    // =========================================================================
    logic signed [2:-FRAC_WIDTH] a_stg4;
    logic signed [2:-FRAC_WIDTH] b_stg4;
    logic                        stop_stg4;

    always_ff @(posedge clk) begin
        a_stg4    <= a_stg3;
        b_stg4    <= b_stg3;
        stop_stg4 <= stop_stg3;
    end

    // =========================================================================
    // OUTPUT ASSIGNMENTS
    // =========================================================================
    assign m_a    = a_stg4;
    assign m_b    = b_stg4;
    assign m_stop = stop_stg4;

endmodule
*/

