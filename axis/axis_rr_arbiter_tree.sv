module axis_rr_arbiter_tree #(
    int NS   = 5, // total number of slaves
    int SANS = 2  // single arbiter's number of slaves
)(
    input clk,
    input rst,

    axis_intf s[NS],
    axis_intf m
);

    function automatic int calc_depth(input int items, input int radix);
        int depth = 0;
        int count = 1;
        while (count < items) begin
            count = count * radix;
            depth++;
        end
        return depth;
    endfunction

    function automatic int next_multiple(input int x, input int d);
        return ((x + d - 1) / d) * d;
    endfunction

    localparam D = calc_depth(NS, SANS);
    localparam N = next_multiple(NS, SANS);

    axis_intf #(m.DATA_WIDTH) links [D+1][N]();

    for (genvar i = 0; i < N; i++) begin
        if (i < NS) begin
            assign s[i].ready        = links[0][i].ready;
            assign links[0][i].valid = s[i].valid;
            assign links[0][i].data  = s[i].data;
            assign links[0][i].last  = s[i].last;
        end else begin
            assign links[0][i].valid = 0;
        end
    end

    for (genvar i = 1; i <= D; i++) begin
        localparam int number_of_arbiters = next_multiple(NS, SANS**i) / (SANS**i);
        for (genvar j = 0; j < N; j++) begin
            if (j < number_of_arbiters) begin
                axis_intf #(m.DATA_WIDTH) arbiter_m();
                axis_rr_arbiter #(SANS) arbiter (clk, rst, links[i-1][j*SANS+:SANS], arbiter_m);
                axis_skid_buffer skid_buffer (clk, rst, arbiter_m, links[i][j]);
            end else begin
                assign links[i][j].valid = 0;
            end
        end
    end

    assign m.valid              = links[D][0].valid;
    assign m.data               = links[D][0].data;
    assign m.last               = links[D][0].last;
    assign links[D][0].ready    = m.ready;

endmodule