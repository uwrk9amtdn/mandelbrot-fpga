interface axis_intf #(DATA_WIDTH = 32);
    logic ready;
    logic valid;
    logic [DATA_WIDTH-1:0] data;
endinterface

module axis_sequence_arbiter #(
    DATA_WIDTH  = 32,
    SLAVE_COUNT = 4
) (
    input clk,
    input rst,
    axis_intf s[SLAVE_COUNT],
    axis_intf m
);

    logic [$clog2(SLAVE_COUNT)-1:0] index;

    task reset();
        index   <= 0;
        m.valid <= 0;
        m.data  <= 0;
        for (int i = 0; i < MASTER_COUNT; i++) begin
            s[i].ready <= 0;
        end
    endtask

    initial begin
        reset();
    end

    always_ff @(posedge clk) begin
        index <= index + 1;

        for (int i = 0; i < MASTER_COUNT; i++) begin
            s[i].ready <= 0;
        end

        s[index].ready <= m.ready;
        m.data     <= s[index].data;
        m.valid    <= s[index].valid;

        if (rst) begin
            reset();
        end
    end
endmodule

module arbiter2(
    input clk,
    input rst,

	input       s1_valid,
	input [7:0] s1_data,
	output      s1_ready,

	input       s2_valid,
	input [7:0] s2_data,
	output      s2_ready,

	output       m_valid,
	output [7:0] m_data,
	input        m_ready
);

	axis_intf #(8) s1;
 	axis_intf #(8) s2;

    axis_intf #(8) m;

    axis_sequence_arbiter #(8, 2) m (clk, rst, s1, s2, m);

    assign s1.valid = s1_valid;
    assign s1.data  = s1_data;
    assign s1_ready = s1.ready;

    assign s2.valid = s2_valid;
    assign s2.data  = s2_data;
    assign s2_ready = s2.ready;

    assign m_valid = m.valid;
    assign m_data  = m.data;
    assign m_ready = m.ready;

endmodule