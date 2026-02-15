module core_wrapper_tb;
    logic        clk;
    logic        rst;

    logic        s_ready;
    logic        s_valid;
    logic [2:-8] s_x_start;
    logic [2:-8] s_y_start;
    logic [2:-8] s_xy_step;
    logic [15:0] s_max_it;

    axis_intf #(16, 1) m ();

    core_wrapper #(
        .START_ADDR (0),
        .X_RES      (1920),
        .Y_RES      (1080),
        .N          (16),
        .FRAC_WIDTH (8)
    ) cw (
        .clk       (clk),
        .rst       (rst),

        .s_ready   (s_ready),
        .s_valid   (s_valid),
        .s_x_start (s_x_start),
        .s_y_start (s_y_start),

        .s_xy_step (s_xy_step),
        .s_max_it  (s_max_it),

        .m         (m)
    );

    initial begin
        clk       = 0;
        rst       = 1;
        s_valid   = 0;
        s_x_start = 0;
        s_y_start = 0;
        s_xy_step = 0;
        s_max_it  = 0;
        m.ready   = 1;

        fork
            forever begin
                #5 clk <= ~clk;
            end
            begin
                #100;
                rst <= 0;
                @(posedge clk);
                s_valid <= 1;
                @(posedge clk iff s_ready & s_valid);
                s_valid <= 0;
                #1us;
            end
        join_any
        $finish;
    end

endmodule