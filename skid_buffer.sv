module skid_buffer(
    input clk, rst,
    axis_intf s,
    axis_intf m
);

    type(s.data) skid_data;
    logic        skid_valid;

    always_ff @(posedge clk) begin

        s.ready <= m.ready;

        if (m.ready | ~m.valid) begin
            if (skid_valid) begin
                skid_valid <= 0;
                m.valid    <= 1;
                m.data     <= skid_data;
            end else begin
                m.valid <= s.valid;
                m.data  <= s.data;
            end
        end

        if (s.ready & s.valid & ~m.ready & m.valid) begin
            skid_valid <= 1;
            skid_data  <= s.data;
        end

        if (rst) begin
            skid_valid <= 0;
            s.ready    <= 0;
            m.valid    <= 0;
        end
    end

endmodule