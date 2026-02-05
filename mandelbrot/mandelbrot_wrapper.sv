module mandelbrot_wrapper #(
    int FRAC_WIDTH = 8
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

    localparam int NUMBER_OF_CORES = 64;
    localparam int ARBITER_SLAVE_COUNT = 4;

    localparam logic [31:0] FRAMEBUFFER_START_ADDR = 0;

    axis_intf #(16) arbiter_tree_master ();

    axis_width_converter wc(clk, rst, );


    axis_intf #(16) core_master [NUMBER_OF_CORES] ();

    axis_rr_arbiter_tree #(NUMBER_OF_CORES, ARBITER_SLAVE_COUNT) arbiter_tree (clk, rst, core_master, arbiter_tree_master)

    for (genvar i = 0; i < N; i++) begin

        mandelbrot_core_wrapper core #()();

    end

    always @(posedge clk) begin

    end


endmodule