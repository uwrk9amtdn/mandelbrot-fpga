module rise_detector(
    input  logic clk,
    input  logic rst,
    input  logic i,
    output logic o
);
    logic i_d1;

    assign o = ~i_d1 & i;

    always_ff @(posedge clk) begin
        i_d1 <= i;
        if (rst) begin
            i_d1 <= 0;
        end
    end

endmodule