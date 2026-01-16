module core #(
    parameter N = 8
)(
    input         clk,
    input         rst,
    input  [1:-N] cx,
    input  [1:-N] cy,
    input  [15:0] max_iteration,
    input         s_valid,
    output        s_ready,

    output        m_valid,
    output [15:0] count
);

    // z_(n+1) = (z_n)^2 + c
    // z_n = x + y*i
    // (z_n)^2 = x*x - y*y + 2*x*y*i
    // c = a + b*i
    // z_(n+1) = (x*x - y*y + a) + i*(2*x*y + b)
    // norm(z_n)^2 = x*x + y*y

    reg [2:-N] x_;
    reg [2:-N] y_;

    reg [15:0] c;

    typedef enum { READY, BUSY } state_t;

    state_t state;

    assign s_ready = state == READY;

    always @(posedge clk) begin

        if (rst) begin
        end

        else begin
            case (state)

                READY: begin
                    if (s_valid) begin
                        c     <= 0;
                        state <= BUSY;
                    end
                end

                BUSY: begin
                    c <= c + 1;
                end
            endcase
        end
    end

endmodule