module axis_wc (
    input clk,
    input rst,

    axis_intf s,
    axis_intf m
);

    // TODO: add keep support

    if (s.DATA_WIDTH > m.DATA_WIDTH && s.DATA_WIDTH % m.DATA_WIDTH != 0) begin
        $error();
    end

    if (m.DATA_WIDTH > s.DATA_WIDTH && m.DATA_WIDTH % s.DATA_WIDTH != 0) begin
        $error();
    end

    if (s.LAST_EN != 1 || m.LAST_EN != 1) begin
        $error();
    end

    axis_adapter #(
        .S_DATA_WIDTH  (s.DATA_WIDTH),
        .S_KEEP_ENABLE (1),
        .M_DATA_WIDTH  (m.DATA_WIDTH),
        .M_KEEP_ENABLE (1),
        .ID_ENABLE     (0),
        .DEST_ENABLE   (0),
        .USER_ENABLE   (0)
    ) adapter (
        .clk            (clk),
        .rst            (rst),

        .s_axis_tdata   (s.data),
        .s_axis_tkeep   ('1),
        .s_axis_tvalid  (s.valid),
        .s_axis_tready  (s.ready),
        .s_axis_tlast   (s.last),

        .m_axis_tdata   (m.data),
        .m_axis_tkeep   (),
        .m_axis_tvalid  (m.valid),
        .m_axis_tready  (m.ready),
        .m_axis_tlast   (m.last)
    );

endmodule