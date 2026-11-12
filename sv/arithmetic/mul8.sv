module mul8(
    input                      clk,
    input  logic signed [7:0]  a,
    input  logic signed [7:0]  b,
    output logic signed [15:0] q
);

    logic signed [3:0] ah;
    logic        [3:0] al;
    logic signed [3:0] bh;
    logic        [3:0] bl;

    assign ah = a[7:4];
    assign al = a[3:0];
    assign bh = b[7:4];
    assign bl = b[3:0];

    logic signed [7:0]  m1 [2:0];
    logic        [7:0]  m2 [2:0];
    logic signed [11:0] m3 [1:1];

    logic signed [5:0]  s1 [0:0];
    logic signed [5:0]  s2 [0:0];
    logic signed [9:0]  s3 [1:1];
    logic signed [12:0] s4 [2:2];

    always_ff @(posedge clk) begin
        m1[0] <= ah * bh;
        m1[1] <= m1[0];
        m1[2] <= m1[1];

        m2[0] <= al * bl;
        m2[1] <= m2[0];
        m2[2] <= m2[1];

        s1[0] <= ah + signed'({1'b0, al});
        s2[0] <= bh + signed'({1'b0, bl});

        m3[1] <= s1[0] * s2[0];

        s3[1] <= m1[0] + signed'({1'b0, m2[0]});

        s4[2] <= m3[1] - s3[1];

        q <= signed'({m1[2], m2[2]}) + signed'({s4[2], 4'd0});
    end

endmodule

`timescale 1ns/1ps

/*

module tb;

    logic clk;

    logic signed [7:0] a, b;
    logic signed [15:0] q;

    mul8 m(clk, a, b, q);

    property p();
        logic signed [7:0] a_;
        logic signed [7:0] b_;
        @(posedge clk)
        (1, a_ = a, b_ = b) |-> ##4 q == a_ * b_
    endproperty

    assert property (p());

    initial begin
        a = 4;
        b = 3;
        clk = 0;

        fork
            forever #5 clk <= ~clk;
             repeat (10000) begin
                @(posedge clk)
                a <= $urandom;
                b <= $urandom;
            end
        join_any

        $finish;
    end


endmodule

*/