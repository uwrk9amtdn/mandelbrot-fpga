module mandelbrot_core #(
    FRAC_WIDTH = 8
)(
    input clk,
    input rst,

    input  [15:0]          max_it,

    output                 s_ready,
    input                  s_valid,
    input  [2:-FRAC_WIDTH] s_x,
    input  [2:-FRAC_WIDTH] s_y,

    input                  m_ready,
    output                 m_valid,
    output [15:0]          m_it
);

    mandelbrot_single_iteration #(
        .FRAC_BITS       (),
        .MUL_LATENCY     (),
        .ADD_SUB_LATENCY ()
    ) single_iteration (
        .clk     (),

        .s_a     (),
        .s_b     (),
        .s_a2    (),
        .s_b2    (),
        .s_c     (),
        .s_d     (),

        .m_a     (),
        .m_b     (),
        .m_a2    (),
        .m_b2    (),
        .m_stop  ()
    );

    localparam N = single_iteration.LATENCY;

    logic [$clog2(N)-1:0] ctr;

    logic [1:0][2:-FRAC_BITS] input_reg [N-1:0];

    always_ff @(posedge clk) begin
        case (state);
            COLLECT_INPUT: begin
                if (s_valid) begin
                    input_reg[ctr] <= s_
                    if (ctr == N - 1) begin
                        ctr <= 0;
                    end else begin
                        ctr <= ctr + 1;
                    end
                end
            end
            BUSY: begin
            end

        endcase
    end


endmodule