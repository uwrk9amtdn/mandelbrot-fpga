module mandelbrot_wrapper #(
    int          FRAC_WIDTH    = 8,
    int          NCORES        = 64,
    int          ARBITER_SIZE  = 4,
    logic [31:0] FB_START_ADDR = 0
)(
    input clk,
    input rst,

    output                s_ready,
    input                 s_valid,
    input [15:0]          s_max_it,
    input [2:-FRAC_WIDTH] s_center_x,
    input [2:-FRAC_WIDTH] s_center_y,
    input [2:-FRAC_WIDTH] s_diff,

    axi_intf mem,
);

    axis_intf #(16) arbiter_tree_master ();

    axis_intf #(16) core_master [NCORES] ();

    axis_rr_arbiter_tree #(NCORES, ARBITER_SIZE) arbiter_tree (clk, rst, core_master, arbiter_tree_master)

    axis_width_converter wc(clk, rst, );

    for (genvar i = 0; i < N; i++) begin

        mandelbrot_core_wrapper core #()();

    end

    always @(posedge clk) begin

    end


endmodule