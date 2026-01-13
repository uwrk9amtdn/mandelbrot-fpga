module ac701_adv7811_setup
#(
    CLK_FREQ = 100.0e6,
    SCL_FREQ = 100.0e3
)(
    input  clk,
    input  rst,

    output reg error = 0,
    output reg done = 0,

    input  sda_i,
    output sda_o,

    input  scl_i,
    output scl_o
);

    reg [15:0] pc = 0;

    reg [31:0] time_counter = 0;
    reg [15:0] call_stack [7:0];
    reg [2:0]  call_stack_pos = 0;

    reg [31:0] args [3:0];

    wire       i2c_op_ready;
    reg        i2c_op_valid = 0;
    reg  [1:0] i2c_op_mode;
    reg  [7:0] i2c_op_wdata;
    reg        i2c_op_rack;

    wire [7:0] i2c_rdata;
    wire       i2c_rdata_valid;

    wire       i2c_wack;
    wire       i2c_wack_valid;

    localparam [6:0] ADV7811_I2C_ADDR = 7'h39;
    localparam [6:0] PCA9548_I2C_ADDR = 7'h74;

    localparam SLEEP_DURATION = int'(2.0e6 / (1.0e9 / CLK_FREQ));

    localparam SETUP_BUS_SWITCH = 10;
    localparam SETUP_ADV7811    = 20;
    localparam WRITE_REG        = 40;
    localparam SLEEP            = 50;
    localparam I2C_ERROR        = 60;

    task call([15:0] address, [31:0] arg0 = 'hx, arg1 = 'hx, arg2 = 'hx, arg3 = 'hx);

        args[0] <= arg0;
        args[1] <= arg1;
        args[2] <= arg2;
        args[3] <= arg3;

        call_stack[call_stack_pos] <= pc + 1;
        call_stack_pos             <= call_stack_pos + 1;
        pc                         <= address;
    endtask

    task jump([15:0] address); pc <= address; endtask

    task ret;
        pc <= call_stack[call_stack_pos - 1];
        call_stack_pos <= call_stack_pos - 1;
    endtask

    task halt; pc <= pc; endtask

    task i2c_send_op ([1:0] mode, [7:0] wdata = 8'hx, [0:0] rack = 1'hx);
        pc <= pc;
        i2c_op_valid <= 1;
        i2c_op_mode  <= mode;
        i2c_op_wdata <= wdata;
        i2c_op_rack  <= rack;
        if (i2c_op_ready & i2c_op_valid) begin
            i2c_op_valid <= 0;
            pc <= pc + 1;
        end
    endtask

    task i2c_read_byte (output [7:0] out);
        pc <= pc;
        if (i2c_rdata_valid) begin
            out <= i2c_rdata;
            pc <= pc + 1;
        end
    endtask

    task i2c_check_wack;
        pc <= pc;
        if (i2c_wack_valid) begin
            if (i2c_wack) begin
                pc <= pc + 1;
            end else begin
                pc <= I2C_ERROR;
            end
        end
    endtask

    i2c_byte_ctrl#(
        .CLK_FREQ (CLK_FREQ),
        .SCL_FREQ (SCL_FREQ)
    ) i2c_i0 (
        .clk (clk),
        .rst (rst),

        .op_ready    (i2c_op_ready),
        .op_valid    (i2c_op_valid),
        .op_mode     (i2c_op_mode),
        .op_wdata    (i2c_op_wdata),
        .op_rack     (i2c_op_rack),

        .rdata       (i2c_rdata),
        .rdata_valid (i2c_rdata_valid),

        .wack        (i2c_wack),
        .wack_valid  (i2c_wack_valid),

        .sda_i       (sda_i),
        .sda_o       (sda_o),

        .scl_i       (scl_i),
        .scl_o       (scl_o)
    );

    // verilator lint_off WIDTHEXPAND

    always @(posedge clk) begin

            pc <= pc + 1;

            if (time_counter != 0) time_counter <= time_counter - 1;

            case (pc)
                0: call (SLEEP, SLEEP_DURATION);
                1: call (SETUP_BUS_SWITCH);
                2: call (SETUP_ADV7811);
                3: done <= 1;
                4: halt;

                // SETUP_BUS_SWITCH
                10: i2c_send_op (0);
                11: i2c_send_op (2, {PCA9548_I2C_ADDR, 1'b0});
                12: i2c_check_wack;
                13: i2c_send_op (2, 1 << 5);
                14: i2c_check_wack;
                15: i2c_send_op (3);
                16: ret;

                // SETUP_ADV7811
                20: call(WRITE_REG, 8'h41, 8'h10);
                21: call(WRITE_REG, 8'h98, 8'h03);
                22: call(WRITE_REG, 8'h9a, 8'he0);
                23: call(WRITE_REG, 8'h9c, 8'h30);
                24: call(WRITE_REG, 8'h9d, 8'h61);
                25: call(WRITE_REG, 8'ha2, 8'ha4);
                26: call(WRITE_REG, 8'ha3, 8'ha4);
                27: call(WRITE_REG, 8'he0, 8'hd0);
                28: call(WRITE_REG, 8'hf9, 8'h00);
                29: call(WRITE_REG, 8'h16, 8'h30);
                30: call(WRITE_REG, 8'h17, 8'h02);
                31: ret;

                // WRITE_REG
                40: i2c_send_op (0);
                41: i2c_send_op (2, {ADV7811_I2C_ADDR, 1'b0});
                42: i2c_check_wack;
                43: i2c_send_op (2, args[0][7:0]);
                44: i2c_check_wack;
                45: i2c_send_op (2, args[1][7:0]);
                46: i2c_check_wack;
                47: i2c_send_op (3);
                48: ret;

                // SLEEP
                50: time_counter <= args[0];
                51: if (time_counter == 0) ret; else halt;

                // I2C_ERROR
                60: i2c_send_op (3);
                61: error <= 1;
                62: halt;

                default:;
            endcase

        if (rst) begin
            error <= 0;
            done <= 0;
            pc <= 0;
            time_counter <= 0;
            call_stack_pos <= 0;
            i2c_op_valid <= 0;
        end
    end


endmodule