// addr[31:16] -> addr[15:0] -> data 0 -> data 1 -> data 2 -> ... -> data N
module mandelbrot_core_wrapper #(
    logic [31:0] START_ADDR,
    int          X_COUNT,
    int          Y_COUNT,
    int          PIXELS_PER_PACKET,
    int          FRAC_WIDTH = 8
)(
    input clk,
    input rst,



    input [15:0] max_it,

    output s_ready,
    input  s_valid,
    input [2:-FRAC_WIDTH] distance,
    input [2:-FRAC_WIDTH]

    output axis_intf m

);

    mandelbrot_core #(
        .FRAC_WIDTH (),
    ) core (
        .clk        (clk),
        .rst        (rst),

        .max_it     (max_it),

        .s_ready    (),
        .s_valid    (),
        .s_x        (),
        .s_y        (),

        .m_ready    (),
        .m_valid    (),
        .m_it       ()
    );

    logic [2:-FRAC_WIDTH] x;
    logic [2:-FRAC_WIDTH] y;

    logic [] x_ctr;
    logic [] y_ctr;


    always_ff @(posedge clk) begin

        if (s_ready | ~s_valid) begin
            if (x_ctr == X_COUNT - 1) begin
                if (y_ctr == Y_COUNT - 1) begin
                end else begin

                end
            end else begin
                x_ctr <= x_ctr + 1;
                x <= x + distance;
            end
        end

        if (rst) begin

        end
    end


endmodule