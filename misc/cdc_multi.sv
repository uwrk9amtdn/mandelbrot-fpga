module cdc_multi #(
    int   SYNC_STAGES   = 2,
    int   DATA_WIDTH    = 8
)(
    input                   s_clk,
    input                   m_clk,
    input  [DATA_WIDTH-1:0] s,
    output [DATA_WIDTH-1:0] m
);

    cdc_handshake #(
        .SYNC_STAGES (SYNC_STAGES),
        .DATA_WIDTH  (DATA_WIDTH)
    ) cdc (
        .s_clk   (s_clk),
        .s_rst   (1'b0),
        .s_ready (),
        .s_valid (1'b1),
        .s_data  (s),

        .m_clk   (m_clk),
        .m_rst   (1'b0),
        .m_ready (1'b1),
        .m_valid (),
        .m_data  (m)
    );

endmodule