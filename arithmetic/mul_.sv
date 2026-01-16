module mul #(
    WIDTH=32
)(
    input clk,
    input rst,

    input  [WIDTH-1:0] a,
    input  [WIDTH-1:0] b,
    input              ab_valid,

    output logic [2*WIDTH-1:0] x,
    output logic               x_valid
);

    logic [2*WIDTH-1:0] a_reg;
    logic [WIDTH-1:0] b_reg;

    logic [$clog2(WIDTH-1):0] counter;

    always @(posedge clk) begin
        b_reg   <= b_reg >> 1;
        a_reg   <= a_reg << 1;
        counter <= counter - 1;

        if (b_reg[0]) begin
            x <= x + a_reg;
        end

        if (counter == 0) begin
            x_valid <= 1;
        end

        if (ab_valid) begin
            x       <= 0;
            a_reg   <= a;
            b_reg   <= b;
            counter <= WIDTH;
            x_valid <= 0;
        end
    end


endmodule