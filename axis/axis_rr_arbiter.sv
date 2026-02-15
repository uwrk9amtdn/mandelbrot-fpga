// scanning round-robit arbiter
module axis_rr_arbiter #(
    NS = 4 // number of slaves
)(
    input  logic clk,
    input  logic rst,

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

    localparam INDEX_WIDTH = NS > 1 ? $clog2(NS) : 1;

    logic                   locked;
    logic [INDEX_WIDTH-1:0] index;

    logic                    s_ready [NS-1:0];
    logic                    s_valid [NS-1:0];
    logic [m.DATA_WIDTH-1:0] s_data  [NS-1:0];
    logic                    s_last  [NS-1:0];

    for (genvar i = 0; i < NS; i++) begin
        assign s_valid[i] = s[i].valid;
        assign s_data[i]  = s[i].data;
        assign s_last[i]  = s[i].last;
        assign s[i].ready = s_ready[i];
    end

    always_comb begin
        m.valid = s_valid [index];
        m.data  = s_data  [index];
        m.last  = s_last  [index];

        for (int i = 0; i < NS; i++) begin
            s_ready[i] = 0;
        end
        s_ready[index] = m.ready;
    end

    always_ff @(posedge clk) begin

        if (m.valid & m.ready) begin
            locked <= ~m.last;
        end

        if ((~m.valid & ~locked) | (m.valid & m.ready & m.last)) begin
            if (index == NS - 1) begin
                index <= 0;
            end else begin
                index <= index + 1;
            end
        end

        if (rst) begin
            index  <= 0;
            locked <= 0;
        end
    end

endmodule