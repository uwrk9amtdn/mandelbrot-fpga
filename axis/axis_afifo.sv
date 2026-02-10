module axis_afifo #(
    int SYNC_STAGES = 2,
    int DEPTH       = 32
)(
    input s_clk,
    input s_rst,
    input m_clk,
    input m_rst,

    axis_intf s,
    axis_intf m
);

    if (s.DATA_WIDTH != m.DATA_WIDTH) begin
        $error();
    end

    if ((DEPTH & (DEPTH - 1)) != 0) begin
        $error();
    end

    logic o_wr_full;
    logic o_rd_empty;
    logic i_rd;

    assign s.ready = ~o_wr_full;

    afifo #(
        .LGFIFO             ($clog2(DEPTH)),
        .WIDTH              (s.DATA_WIDTH),
        .NFF                (SYNC_STAGES),
        .WRITE_ON_POSEDGE   (1),
        .OPT_REGISTER_READS (1)
    ) afifo0 (
        .i_wclk        (s_clk),
        .i_wr_reset_n  (~s_rst),
        .i_wr          (s.valid & ~o_wr_full),
        .i_wr_data     (s.data),
        .o_wr_full     (o_wr_full),

        .i_rclk        (m_clk),
        .i_rd_reset_n  (~m_rst),
        .i_rd          (i_rd),
        .o_rd_data     (m.data),
        .o_rd_empty    (o_rd_empty)
    );

    assign i_rd = (m.ready | ~m.valid) & ~o_rd_empty;

    always_ff @(posedge m_clk) begin
        if (m.ready | ~m.valid) begin
            m.valid <= i_rd;
        end

        if (m_rst) begin
            m.valid <= 0;
        end
    end

endmodule