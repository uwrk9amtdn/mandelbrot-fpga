/*
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

    if (s.LAST_EN != m.LAST_EN) begin
        $error();
    end

    if ((DEPTH & (DEPTH - 1)) != 0) begin
        $error();
    end

    localparam int WIDTH = s.DATA_WIDTH + (s.LAST_EN ? 1 : 0);

    logic [WIDTH-1:0] i_wr_data;
    logic [WIDTH-1:0] o_rd_data;
    logic [WIDTH-1:0] o_rd_data_reg;
    logic             o_wr_full;
    logic             o_rd_empty;
    logic             i_rd;
    logic             i_wr;

    if (s.LAST_EN) begin
        assign i_wr_data        = {s.last, s.data};
        assign {m.last, m.data} = o_rd_data_reg;
    end else begin
        assign i_wr_data = s.data;
        assign m.data    = o_rd_data_reg;
    end

    assign s.ready = ~o_wr_full;

    assign i_rd = (m.ready | ~m.valid) & ~o_rd_empty;
    assign i_wr = s.valid & ~o_wr_full;

    afifo #(
        .LGFIFO             ($clog2(DEPTH)),
        .WIDTH              (WIDTH),
        .NFF                (SYNC_STAGES),
        .WRITE_ON_POSEDGE   (1),
        .OPT_REGISTER_READS (1)
    ) afifo0 (
        .i_wclk        (s_clk),
        .i_wr_reset_n  (~s_rst),
        .i_wr          (i_wr),
        .i_wr_data     (i_wr_data),
        .o_wr_full     (o_wr_full),

        .i_rclk        (m_clk),
        .i_rd_reset_n  (~m_rst),
        .i_rd          (i_rd),
        .o_rd_data     (o_rd_data),
        .o_rd_empty    (o_rd_empty)
    );

    always_ff @(posedge m_clk) begin
        if (m.ready | ~m.valid) begin
            m.valid       <= i_rd;
            o_rd_data_reg <= o_rd_data;
        end

        if (m_rst) begin
            m.valid <= 0;
        end
    end

endmodule
*/

module axis_afifo #(
    int SYNC_STAGES = 2,
    int DEPTH       = 32
)(
    input arst,

    input s_clk,
    input m_clk,

    axis_intf s,
    axis_intf m
);

    if (s.DATA_WIDTH != m.DATA_WIDTH) begin
        $error();
    end

    if (s.LAST_EN != m.LAST_EN) begin
        $error();
    end

    xpm_fifo_axis #(
        .CDC_SYNC_STAGES     (SYNC_STAGES),
        .CLOCKING_MODE       ("independent_clock"),
        .FIFO_DEPTH          (DEPTH),
        .TDATA_WIDTH         (s.DATA_WIDTH)
    ) xpm_fifo_axis_inst (
        .s_aclk             (s_clk),
        .m_aclk             (m_clk),

        .s_aresetn          (~arst),

        .s_axis_tready      (s.ready),
        .s_axis_tvalid      (s.valid),
        .s_axis_tdata       (s.data),
        .s_axis_tdest       ('0),
        .s_axis_tkeep       ('1),
        .s_axis_tid         ('0),
        .s_axis_tstrb       ('0),
        .s_axis_tlast       (s.last),
        .s_axis_tuser       ('0),

        .m_axis_tready      (m.ready),
        .m_axis_tvalid      (m.valid),
        .m_axis_tdata       (m.data),
        .m_axis_tdest       (),
        .m_axis_tkeep       (),
        .m_axis_tid         (),
        .m_axis_tstrb       (),
        .m_axis_tlast       (m.last),
        .m_axis_tuser       ()
    );

endmodule