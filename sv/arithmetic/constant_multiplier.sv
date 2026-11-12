module constant_multiplier #(
    int                      INPUT_WIDTH    = 8,
    int                      CONSTANT_WIDTH = 11,
    int                      OUTPUT_WIDTH   = INPUT_WIDTH + CONSTANT_WIDTH,
    bit                      SIGNED         = 1,
    bit [CONSTANT_WIDTH-1:0] CONSTANT       = 960,
    int                      LATENCY        = 1
)(
    input  logic                    clk,
    input  logic                    rst,

    input  logic                    s_valid,
    input  logic [INPUT_WIDTH-1:0]  s_data,

    output logic                    m_valid,
    output logic [OUTPUT_WIDTH-1:0] m_data
);
    // (* shreg_extract = "no" *)
    logic [OUTPUT_WIDTH-1:0] d;

    logic                    v;

    if (SIGNED) begin
        assign d = signed'(s_data) * signed'(CONSTANT);
    end else begin
        assign d = s_data * CONSTANT;
    end

    assign v = s_valid;

    if (LATENCY == 0) begin
        assign m_valid = v;
        assign m_data  = d;
    end else begin
        logic [OUTPUT_WIDTH-1:0] d_reg [LATENCY];
        logic                    v_reg [LATENCY];

        always_ff @(posedge clk) begin
            d_reg[0] <= d;
            v_reg[0] <= v;
            for (int i = 1; i < LATENCY; i++) begin
                d_reg[i] <= d_reg[i-1];
                v_reg[i] <= v_reg[i-1];
            end

            if (rst) begin
                for (int i = 0; i < LATENCY; i++) begin
                    v_reg[i] <= 0;
                end
            end
        end

        assign m_valid = v_reg[LATENCY-1];
        assign m_data  = d_reg[LATENCY-1];
    end


endmodule