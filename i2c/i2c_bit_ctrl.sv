module i2c_bit_ctrl #(
    CLK_FREQ = 100.0e6,
    SCL_FREQ = 400.0e3
)(
    input       clk,
    input       rst,

    output reg  op_ready,
    input       op_valid,
    input [1:0] op_mode, // 0:start, 1:read, 2:write, 3:stop
    input       op_wdata,

    output reg  rdata,
    output reg  rdata_valid = 0,

    input       sda_i,
    output reg  sda_o = 1,

    input       scl_i,
    output reg  scl_o = 1
);
    // verilator lint_off WIDTHEXPAND
    // verilator lint_off WIDTHTRUNC

    localparam TICK_COUNT = int'($ceil(CLK_FREQ / (SCL_FREQ * 4.0)));

    typedef enum { IDLE, START, READ, WRITE, STOP } state_t;
    state_t state = IDLE;

    assign op_ready = state == IDLE;

    reg [$clog2(TICK_COUNT) - 1:0] tick_counter = 0;

    reg wdata;

    reg [1:0] i = 0;

    wire tick;
    assign tick = tick_counter == 0;

    always @(posedge clk) begin
        tick_counter <= tick ? TICK_COUNT - 1 : tick_counter - 1;
        rdata_valid  <= 0;
        case (state)
            IDLE: begin
                if (op_ready & op_valid) begin
                    case (op_mode)
                        2'b00: state <= START;
                        2'b01: state <= READ;
                        2'b10: state <= WRITE;
                        2'b11: state <= STOP;
                    endcase
                    wdata <= op_wdata;
                end
            end
            START: begin
                if (tick) begin
                    case (i)
                        0: sda_o <= 1;
                        1: scl_o <= 1;
                        2: sda_o <= 0;
                        3: scl_o <= 0;
                    endcase
                end
            end
            READ: begin
                if (tick) begin
                    case (i)
                        0: sda_o <= 1;
                        1: begin
                            scl_o <= 1;
                            rdata <= sda_i;
                            rdata_valid <= 1;
                        end
                        2:;
                        3: scl_o <= 0;
                    endcase
                end
            end
            WRITE: begin
                if (tick) begin
                    case (i)
                        0: sda_o <= wdata;
                        1: scl_o <= 1;
                        2:;
                        3: scl_o <= 0;
                    endcase
                end
            end
            STOP: begin
                if (tick) begin
                    case (i)
                        0: sda_o <= 0;
                        1: scl_o <= 1;
                        2: sda_o <= 1;
                        3:;
                    endcase
                end
            end

        endcase

        if (state != IDLE && tick) begin
            if (i == 3) begin
                state <= IDLE;
                i <= 0;
            end else begin
                i <= i + 1;
            end
        end

        if (rst) begin
            state <= IDLE;
            rdata_valid <= 0;
            sda_o <= 1;
            scl_o <= 1;
            tick_counter <= 0;
            i <= 0;
        end
    end



endmodule