module axis_cdc_handshake #(
    int SYNC_STAGES = 4
)(
    input     s_clk,
    input     s_rst,
    input     m_clk,
    input     m_rst,
    axis_intf s,
    axis_intf m
);

    if (s.DATA_WIDTH != m.DATA_WIDTH || s.LAST_EN != m.LAST_EN) begin
        $error();
    end

    logic m_req;
    logic s_ack;
    logic s_req   = 0;
    logic m_ack   = 0;
    logic m_req_d = 0;

    logic [s.DATA_WIDTH-1:0] data;
    logic                    last;

    cdc_single #(
        .SYNC_STAGES   (SYNC_STAGES),
        .INITIAL_VALUE (0)
    ) cdc_req (
        .clk (m_clk),
        .i   (s_req),
        .o   (m_req)
    );

    cdc_single #(
        .SYNC_STAGES   (SYNC_STAGES),
        .INITIAL_VALUE (0)
    ) cdc_ack (
        .clk (s_clk),
        .i   (m_ack),
        .o   (s_ack)
    );

    assign s.ready = ~s_req & ~s_ack;

    always_ff @(posedge s_clk) begin
        if (s.ready & s.valid) begin
            data  <= s.data;
            last  <= s.last;
            s_req <= 1;
        end
        if (s_ack) begin
            s_req <= 0;
        end
        if (s_rst) begin
            s_req   <= 0;
        end
    end

    always_ff @(posedge m_clk) begin
        m_req_d <= m_req;
        if (m_req & ~m_req_d) begin
            m.valid <= 1;
            m.data  <= data;
            m.last  <= last;
        end
        if (m.ready & m.valid) begin
            m.valid <= 0;
            m_ack   <= 1;
        end
        if (~m_req) begin
            m_ack <= 0;
        end
        if (m_rst) begin
            m_ack   <= 0;
            m_req_d <= 0;
            m.valid <= 0;
        end
    end

endmodule

module axis_cdc_handshake_ #(
    int SYNC_STAGES = 4
)(
    input     s_clk,
    input     s_rst,
    input     m_clk,
    input     m_rst,
    axis_intf s,
    axis_intf m
);

    if (s.DATA_WIDTH != m.DATA_WIDTH || s.LAST_EN != m.LAST_EN) begin
        $error();
    end

    logic m_req;
    logic s_ack;
    logic s_req   = 0;
    logic m_ack   = 0;
    logic m_req_d = 0;

    logic [s.DATA_WIDTH:0] s_data;
    logic [s.DATA_WIDTH:0] m_data;

    xpm_cdc_handshake #(
        .DEST_EXT_HSK   (1),
        .DEST_SYNC_FF   (SYNC_STAGES),
        .INIT_SYNC_FF   (0),
        .SIM_ASSERT_CHK (0),
        .SRC_SYNC_FF    (SYNC_STAGES),
        .WIDTH          (s.DATA_WIDTH + 1)
    ) cdc (
        .dest_out  (m_data),
        .dest_req  (m_req),
        .src_rcv   (s_ack),
        .dest_ack  (m_ack),
        .dest_clk  (m_clk),
        .src_clk   (s_clk),
        .src_in    (s_data),
        .src_send  (s_req)
    );

    assign s.ready = ~s_req & ~s_ack;

    always_ff @(posedge s_clk) begin
        if (s.ready & s.valid) begin
            s_data <= {s.data, s.last};
            s_req  <= 1;
        end
        if (s_ack) begin
            s_req <= 0;
        end
        if (s_rst) begin
            s_req   <= 0;
        end
    end

    always_ff @(posedge m_clk) begin
        m_req_d <= m_req;
        if (m_req & ~m_req_d) begin
            m.valid          <= 1;
            {m.data, m.last} <= m_data;
        end
        if (m.ready & m.valid) begin
            m.valid <= 0;
            m_ack   <= 1;
        end
        if (~m_req) begin
            m_ack <= 0;
        end
        if (m_rst) begin
            m_ack   <= 0;
            m_req_d <= 0;
            m.valid <= 0;
        end
    end

endmodule