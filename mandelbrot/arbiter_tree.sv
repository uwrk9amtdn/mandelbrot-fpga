module arbiter_tree #(
    int SLAVE_COUNT                = 64,
    int SINGLE_ARBITER_SLAVE_COUNT = 4
)(
    input clk,
    input rst,

    axis_intf s[SLAVE_COUNT],
    axis_intf m,
);


    generate



    endgenerate

endmodule