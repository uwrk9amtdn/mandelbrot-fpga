module axis_skid_buffer(
    input clk, rst,
    axis_intf s,
    axis_intf m
);

    if (s.DATA_WIDTH != m.DATA_WIDTH) begin
        $error();
    end

    // TODO: add LAST_EN = 0 support
    if (s.LAST_EN != 1 || m.LAST_EN != 1) begin
        $error();
    end

    logic [m.DATA_WIDTH-1:0] skid_data;
    logic                    skid_last;
    logic                    skid_valid;

    always_ff @(posedge clk) begin

        s.ready <= m.ready;

        if (m.ready | ~m.valid) begin
            if (skid_valid) begin
                skid_valid <= 0;
                m.valid    <= 1;
                m.data     <= skid_data;
                m.last     <= skid_last;
            end else begin
                m.valid <= s.valid;
                m.data  <= s.data;
                m.last  <= s.last;
            end
        end

        if (s.ready & s.valid & ~m.ready & m.valid) begin
            skid_valid <= 1;
            skid_data  <= s.data;
            skid_last  <= s.last;
        end

        if (rst) begin
            skid_valid <= 0;
            s.ready    <= 0;
            m.valid    <= 0;
        end
    end

endmodule