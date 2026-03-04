module wrapper_tb;

    logic clk;
    logic rst;

    logic        s_ready;
    logic        s_valid;
    logic [15:0] s_max_it;
    logic [2:-8] s_center_x;
    logic [2:-8] s_center_y;
    logic [2:-8] s_xy_step;

    axis_intf #(32, 0) m_addr ();
    axis_intf #(64, 1) m_data ();

    wrapper #(
       .X_RES             (1920),
       .Y_RES             (1080),
       .FRAC_WIDTH        (8),
       .NCORES            (4),
       .ARBITER_TREE_SANS (4),
       .BURST_LENGTH      (16),
       .FB_START_ADDR     (0)
    ) wrapper (
        .clk        (clk),
        .rst        (rst),

        .s_ready    (s_ready),
        .s_valid    (s_valid),
        .s_max_it   (s_max_it),
        .s_center_x (s_center_x),
        .s_center_y (s_center_y),
        .s_xy_step  (s_xy_step),

        .m_addr     (m_addr),
        .m_data     (m_data)
    );

    initial begin
        rst          = 1;
        clk          = 0;
        s_valid      = 0;
        s_max_it     = 0;
        s_center_x   = 0;
        s_center_y   = 0;
        s_xy_step    = 0;
        m_addr.ready = 1;
        m_data.ready = 1;

        fork
            forever begin
                #5 clk <= ~clk;
            end
            begin
                #20 rst <= 0;
                #1000;
                @(posedge clk);
                s_valid <= 1;
                @(posedge clk iff s_ready & s_valid);
                s_valid <= 0;
                #1ms;
            end
        join_any
    end


endmodule