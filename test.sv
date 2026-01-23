module a(
    input clk,

    input         s_valid,
    input  [15:0] s_data,

    output        m_valid,
    output [15:0] m_data,
    output        m_finish
);

endmodule

module b(
    output        s_ready,
    input         s_valid,
    input  [15:0] s_data,

    input         m_ready,
    output        m_valid,
    output [15:0] m_data,
);

    a a1(a_s_valid, a_s_data, a_m_valid, a_m_data, a_m_finish);

    logic [15:0] count [3:0];

    always @(posedge clk) begin

        case (state)
            READY: begin

            end

            WAIT_FINISH: begin
                if (&finish_reg) begin
                    finish_reg <= 0;
                    state      <= READY;
                end
            end
        endcase

        if (count[3]) begin

        end

    end




endmodule