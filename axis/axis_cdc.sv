module axis_cdc #(
    int SYNC_STAGES = 4
)(
    input     s_clk,
    input     m_clk,
    axis_intf s,
    axis_int  m
);

    if (s.DATA_WIDTH != m.DATA_WIDTH || s.LAST_EN != 0 || m.LAST_EN != 0) begin
        $error();
    end

    // TODO

endmodule