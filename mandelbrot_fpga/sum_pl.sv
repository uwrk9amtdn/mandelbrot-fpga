module sum_pl(
    input             clk,
    input      [31:0] a,
    input      [31:0] b,
    output reg [32:0] q
);


    reg [3:0] c [3:0];

    reg [31:0] a_ [3:0];
    reg [31:0] b_ [3:0];
    reg [31:0] q_ [3:0];

    always @(posedge clk) begin

        a_[0] <= a;
        b_[0] <= b;

        for (int i = 0; i < 3; i++) begin
            a_[i+1] <= a_[i];
            b_[i+1] <= b_[i];
            q_[i+1] <= q_[i];
        end

        {c[0], q_[0][ 7: 0]} <= a    [ 7: 0] + b    [ 7: 0];
        {c[1], q_[1][15: 8]} <= a_[1][15: 8] + b_[1][15: 8] + c[0];
        {c[2], q_[2][23:16]} <= a_[2][23:16] + b_[2][23:16] + c[1];
        {c[3], q_[3][31:24]} <= a_[3][31:24] + b_[3][31:24] + c[2];

        q <= {c[3], q_[3]};
    end


endmodule