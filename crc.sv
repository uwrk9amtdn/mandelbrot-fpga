module crc #(
) (
    input clk,
    input rst,

    output        s_axis_ready,
    input         s_axis_valid,
    input  [31:0] s_axis_data,
    input         s_axis_last,

    output        m_axis_valid,
    output [15:0] m_axis_data
);

endmodule