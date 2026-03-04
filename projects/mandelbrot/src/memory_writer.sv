module memory_writer #(
    int BURST_LENGTH = 16,
    int AXI_ID       = 1
)(
    input clk,
    input rst,

    axis_intf s_addr,
    axis_intf s_data,

    axi_intf  m
);

    if (s_data.DATA_WIDTH != m.DATA_WIDTH || s_data.LAST_EN != 1) begin
        $error();
    end

    if (s_addr.DATA_WIDTH != 32 || s_addr.LAST_EN != 0) begin
        $error();
    end

    if (s_data.DATA_WIDTH / 16 > BURST_LENGTH || BURST_LENGTH % (s_data.DATA_WIDTH / 16) != 0) begin
        $error();
    end

    assign m.awid       = AXI_ID;
    assign m.awaddr     = s_addr.data;
    assign m.awlen      = BURST_LENGTH / (s_data.DATA_WIDTH / 16) - 1;
    assign m.awsize     = $clog2(s_data.DATA_WIDTH / 8);
    assign m.awburst    = 2'b01;
    assign m.awlock     = 0;
    assign m.awcache    = 4'b0011;
    assign m.awprot     = 0;
    assign m.awqos      = 0;
    assign m.awvalid    = s_addr.valid;
    assign s_addr.ready = m.awready;

    assign m.wdata      = s_data.data;
    assign m.wstrb      = '1;
    assign m.wlast      = s_data.last;
    assign m.wvalid     = s_data.valid;
    assign s_data.ready = m.wready;

    assign m.bready     = 1;
endmodule
