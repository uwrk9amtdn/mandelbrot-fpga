module mandelbrot_wrapper #(
    FRAC_WIDTH = 8
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

    axis_intf #(16) root_arbiter_master ();

    axis_width_converter wc(clk, rst, );

    generate
        for (genvar i = 0; i < N; i++) begin : core_gen

            mandelbrot_core_wrapper core #()();

        end
        for (genvar i = 0; i < N / 4; i++) begin

            axis_rr_arbiter #(4) arbiter (clk, rst, );
            axis_skid_buffer sb (clk, rst, )
        end
    endgenerate

    always @(posedge clk) begin

    end


endmodule