// TODO: cleanup
module axis_rr_arbiter_tree #(
    int NS   = 5, // total number of slaves
    int SANS = 2  // single arbiter's number of slaves
)(
    input clk,
    input rst,

    axis_intf s[NS],
    axis_intf m
);

    if (m.LAST_EN != 1) begin
        $error();
    end

    for (genvar i = 0; i < NS; i++) begin
        if (s[i].DATA_WIDTH != m.DATA_WIDTH || s[i].LAST_EN != 1) begin
            $error();
        end
    end

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

    axis_intf #(m.DATA_WIDTH, 1) links [D+1][N/SANS][SANS]();

    for (genvar i = 0; i < N; i++) begin
        if (i < NS) begin
            assign s[i].ready                     = links[0][i/SANS][i%SANS].ready;
            assign links[0][i/SANS][i%SANS].valid = s[i].valid;
            assign links[0][i/SANS][i%SANS].data  = s[i].data;
            assign links[0][i/SANS][i%SANS].last  = s[i].last;
        end else begin
            assign links[0][i/SANS][i%SANS].valid = 0;
            assign links[0][i/SANS][i%SANS].data  = 0;
            assign links[0][i/SANS][i%SANS].last  = 0;
        end
    end

    for (genvar i = 1; i <= D; i++) begin
        localparam int NA = next_multiple(NS, SANS**i) / (SANS**i);
        for (genvar j = 0; j < N; j++) begin
            if (j < NA) begin
                axis_intf #(m.DATA_WIDTH, 1) arbiter_m();
                axis_rr_arbiter #(SANS) arbiter (clk, rst, links[i-1][j], arbiter_m);
                axis_skid_buffer skid_buffer (clk, rst, arbiter_m, links[i][j/SANS][j%SANS]);
            end else begin
                assign links[i][j/SANS][j%SANS].valid = 0;
            end
        end
    end

    assign m.valid              = links[D][0][0].valid;
    assign m.data               = links[D][0][0].data;
    assign m.last               = links[D][0][0].last;
    assign links[D][0][0].ready = m.ready;

endmodule