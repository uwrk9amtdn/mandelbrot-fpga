module axis_sequence_arbiter #(
    DATA_WIDTH   = 32,
    MASTER_COUNT = 4
) (
    input clk,
    input rst,
    axis_intf m[MASTER_COUNT],
    axis_intf s
);



    logic [$clog2(MASTER_COUNT)-1:0] index;

    task reset();
        index   <= 0;
        s.valid <= 0;
        s.data  <= 0;
        for (int i = 0; i < MASTER_COUNT; i++) begin
            m[i].ready <= 0;
        end
    endtask

    initial begin
        reset();
    end

    always_ff @(posedge clk) begin
        index <= index + 1;

        for (int i = 0; i < MASTER_COUNT; i++) begin
            m[i].ready <= 0;
        end

        m[index].ready <= s.ready;
        s.data     <= m[index].data;
        s.valid    <= m[index].valid;

        if (rst) begin
            reset();
        end
    end
endmodule