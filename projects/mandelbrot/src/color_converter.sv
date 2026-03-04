module color_converter(
    input         clk,
    input         rst,

    input [3:0]   start_index,

    axis_intf     s_axis_it,

    axis_intf     m_axis_rgb
);

    if (s_axis_it.DATA_WIDTH != 16 || m_axis_rgb.DATA_WIDTH != 24) begin
        $error();
    end

    if (s_axis_it.LAST_EN != 0 || m_axis_rgb.LAST_EN != 0) begin
        $error();
    end

    assign s_axis_it.ready = m_axis_rgb.ready;

    always_ff @(posedge clk) begin
        m_axis_rgb.valid <= s_axis_it.valid;
        m_axis_rgb.data  <= {8'h00, 8'h00, s_axis_it.data[start_index+:8]};
        if (rst) begin
            m_axis_rgb.valid <= 0;
        end
    end
endmodule