module mandelbrot_core #(
    parameter FRACTION_WIDTH = 8;
    parameter ID_WIDTH       = 16;
)(
    input clk,

    output                    s_ready,
    input                     s_valid,
    input [1:-FRACTION_WIDTH] s_x,
    input [1:-FRACTION_WIDTH] s_y,
    input [15:0]              s_max_it,
    input [ID_WIDTH-1:0]      s_id,

    input                     m_ready,
    output                    m_valid,
    output [15:0]             m_it,
    output [ID_WIDTH-1:0]     m_id
);

// for i : 1 to max_it

    // z = z^2 + c
    // zx = zx * zx - zy * zy + cx
    // zy = 2 * zx * zy + cy;


    always_ff @(posedge clk) begin
        case (state);
            IDLE: begin
            end


        endcase
    end


endmodule