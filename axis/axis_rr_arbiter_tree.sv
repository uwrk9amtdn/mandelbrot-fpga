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

    // verilator does not support multidimensional interface arrays
    axis_intf #(m.DATA_WIDTH, 1) links [(D+1)*N]();

    for (genvar i = 0; i < N; i++) begin
        if (i < NS) begin
            assign s[i].ready     = links[i].ready;
            assign links[i].valid = s[i].valid;
            assign links[i].data  = s[i].data;
            assign links[i].last  = s[i].last;
        end else begin
            assign links[i].valid = 0;
            assign links[i].data  = 0;
            assign links[i].last  = 0;
        end
    end

    for (genvar i = 1; i <= D; i++) begin
        localparam int NA = next_multiple(NS, SANS**i) / (SANS**i);
        for (genvar j = 0; j < N; j++) begin
            if (j < NA) begin
                axis_intf #(m.DATA_WIDTH, 1) arbiter_s[SANS]();
                axis_intf #(m.DATA_WIDTH, 1) arbiter_m();
                for (genvar k = 0; k < SANS; k++) begin
                    axis_intf_connect con(links[(i-1)*N+j*SANS+k], arbiter_s[k]);
                end
                axis_rr_arbiter #(SANS) arbiter (clk, rst, arbiter_s, arbiter_m);
                axis_skid_buffer skid_buffer (clk, rst, arbiter_m, links[i*N+j]);
            end else begin
                assign links[i*N+j].valid = 0;
            end
        end
    end

    assign m.valid            = links[D*N+0].valid;
    assign m.data             = links[D*N+0].data;
    assign m.last             = links[D*N+0].last;
    assign links[D*N+0].ready = m.ready;

endmodule