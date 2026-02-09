module scheduler #(
    parameter N = 16,
    parameter SX = 1024,
    parameter SY = 1024,
    parameter S = $clog2(SX*SY)
)(
    input          clk,
    input          rst,

    output         m_ready,
    input          m_valid,
    input  [ 31:0] m_x,
    input  [ 31:0] m_y,
    input  [ 23:0] m_d,

    input  [N-1:0] s_ready,
    output [N-1:0] s_valid,
    output [ 31:0] s_x,
    output [ 31:0] s_y,
    output [S-1:0] s_id
);

    typedef enum {READY, BUSY} state_t;
    state_t state;

    reg [S-1:0] id_counter;
    reg [$clog2(SX)-1:0] x_counter;
    reg [$clog2(SY)-1:0] y_counter;
    reg [31:0] x;
    reg [31:0] y;

    always @* begin
        if (state == READY) begin
        end
        else begin
            for (int i = 0; i < N; i++) begin

            end
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            state <= READY;
        end
        else begin
            case (state)
                READY: begin
                    if (m_ready & m_valid) begin
                        state <= BUSY;
                        id_counter <= 0;
                        x_counter <= 0;
                        y_counter <= 0;
                        x <= m_x;
                        y <= m_y;
                    end
                end

                BUSY: begin
                    automatic bit t = 0;
                    s_valid <= '{default:0};
                    for (int i = 0; i < N; i++) begin
                        if (s_ready[i]) s_valid[i] = 1;
                        t = 1;
                        break;
                    end
                    if (t) begin
                        x_counter <= x_counter + 1;
                        y_counter <= y_counter + 1;
                        if (x_counter == SX-1) begin
                            x_counter <= 0;
                            y_counter <= y_counter + 1;
                        end
                    end
                end

                default:; //
            endcase
        end
    end

endmodule