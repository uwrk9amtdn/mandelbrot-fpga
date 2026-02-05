module arbiter_tree #(
    int SLAVE_COUNT                = 64,
    int SINGLE_ARBITER_SLAVE_COUNT = 4
)(
    input clk,
    input rst,

    axis_intf s[SLAVE_COUNT],
    axis_intf m,
);

    localparam N = $ceil(SLAVE_COUNT / real'(SINGLE_ARBITER_SLAVE_COUNT)) * SINGLE_ARBITER_SLAVE_COUNT;

    localparam L = $clog2(SLAVE_COUNT);

    axis_intf intf [L][N]();

    for (genvar i = 0; i < N; i++) begin
        if (N <= SLAVE_COUNT - 1) begin
            assign s[i].ready       = intf[0][i].ready;
            assign intf[0][i].valid = s[i].valid;
            assign intf[0][i].data  = s[i].data;
            assign intf[0][i].last  = s[i].last;
        end else begin
            assign intf[0][i].valid = 0;
            assign intf[0][i].data = 0;
            assign intf[0][i].last = 0;
        end
    end

    for (genvar i = 1; i < LEVEL; i++) begin

        for (genvar j = 0; j < i / 4)
    end




    generate
        genvar c;
        c = SLAVE_COUNT;

        while (c > 0) begin
            for (genvar i = 0; i < SINGLE_ARBITER_SLAVE_COUNT; i++) begin
                if (c > 0) begin

                end else begin
                end
            end
        end

    endgenerate

endmodule