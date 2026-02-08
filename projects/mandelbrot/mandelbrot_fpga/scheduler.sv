module scheduler #(
    parameter N              = 16,
    parameter ID_WIDTH       = 16,
    parameter FRACTION_WIDTH = 16
)(
    input                          clk,
    input                          rst,

    output reg                     m_ready,
    input                          m_valid,
    input      [2:-FRACTION_WIDTH] m_x,
    input      [2:-FRACTION_WIDTH] m_y,
    input      [ID_WIDTH-1:0]      m_id,

    input      [N-1:0]             s_ready,
    output reg [N-1:0]             s_valid,
    output reg [2:-FRACTION_WIDTH] s_x,
    output reg [2:-FRACTION_WIDTH] s_y,
    output reg [ID_WIDTH-1:0]      s_id
);

    always @* begin
        s_x  = m_x;
        s_y  = m_y;
        s_id = m_id;

        m_ready = |s_ready;
        s_valid = 0;
        for(int i = 0; i < N; i++) begin
            if (s_ready[i]) begin
                s_valid[i] = m_valid;
                break;
            end
        end
    end

endmodule
