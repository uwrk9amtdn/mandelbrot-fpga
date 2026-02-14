module wrapper #(
    int          X_RES             = 1920,
    int          Y_RES             = 1080,
    int          FRAC_WIDTH        = 8,
    int          NCORES            = 54,
    int          ARBITER_TREE_SANS = 4,
    int          BURST_LENGTH      = 16,
    logic [31:0] FB_START_ADDR     = 0
)(
    input  logic clk,
    input  logic rst,

    output logic                 s_ready,
    input  logic                 s_valid,
    input  logic [15:0]          s_max_it,
    input  logic [2:-FRAC_WIDTH] s_center_x,
    input  logic [2:-FRAC_WIDTH] s_center_y,
    input  logic [2:-FRAC_WIDTH] s_xy_step,

    axis_intf m_addr,
    axis_intf m_data
);

    if (Y_RES % NCORES != 0) begin
        $error(); // TODO
    end

    if (m_addr.DATA_WIDTH != 32 || m_addr.LAST_EN != 0) begin
        $error();
    end

    if (m_data.DATA_WIDTH / 16 > BURST_LENGTH || BURST_LENGTH % (m_data.DATA_WIDTH / 16) != 0) begin
        $error();
    end

    if (m_data.LAST_EN != 1) begin
        $error();
    end

    axis_intf #(16, 1) at_m ();

    begin : slave_block
        logic signed [2:-FRAC_WIDTH] center_x;
        logic signed [2:-FRAC_WIDTH] center_y;
        logic signed [2:-FRAC_WIDTH] xy_step;
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

        logic                        cmul_core_y_step_m_valid;
        logic signed [2:-FRAC_WIDTH] cmul_core_y_step_m_data;

        logic signed [2:-FRAC_WIDTH] core_y_step;
        logic                        core_y_step_valid;

        logic signed [2:-FRAC_WIDTH] core_s_x;
        logic signed [2:-FRAC_WIDTH] core_s_y;

        logic [$clog2(NCORES)-1:0] ctr;

        logic [NCORES-1:0] core_s_valid;

        logic [NCORES-1:0] core_s_ready;

        typedef enum {READY, PREPARE, DISPATCH} state_t;

        state_t state;

        axis_intf #(16, 1) core_m [NCORES] ();

        axis_rr_arbiter_tree #(NCORES, ARBITER_TREE_SANS) at (clk, rst, core_m, at_m);

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
            .s_data    (xy_step),

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
            .s_data    (xy_step),

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
        ) cmul_core_y_step (
            .clk       (clk),
            .rst       (rst),

            .s_valid   (cmul_s_valid),
            .s_data    (xy_step),

            .m_valid   (cmul_core_y_step_m_valid),
            .m_data    (cmul_core_y_step_m_data)
        );

        for (genvar i = 0; i < NCORES; i++) begin : core_gen

            localparam START_ADDR = FB_START_ADDR + (longint'(X_RES) * Y_RES * 2 * i / NCORES);

            core_wrapper #(
                .START_ADDR  (START_ADDR),
                .X_RES       (X_RES),
                .Y_RES       (Y_RES/NCORES),
                .N           (BURST_LENGTH),
                .FRAC_WIDTH  (FRAC_WIDTH)
            ) core (
                .clk       (clk),
                .rst       (rst),

                .s_ready   (core_s_ready[i]),
                .s_valid   (core_s_valid[i]),
                .s_x_start (core_s_x),
                .s_y_start (core_s_y),

                .s_xy_step (xy_step),
                .s_max_it  (max_it),

                .m         (core_m[i])
            );

        end

        assign s_ready = state == READY;

        always_ff @(posedge clk) begin

            cmul_s_valid <= 0;

            case (state)

                READY: begin
                    if (s_ready & s_valid) begin
                        center_x          <= s_center_x;
                        center_y          <= s_center_y;
                        xy_step           <= s_xy_step;
                        max_it            <= s_max_it;

                        cmul_s_valid      <= 1;

                        top_left_x_valid  <= 0;
                        top_left_y_valid  <= 0;
                        core_y_step_valid <= 0;

                        state             <= PREPARE;
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

                    if (cmul_core_y_step_m_valid) begin
                        core_y_step       <= cmul_core_y_step_m_data;
                        core_y_step_valid <= 1;
                    end

                    if (top_left_x_valid & top_left_y_valid & core_y_step_valid) begin
                        state           <= DISPATCH;
                        core_s_valid[0] <= 1;
                        ctr             <= 0;
                        core_s_x        <= top_left_x;
                        core_s_y        <= top_left_y;
                    end

                end

                DISPATCH: begin
                    if (core_s_ready[ctr]) begin

                        core_s_y <= core_s_y - core_y_step;

                        core_s_valid <= core_s_valid << 1;

                        if (ctr == NCORES - 1) begin
                            ctr   <= 0;
                            state <= READY;
                        end else begin
                            ctr <= ctr + 1;
                        end
                    end
                end

            endcase

            if (rst) begin
                cmul_s_valid <= 0;
                core_s_valid <= 0;
                state        <= READY;
            end

        end
    end

    begin : master_block

        axis_intf #(16, 1) wc_s ();

        axis_wc wc (
            .clk (clk),
            .rst (rst),

            .s (wc_s),
            .m (m_data)
        );

        typedef enum {ADDR1, ADDR2, DATA} state_t;

        state_t state;

        always_comb begin
            wc_s.valid = 0;
            wc_s.data  = at_m.data;
            wc_s.last  = at_m.last;
            at_m.ready = 0;

            case (state)
                ADDR1: begin
                    at_m.ready = m_addr.ready | ~m_addr.valid;
                end
                ADDR2: begin
                    at_m.ready = m_addr.ready | ~m_addr.valid;
                end
                DATA: begin
                    wc_s.valid = at_m.valid;
                    at_m.ready = wc_s.ready;
                end
            endcase
        end

        always_ff @(posedge clk) begin

            if (m_addr.ready) begin
                m_addr.valid <= 0;
            end

            case (state)
                ADDR1: begin
                    if (at_m.ready & at_m.valid) begin
                        m_addr.valid <= 0;
                        m_addr.data  <= {m_addr.data[15:0], at_m.data};
                    end
                end

                ADDR2: begin
                    if (at_m.ready & at_m.valid) begin
                        m_addr.valid <= 1;
                        m_addr.data  <= {m_addr.data[15:0], at_m.data};
                    end
                end

                DATA: begin
                    if (at_m.ready & at_m.valid & at_m.last) begin
                        state <= ADDR1;
                    end
                end
            endcase

            if (rst) begin
                m_addr.valid <= 0;
                state        <= ADDR1;
            end
        end
    end

endmodule