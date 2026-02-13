// addr[31:16] -> addr[15:0] -> data 0 -> data 1 -> data 2 -> ... -> data N
module core_wrapper #(
    logic [31:0] START_ADDR  = 0,
    int          X_RES       = 1920,
    int          Y_RES       = 1080,
    int          N           = 16,
    int          FRAC_WIDTH  = 8
)(
    input  logic                 clk,
    input  logic                 rst,

    output logic                 s_ready,
    input  logic                 s_valid,
    input  logic [2:-FRAC_WIDTH] s_x_start,
    input  logic [2:-FRAC_WIDTH] s_y_start,

    input  logic [2:-FRAC_WIDTH] s_xy_step,
    input  logic [15:0]          s_max_it,

    axis_intf m
);

    if ((X_RES * Y_RES) % N != 0) begin
        $error();
    end

    logic                        core_s_ready;
    logic                        core_s_valid;
    logic signed [2:-FRAC_WIDTH] core_s_x;
    logic signed [2:-FRAC_WIDTH] core_s_y;

    logic                        core_m_ready;
    logic                        core_m_valid;
    logic [15:0]                 core_m_it;

    logic signed [2:-FRAC_WIDTH] x_start_reg;
    logic signed [2:-FRAC_WIDTH] xy_step_reg;
    logic [15:0]                 max_it_reg;

    logic signed [2:-FRAC_WIDTH] x;
    logic signed [2:-FRAC_WIDTH] y;

    core #(
        .FRAC_WIDTH (FRAC_WIDTH)
    ) core (
        .clk        (clk),
        .rst        (rst),

        .max_it     (max_it_reg),

        .s_ready    (core_s_ready),
        .s_valid    (core_s_valid),
        .s_x_start  (core_s_x),
        .s_y_start  (core_s_y),

        .m_ready    (core_m_ready),
        .m_valid    (core_m_valid),
        .m_it       (core_m_it)
    );

    if (N % core.N != 0) begin
        $error();
    end

    logic [$clog2(X_RES)-1:0] x_ctr;
    logic [$clog2(Y_RES)-1:0] y_ctr;

    typedef enum {READY, CALC} sstate_t;
    sstate_t sstate;

    assign s_ready = sstate == READY;

    always_ff @(posedge clk) begin

        if (core_s_ready) begin
            core_s_valid <= 0;
        end

        case (sstate)
            READY: begin
                if (s_ready & s_valid) begin
                    x_start_reg <= s_x_start;
                    x           <= s_x_start;
                    y           <= s_y_start;
                    max_it_reg  <= s_max_it;
                    xy_step_reg <= s_xy_step;
                    x_ctr       <= 0;
                    y_ctr       <= 0;
                    sstate      <= CALC;
                end
            end

            CALC: begin
                if (core_s_ready | ~core_s_valid) begin
                    core_s_valid <= 1;
                    core_s_x     <= x;
                    core_s_y     <= y;
                    if (x_ctr == X_RES - 1) begin
                        x_ctr    <= 0;
                        x        <= x_start_reg;
                        y        <= y - xy_step_reg;
                        if (y_ctr == Y_RES - 1) begin
                            y_ctr  <= 0;
                            sstate <= READY;
                        end else begin
                            y_ctr <= y_ctr + 1;
                        end
                    end else begin
                        x_ctr <= x_ctr + 1;
                        x     <= x + xy_step_reg;
                    end
                end
            end
        endcase

        if (rst) begin
            core_s_valid <= 0;
            sstate       <= READY;
        end
    end

    //////////////////

    logic [$clog2(N)-1:0] ptr;

    (* ram_style = "distributed" *) logic [15:0] data [N];

    logic [31:0] addr;

    typedef enum {LOAD, ADDR1, ADDR2, UNLOAD} mstate_t;
    mstate_t mstate;

    assign core_m_ready = mstate == LOAD;

    always_ff @(posedge clk) begin

        if (m.ready) begin
            m.valid <= 0;
        end

        case (mstate)
            LOAD: begin
                if (core_m_ready & core_m_valid) begin
                    data[ptr] <= core_m_it;
                    if (ptr == N - 1) begin
                        ptr    <= 0;
                        mstate <= ADDR1;
                    end else begin
                        ptr <= ptr + 1;
                    end
                end
            end
            ADDR1: begin
                if (m.ready | ~m.valid) begin
                    m.valid  <= 1;
                    m.data   <= addr[31:16];
                    m.last   <= 0;
                    mstate   <= ADDR2;
                end
            end
            ADDR2: begin
                if (m.ready | ~m.valid) begin
                    m.valid <= 1;
                    m.data  <= addr[15:0];
                    m.last  <= 0;
                    mstate  <= UNLOAD;
                    addr    <= addr + (N * 2);
                end
            end
            UNLOAD: begin
                if (m.ready | ~m.valid) begin
                    m.valid <= 1;
                    m.data  <= data[ptr];
                    if (ptr == N - 1) begin
                        m.last <= 1;
                        mstate <= LOAD;
                        ptr    <= 0;
                    end else begin
                        m.last  <= 0;
                        ptr <= ptr + 1;
                    end
                end
            end
        endcase

        if (rst) begin
            ptr     <= 0;
            addr    <= START_ADDR;
            mstate  <= LOAD;
            m.valid <= 0;
        end

    end


endmodule