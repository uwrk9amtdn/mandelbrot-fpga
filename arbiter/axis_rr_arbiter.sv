// scanning round-robit arbiter
module axis_rr_arbiter #(
    SLAVE_COUNT = 4
)(
    input  logic clk,
    input  logic rst,

    axis_intf s[SLAVE_COUNT],
    axis_intf m
);

    localparam INDEX_WIDTH = SLAVE_COUNT > 1 ? $clog2(SLAVE_COUNT) : 1;

    logic                   locked;
    logic [INDEX_WIDTH-1:0] index;

    logic        s_ready [SLAVE_COUNT-1:0];
    logic        s_valid [SLAVE_COUNT-1:0];
    type(m.data) s_data  [SLAVE_COUNT-1:0];
    logic        s_last  [SLAVE_COUNT-1:0];

    generate
        for (genvar i = 0; i < SLAVE_COUNT; i++) begin
            assign s_valid[i] = s[i].valid;
            assign s_data[i]  = s[i].data;
            assign s_last[i]  = s[i].last;
            assign s[i].ready = s_ready[i];
        end
    endgenerate

    always_comb begin
        m.valid = s_valid [index];
        m.data  = s_data  [index];
        m.last  = s_last  [index];

        for (int i = 0; i < SLAVE_COUNT; i++) begin
            s_ready[i] = 0;
        end
        s_ready[index] = m.ready;
    end

    always_ff @(posedge clk) begin

        if (m.valid & m.ready) begin
            locked <= ~m.last;
        end

        if ((~m.valid & ~locked) | (m.valid & m.ready & m.last)) begin
            if (index == SLAVE_COUNT - 1) begin
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