module core #(
    FRAC_WIDTH = 8
)(
    input  logic                 clk,
    input  logic                 rst,

    input  logic [15:0]          max_it,

    output logic                 s_ready,
    input  logic                 s_valid,
    input  logic [2:-FRAC_WIDTH] s_x,
    input  logic [2:-FRAC_WIDTH] s_y,

    input  logic                 m_ready,
    output logic                 m_valid,
    output logic [15:0]          m_it
);

    logic [2:-FRAC_WIDTH] msi_s_a;
    logic [2:-FRAC_WIDTH] msi_s_b;
    logic [2:-FRAC_WIDTH] msi_s_a2;
    logic [2:-FRAC_WIDTH] msi_s_b2;
    logic [2:-FRAC_WIDTH] msi_s_c;
    logic [2:-FRAC_WIDTH] msi_s_d;

    logic [2:-FRAC_WIDTH] msi_m_a;
    logic [2:-FRAC_WIDTH] msi_m_b;
    logic [2:-FRAC_WIDTH] msi_m_a2;
    logic [2:-FRAC_WIDTH] msi_m_b2;
    logic                 msi_m_stop;

    single_iteration #(
        .FRAC_WIDTH (FRAC_WIDTH)
    ) msi (
        .clk    (clk),

        .s_a    (msi_s_a),
        .s_b    (msi_s_b),
        .s_a2   (msi_s_a2),
        .s_b2   (msi_s_b2),
        .s_c    (msi_s_c),
        .s_d    (msi_s_d),

        .m_a    (msi_m_a),
        .m_b    (msi_m_b),
        .m_a2   (msi_m_a2),
        .m_b2   (msi_m_b2),
        .m_stop (msi_m_stop)
    );

    localparam int N = msi.LATENCY;

    // TODO: block ram sentezlenirse calismaz
    (* ram_style = "distributed" *) logic [2:-FRAC_WIDTH] x_mem    [N-1:0];
    (* ram_style = "distributed" *) logic [2:-FRAC_WIDTH] y_mem    [N-1:0];
    (* ram_style = "distributed" *) logic                 done_mem [N-1:0];
    (* ram_style = "distributed" *) logic [15:0]          iter_mem [N-1:0];

    typedef enum {LOAD, CALC, UNLOAD} state_t;
    state_t state;

    localparam PTR_WIDTH = N > 1 ? $clog2(N) : 1;
    logic [PTR_WIDTH-1:0] ptr;
    logic [PTR_WIDTH:0]   active_cnt;
    logic [15:0]          iter_cnt;

    assign msi_s_a  = state == LOAD ? 0 : msi_m_a;
    assign msi_s_b  = state == LOAD ? 0 : msi_m_b;
    assign msi_s_a2 = state == LOAD ? 0 : msi_m_a2;
    assign msi_s_b2 = state == LOAD ? 0 : msi_m_b2;
    assign msi_s_c  = x_mem[ptr];
    assign msi_s_d  = y_mem[ptr];

    assign s_ready     = state == LOAD;

    assign m_valid     = state == UNLOAD;
    assign m_it        = iter_mem[ptr];

    always_ff @(posedge clk) begin

        case (state)
            LOAD: begin
                iter_cnt      <= 1;
                active_cnt    <= N;
                done_mem[ptr] <= 0;

                if (s_valid) begin
                    x_mem   [ptr] <= s_x;
                    y_mem   [ptr] <= s_y;

                    if (ptr == N - 1) begin
                        ptr        <= 0;
                        state      <= CALC;
                    end else begin
                        ptr <= ptr + 1;
                    end
                end
            end

            CALC: begin
                if (ptr == N - 1) begin
                    ptr <= 0;
                    iter_cnt <= iter_cnt + 1;
                end else begin
                    ptr <= ptr + 1;
                end

                if (~done_mem[ptr]) begin
                    if (msi_m_stop || iter_cnt >= max_it) begin
                        iter_mem[ptr] <= iter_cnt;
                        done_mem[ptr] <= 1;
                        active_cnt <= active_cnt - 1;
                    end
                end

                if (active_cnt == 0) begin
                    ptr   <= 0;
                    state <= UNLOAD;
                end
            end

            UNLOAD: begin
                if (m_ready) begin
                    if (ptr == N - 1) begin
                        ptr   <= 0;
                        state <= LOAD;
                    end else begin
                        ptr <= ptr + 1;
                    end
                end
            end

        endcase

        if (rst) begin
            state       <= LOAD;
            ptr         <= 0;
        end
    end


endmodule