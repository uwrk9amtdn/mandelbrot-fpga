module axis_width_converter #(
    S_DATA_WIDTH = 8,
    M_DATA_WIDTH = 32,
)(
    input clk,
    input rst,

    output                    s_ready,
    input                     s_valid,
    input  [S_DATA_WIDTH-1:0] s_data,

    input                     m_ready,
    output                    m_valid,
    output [M_DATA_WIDTH-1:0] m_data,
);

    localparam N = M_DATA_WIDTH / S_DATA_WIDTH;



endmodule