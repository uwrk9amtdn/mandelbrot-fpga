module mandelbrot_asic #(
    parameter int          X_RES             = 2048,
    parameter int          Y_RES             = 2048,
    parameter int          FRAC_WIDTH        = 16,
    parameter int          NCORES            = 4,   // Y_RES % NCORES must be 0
    parameter int          ARBITER_TREE_SANS = 4,
    parameter int          BURST_LENGTH      = 16,
    parameter logic [31:0] FB_START_ADDR     = 0
)(
    input  logic                 clk,
    input  logic                 rst,

    output logic                 s_ready,
    input  logic                 s_valid,
    input  logic [15:0]          s_max_it,
    input  logic [2:-FRAC_WIDTH] s_center_x,
    input  logic [2:-FRAC_WIDTH] s_center_y,
    input  logic [2:-FRAC_WIDTH] s_xy_step,

    input  logic                 m_addr_ready,
    output logic                 m_addr_valid,
    output logic [31:0]          m_addr_data,

    input  logic                 m_data_ready,
    output logic                 m_data_valid,
    output logic [15:0]          m_data_data,
    output logic                 m_data_last
);

    axis_intf #(32, 0) m_addr ();
    axis_intf #(16, 1) m_data ();

    assign m_addr_valid = m_addr.valid;
    assign m_addr_data  = m_addr.data;
    assign m_addr.ready = m_addr_ready;

    assign m_data.ready = m_data_ready;
    assign m_data_valid = m_data.valid;
    assign m_data_data  = m_data.data;
    assign m_data_last  = m_data.last;

    wrapper #(
        .X_RES             (X_RES),
        .Y_RES             (Y_RES),
        .FRAC_WIDTH        (FRAC_WIDTH),
        .NCORES            (NCORES),
        .ARBITER_TREE_SANS (ARBITER_TREE_SANS),
        .BURST_LENGTH      (BURST_LENGTH),
        .FB_START_ADDR     (FB_START_ADDR)
    ) u_wrapper (
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

endmodule
