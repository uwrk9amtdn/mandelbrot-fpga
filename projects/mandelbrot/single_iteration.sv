(* use_dsp = "yes" *) module single_iteration #(
    FRAC_WIDTH = 32
)(
    input clk,

    input  signed [2:-FRAC_WIDTH] s_a,
    input  signed [2:-FRAC_WIDTH] s_b,
    input  signed [2:-FRAC_WIDTH] s_c,
    input  signed [2:-FRAC_WIDTH] s_d,

    output signed [2:-FRAC_WIDTH] m_a,
    output signed [2:-FRAC_WIDTH] m_b,
    output                        m_stop
);

    // localparam LATENCY = 4;
    parameter LATENCY = 4;

    logic signed [2:-FRAC_WIDTH] a_reg    [LATENCY:0];
    logic signed [2:-FRAC_WIDTH] b_reg    [LATENCY:0];
    logic                        stop_reg [LATENCY:0];

    logic signed [5:-2*FRAC_WIDTH] a2;
    logic signed [5:-2*FRAC_WIDTH] b2;
    logic signed [5:-2*FRAC_WIDTH] a_mul_b;
    logic signed [6:-2*FRAC_WIDTH] a_mul_b_mul_2;
    logic signed [6:-2*FRAC_WIDTH] a2_add_b2;

    // ignored overflow (m_stop should assert before overflow)

    always_comb begin
        a2            = s_a * s_a;
        b2            = s_b * s_b;
        a_mul_b       = s_a * s_b;
        a_mul_b_mul_2 = a_mul_b << 1;
        a2_add_b2     = a2 + b2;

        a_reg    [0] = a2[2:-FRAC_WIDTH] - b2[2:-FRAC_WIDTH] + s_c;
        b_reg    [0] = a_mul_b_mul_2[2:-FRAC_WIDTH] + s_d;
        stop_reg [0] = |a2_add_b2[6:2];
    end

    always_ff @(posedge clk) begin
        for (int i = 0; i < LATENCY; i++) begin
            a_reg   [i+1] <= a_reg   [i];
            b_reg   [i+1] <= b_reg   [i];
            stop_reg[i+1] <= stop_reg[i];
        end
    end

    assign m_a    = a_reg    [LATENCY];
    assign m_b    = b_reg    [LATENCY];
    assign m_stop = stop_reg [LATENCY];

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
        // 1. We use $signed() to prevent the "Unsigned Slicing Trap"
        a_stg3 <= $signed(a2_stg2[2:-FRAC_WIDTH]) - $signed(b2_stg2[2:-FRAC_WIDTH]) + c_stg2;

        // 2. We shift the slice index by 1 to effectively multiply by 2
        //    WITHOUT losing the LSB precision bit.
        //    Index 1 corresponds to bit [2] shifted left once.
        b_stg3 <= $signed(ab_stg2[1:-(FRAC_WIDTH+1)]) + d_stg2;

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