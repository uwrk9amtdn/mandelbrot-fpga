module wrapper #(
    int          FRAC_WIDTH    = 8,
    int          NCORES        = 64,
    int          ARBITER_SIZE  = 4,
    int          BURST_SIZE    = 16,
    logic [31:0] FB_START_ADDR = 0
    int          AXI_ID        = 0,
    int          X_RES         = 1920,
    int          Y_RES         = 1080
)(
    input clk,
    input rst,

    output                s_ready,
    input                 s_valid,
    input [15:0]          s_max_it,
    input [2:-FRAC_WIDTH] s_center_x,
    input [2:-FRAC_WIDTH] s_center_y,
    input [2:-FRAC_WIDTH] s_xy_step,

    axi_intf m_axi_mem,
);

    logic signed [2:-FRAC_WIDTH] center_x;
    logic signed [2:-FRAC_WIDTH] center_y;
    logic signed [2:-FRAC_WIDTH] pixel_distance;
    logic [15:0]                 max_it;

    logic                        cmul_s_valid;

    logic signed [2:-FRAC_WIDTH] top_left_x;
    logic signed [2:-FRAC_WIDTH] top_left_y;
    logic                        top_left_x_valid;
    logic                        top_left_y_valid;

    logic                        cmul_x_m_valid;
    logic signed [2:-FRAC_WIDTH] cmul_x_m_data;

    logic                        cmul_y_m_valid;
    logic signed [2:-FRAC_WIDTH] cmul_y_m_data;

    logic                        cmul_core_diff_y_m_valid;
    logic signed [2:-FRAC_WIDTH] cmul_core_diff_y_m_data;

    logic signed [2:-FRAC_WIDTH] core_diff_y;
    logic                        core_diff_y_valid;

    logic signed [2:-FRAC_WIDTH] core_s_x;
    logic signed [2:-FRAC_WIDTH] core_s_y;

    logic [$clog2(NCORES)-1:0] ctr;

    logic [NCORES-1:0] core_s_valid;

    typedef enum {READY, CALC_TOPLEFT, LOAD} state_t;

    state_t state;

    axis_intf #(16) arbiter_tree_master ();

    axis_intf #(16) core_master [NCORES] ();

    axis_rr_arbiter_tree #(NCORES, ARBITER_SIZE) arbiter_tree (clk, rst, core_master, arbiter_tree_master);

    constant_multiplier #(
        .INPUT_WIDTH     (3+FRAC_WIDTH),
        .CONSTANT_WIDTH  ($clog2(X_RES/2)+1),
        .OUTPUT_WIDTH    (3+FRAC_WIDTH),
        .SIGNED          (1),
        .CONSTANT        (X_RES/2),
        .LATENCY         (1)
    ) cmul_x (
        .clk       (clk),
        .rst       (rst),

        .s_valid   (cmul_s_valid),
        .s_data    (pixel_distance),

        .m_valid   (cmul_x_m_valid),
        .m_data    (cmul_x_m_data)
    );

    constant_multiplier #(
        .INPUT_WIDTH     (3+FRAC_WIDTH),
        .CONSTANT_WIDTH  ($clog2(Y_RES/2)+1),
        .OUTPUT_WIDTH    (3+FRAC_WIDTH),
        .SIGNED          (1),
        .CONSTANT        (Y_RES/2),
        .LATENCY         (1)
    ) cmul_y (
        .clk       (clk),
        .rst       (rst),

        .s_valid   (cmul_s_valid),
        .s_data    (pixel_distance),

        .m_valid   (cmul_y_m_valid),
        .m_data    (cmul_y_m_data)
    );

    constant_multiplier #(
        .INPUT_WIDTH     (3+FRAC_WIDTH),
        .CONSTANT_WIDTH  ($clog2(Y_RES/NCORES)+1),
        .OUTPUT_WIDTH    (3+FRAC_WIDTH),
        .SIGNED          (1),
        .CONSTANT        (Y_RES/NCORES),
        .LATENCY         (1)
    ) cmul_core_diff_y (
        .clk       (clk),
        .rst       (rst),

        .s_valid   (cmul_s_valid),
        .s_data    (pixel_distance),

        .m_valid   (cmul_core_diff_y_m_valid),
        .m_data    (cmul_core_diff_y_m_data)
    );

    for (genvar i = 0; i < N; i++) begin : core_gen

        localparam START_ADDR = FB_START_ADDR + (X_RES * Y_RES * 2 * i / NCORES);

        core_wrapper #(
            .START_ADDR  (START_ADDR),
            .X_RES       (X_RES),
            .Y_RES       (Y_RES/NCORES),
            .N           (BURST_SIZE),
            .FRAC_WIDTH  (FRAC_WIDTH)
        ) core (
            .clk       (clk),
            .rst       (rst),

            .s_ready   (core_s_ready[i]),
            .s_valid   (core_s_valid[i]),
            .s_x_start (core_s_x),
            .s_y_start (core_s_y),

            .s_xy_step (core_s_xy_step),
            .s_max_it  (core_s_max_it),

            .m         (core_m)
        );

    end

    memory_writer #(
        .BURST_SIZE (BURST_SIZE),
        .AXI_ID     (AXI_ID)
    ) memw (
        .clk    (clk),
        .rst    (rst),
        .s_axis (arbiter_tree_master),
        .m_axi  (m_axi_mem)
    );

    assign s_ready = state == READY;

    always_ff @(posedge clk) begin

        cmul_s_valid <= 0;

        case (state)

            READY: begin
                if (s_ready & s_valid) begin
                    center_x         <= s_center_x;
                    center_y         <= s_center_y;
                    pixel_distance   <= s_xy_step;
                    max_it           <= s_max_it;

                    cmul_s_valid     <= 1;

                    top_left_x_valid <= 0;
                    top_left_y_valid <= 0;

                    state            <= CALC_TOPLEFT;
                end
            end

            PREPARE: begin

                if (cmul_x_m_valid) begin
                    top_left_x       <= center_x - cmul_x_m_data;
                    top_left_x_valid <= 1;
                end

                if (cmul_y_m_valid) begin
                    top_left_y       <= center_y + cmul_y_m_data;
                    top_left_y_valid <= 1;
                end

                if (cmul_core_diff_y_m_valid) begin
                    core_diff_y       <= cmul_core_diff_y_m_data;
                    core_diff_y_valid <= 1;
                end

                if (top_left_x_valid & top_left_y_valid & core_diff_y_valid) begin
                    core_s_valid[0] <= 1;
                    ctr             <= 0;
                    core_s_x        <= top_left_x;
                    core_s_y        <= top_left_y;
                    core_diff_y     <= cmul_core_diff_y_m_data;
                end

            end

            LOAD: begin
                if (core_s_ready[ctr]) begin

                    core_s_y <= core_s_y - core_diff_y;

                    core_s_valid <= core_s_valid << 1;

                    if (ctr == NCORES - 1) begin
                        ctr <= 0;
                        state <= READY;
                    end else begin
                        ctr <= ctr + 1;
                    end
                end
            end

        endcase

        if (rst) begin
            cmul_s_valid <= 0;
        end

    end

endmodule