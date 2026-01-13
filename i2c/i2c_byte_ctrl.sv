module i2c_byte_ctrl #(
    CLK_FREQ = 100.0e6,
    SCL_FREQ = 400.0e3
)(
    input            clk,
    input            rst,

    output reg       op_ready,
    input            op_valid,
    input      [1:0] op_mode, // 0:start, 1:read, 2:write, 3:stop
    input      [7:0] op_wdata,
    input            op_rack,

    output reg [7:0] rdata,
    output reg       rdata_valid,

    output reg       wack,
    output reg       wack_valid,

    input            sda_i,
    output           sda_o,

    input            scl_i,
    output           scl_o
);

    wire      bit_op_ready;
    reg       bit_op_valid = 0;
    reg [1:0] bit_op_mode;
    reg       bit_op_wdata;

    wire      bit_rdata;
    wire      bit_rdata_valid;

    i2c_bit_ctrl #(
        .CLK_FREQ (CLK_FREQ),
        .SCL_FREQ (SCL_FREQ)
    ) i2c_bit_ctrl_i0 (
        .clk         (clk),
        .rst         (rst),

        .op_ready    (bit_op_ready),
        .op_valid    (bit_op_valid),
        .op_mode     (bit_op_mode),
        .op_wdata    (bit_op_wdata),

        .rdata       (bit_rdata),
        .rdata_valid (bit_rdata_valid),

        .sda_i       (sda_i),
        .sda_o       (sda_o),

        .scl_i       (scl_i),
        .scl_o       (scl_o)
    );

    reg [7:0] wdata;
    reg rack;

    reg [2:0] byte_counter = 0;

    typedef enum { IDLE, START, READ, READ_RCV, READ_ACK, WRITE, WRITE_ACK, WRITE_ACK_RCV, STOP } state_t;
    state_t state = IDLE;

    assign op_ready = state == IDLE;

    always @(posedge clk) begin

        rdata_valid <= 0;
        wack_valid <= 0;

        case (state)
            IDLE: begin
                if (op_ready & op_valid) begin
                    rack  <= op_rack;
                    wdata <= op_wdata;
                    case (op_mode)
                        2'b00: state <= START;
                        2'b01: state <= READ;
                        2'b10: state <= WRITE;
                        2'b11: state <= STOP;
                    endcase
                end
            end

            START: begin
                bit_op_valid <= 1;
                bit_op_mode  <= 0;
                if (bit_op_ready & bit_op_valid) begin
                    bit_op_valid <= 0;
                    state        <= IDLE;
                end
            end

            READ: begin
                bit_op_valid <= 1;
                bit_op_mode  <= 1;
                if (bit_op_ready & bit_op_valid) begin
                    bit_op_valid <= 0;
                    state        <= READ_RCV;
                end
            end

            READ_RCV: begin
                if (bit_rdata_valid) begin
                    rdata <= {rdata[7:1], bit_rdata};
                    if (byte_counter == 7) begin
                        rdata_valid  <= 1;
                        byte_counter <= 0;
                        state        <= READ_ACK;
                    end else begin
                        byte_counter <= byte_counter + 1;
                        state        <= READ;
                    end
                end
            end

            READ_ACK: begin
                bit_op_valid <= 1;
                bit_op_mode  <= 2;
                bit_op_wdata <= ~rack;
                if (bit_op_ready & bit_op_valid) begin
                    bit_op_valid <= 0;
                    state        <= IDLE;
                end
            end

            WRITE: begin
                bit_op_valid <= 1;
                bit_op_mode <= 2;
                bit_op_wdata <= wdata[7];
                if (bit_op_ready & bit_op_valid) begin
                    bit_op_valid <= 0;
                    wdata        <= wdata << 1;
                    if (byte_counter == 7) begin
                        byte_counter      <= 0;
                        state             <= WRITE_ACK;
                    end else byte_counter <= byte_counter + 1;
                end
            end

            WRITE_ACK: begin
                bit_op_valid <= 1;
                bit_op_mode  <= 1;
                if (bit_op_ready & bit_op_valid) begin
                    bit_op_valid <= 0;
                    state        <= WRITE_ACK_RCV;
                end
            end

            WRITE_ACK_RCV: begin
                if (bit_rdata_valid) begin
                    wack_valid <= 1;
                    wack       <= ~bit_rdata;
                    state      <= IDLE;
                end
            end

            STOP: begin
                bit_op_valid <= 1;
                bit_op_mode  <= 3;
                if (bit_op_ready & bit_op_valid) begin
                    bit_op_valid <= 0;
                    state        <= IDLE;
                end
            end
        endcase

        if (rst) begin
            bit_op_valid <= 0;
            byte_counter <= 0;
            state        <= IDLE;
        end
    end



endmodule