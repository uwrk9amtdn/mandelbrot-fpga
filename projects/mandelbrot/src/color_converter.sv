module color_converter(
    input        clk,
    input        rst,

    input [3:0]  start_index,
    input        two_color,

    input [23:0] color_0,
    input [23:0] color_1,
    input [23:0] color_2,
    input [23:0] color_3,

    axis_intf    s_axis_it,

    axis_intf    m_axis_rgb
);

    if (s_axis_it.DATA_WIDTH != 16 || m_axis_rgb.DATA_WIDTH != 24) begin
        $error();
    end

    if (s_axis_it.LAST_EN != 0 || m_axis_rgb.LAST_EN != 0) begin
        $error();
    end

    logic [23:0] colors [4];
    assign colors = '{color_0, color_1, color_2, color_3};

    logic [1:0] color_index;
    logic [1:0] color_index_a;
    logic [1:0] color_index_b;

    logic [23:0] a;
    logic [23:0] b;
    logic [7:0]  alpha;

    logic li_s_valid;
    logic li_s_ready;

    linear_interpolator #(
        .SIGNED    (0),
        .WIDTH     (8),
        .PRECISION (8)
    ) li_b (
        .clk         (clk),
        .rst         (rst),

        .s_ready     (li_s_ready),
        .s_valid     (li_s_valid),
        .s_a         (a[0+:8]),
        .s_b         (b[0+:8]),
        .s_alpha     (alpha),

        .m_ready     (m_axis_rgb.ready),
        .m_valid     (m_axis_rgb.valid),
        .m_q         (m_axis_rgb.data[0+:8])
    );

    linear_interpolator #(
        .SIGNED    (0),
        .WIDTH     (8),
        .PRECISION (8)
    ) li_g (
        .clk         (clk),
        .rst         (rst),

        .s_ready     (),
        .s_valid     (li_s_valid),
        .s_a         (a[8+:8]),
        .s_b         (b[8+:8]),
        .s_alpha     (alpha),

        .m_ready     (m_axis_rgb.ready),
        .m_valid     (),
        .m_q         (m_axis_rgb.data[8+:8])
    );

    linear_interpolator #(
        .SIGNED    (0),
        .WIDTH     (8),
        .PRECISION (8)
    ) li_r (
        .clk         (clk),
        .rst         (rst),

        .s_ready     (),
        .s_valid     (li_s_valid),
        .s_a         (a[16+:8]),
        .s_b         (b[16+:8]),
        .s_alpha     (alpha),

        .m_ready     (m_axis_rgb.ready),
        .m_valid     (),
        .m_q         (m_axis_rgb.data[16+:8])
    );

    assign s_axis_it.ready = li_s_ready | ~li_s_valid;

    logic [25:0] it_zero_padded;
    assign it_zero_padded = {2'd0, s_axis_it.data, 8'd0};

    logic       s_valid_reg [2];
    logic [7:0] alpha_reg   [2];

    always_ff @(posedge clk) begin

        if (li_s_ready | ~li_s_valid) begin
            color_index   <= it_zero_padded[start_index+8+:2];
            color_index_a <= (two_color ? 2'b01 : 2'b11) & (color_index);
            color_index_b <= (two_color ? 2'b01 : 2'b11) & (color_index + 1);
            a             <= colors[color_index_a];
            b             <= colors[color_index_b];

            alpha_reg[0] <= it_zero_padded[start_index+:8];
            alpha_reg[1] <= alpha_reg[0];
            alpha        <= alpha_reg[1];

            s_valid_reg[0] <= s_axis_it.valid;
            s_valid_reg[1] <= s_valid_reg[0];
            li_s_valid     <= s_valid_reg[1];
        end

        if (rst) begin
            li_s_valid     <= 0;
            s_valid_reg[0] <= 0;
            s_valid_reg[1] <= 0;
        end
    end
endmodule