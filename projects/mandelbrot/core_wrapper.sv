// addr[31:16] -> addr[15:0] -> data 0 -> data 1 -> data 2 -> ... -> data N
module mandelbrot_core_wrapper #(
    logic [31:0] START_ADDR        = 0,
    int          RES_X             = 1920,
    int          RES_Y             = 1,
    int          PIXELS_PER_PACKET = 16,
    int          FRAC_WIDTH        = 8
)(
    input  logic                 clk,
    input  logic                 rst,

    output logic                 s_ready,
    input  logic                 s_valid,
    input  logic [2:-FRAC_WIDTH] s_x,
    input  logic [2:-FRAC_WIDTH] s_y,

    input  logic [2:-FRAC_WIDTH] s_d,
    input  logic [15:0]          s_max_it,

    axis_intf m

);

    logic                 core_s_ready;
    logic [2:-FRAC_WIDTH] core_s_x;
    logic [2:-FRAC_WIDTH] core_s_y;

    mandelbrot_core #(
        .FRAC_WIDTH (),
    ) core (
        .clk        (clk),
        .rst        (rst),

        .max_it     (core_max_it),

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

    typedef enum {} state_t;
    state_t state;

    always_ff @(posedge clk) begin

        if (s_ready | ~s_valid) begin

            if (x_ctr == RES_X - 1) begin
                if (y_ctr == RES_Y - 1) begin
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