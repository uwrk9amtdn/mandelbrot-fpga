module constant_multiplier #(
    int                      DATA_WIDTH     = 8,
    int                      CONSTANT_WIDTH = 10,
    bit                      SIGNED         = 0,
    bit [CONSTANT_WIDTH-1:0] CONSTANT       = 960,
    int                      LATENCY        = 1
)(
    input  logic                                 clk,
    input  logic                                 rst,

    input  logic                                 s_valid,
    input  logic [DATA_WIDTH-1:0]                s_data,

    output logic                                 m_valid,
    output logic [DATA_WIDTH+CONSTANT_WIDTH-1:0] m_data
);


    logic [DATA_WIDTH+CONSTANT_WIDTH-1:0] d [LATENCY+1];
    logic                                 v [LATENCY+1];

    if (SIGNED) begin
        assign d[0] = $signed(s_data) * $signed(CONSTANT);
    end else begin
        assign d[0] = s_data * CONSTANT;
    end

    assign v[0] = s_valid;

    for (genvar i = 0; i < LATENCY; i++) begin
        always_ff @(posedge clk) begin
            v [i+1] <= v[i];
            d [i+1] <= d[i];
            if (rst) begin
                v[i+1] <= 0;
            end
        end
    end

    assign m_valid = v[LATENCY];
    assign m_data  = d[LATENCY];


endmodule