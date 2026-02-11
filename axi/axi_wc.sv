module axi_wc #(
    bit CONVERT_BURST        = 1,
    bit CONVERT_NARROW_BURST = 0
)(
    input clk,
    input rst,

    axi_intf s,
    axi_intf m
);

    if (s.ADDR_WIDTH != m.ADDR_WIDTH) begin
        $error();
    end

    if (s.ID_WIDTH != m.ID_WIDTH) begin
        $error();
    end

    axi_adapter #(
        .ADDR_WIDTH           (s.ADDR_WIDTH),
        .S_DATA_WIDTH         (s.DATA_WIDTH),
        .M_DATA_WIDTH         (m.DATA_WIDTH),
        .ID_WIDTH             (s.ID_WIDTH),
        .CONVERT_BURST        (CONVERT_BURST),
        .CONVERT_NARROW_BURST (CONVERT_NARROW_BURST),
        .FORWARD_ID           (1)
    ) wc (
        .clk (clk),
        .rst (rst),

        .s_axi_awid     (s.awid),
        .s_axi_awaddr   (s.awaddr),
        .s_axi_awlen    (s.awlen),
        .s_axi_awsize   (s.awsize),
        .s_axi_awburst  (s.awburst),
        .s_axi_awlock   (s.awlock),
        .s_axi_awcache  (s.awcache),
        .s_axi_awprot   (s.awprot),
        .s_axi_awqos    (s.awqos),
        .s_axi_awregion (s.awregion),
        .s_axi_awuser   (),
        .s_axi_awvalid  (s.awvalid),
        .s_axi_awready  (s.awready),
        .s_axi_wdata    (s.wdata),
        .s_axi_wstrb    (s.wstrb),
        .s_axi_wlast    (s.wlast),
        .s_axi_wuser    (),
        .s_axi_wvalid   (s.wvalid),
        .s_axi_wready   (s.wready),
        .s_axi_bid      (s.bid),
        .s_axi_bresp    (s.bresp),
        .s_axi_buser    (),
        .s_axi_bvalid   (s.bvalid),
        .s_axi_bready   (s.bready),
        .s_axi_arid     (s.arid),
        .s_axi_araddr   (s.araddr),
        .s_axi_arlen    (s.arlen),
        .s_axi_arsize   (s.arsize),
        .s_axi_arburst  (s.arburst),
        .s_axi_arlock   (s.arlock),
        .s_axi_arcache  (s.arcache),
        .s_axi_arprot   (s.arprot),
        .s_axi_arqos    (s.arqos),
        .s_axi_arregion (s.arregion),
        .s_axi_aruser   (),
        .s_axi_arvalid  (s.arvalid),
        .s_axi_arready  (s.arready),
        .s_axi_rid      (s.rid),
        .s_axi_rdata    (s.rdata),
        .s_axi_rresp    (s.rresp),
        .s_axi_rlast    (s.rlast),
        .s_axi_ruser    (),
        .s_axi_rvalid   (s.rvalid),
        .s_axi_rready   (s.rready),

        .m_axi_awid     (m.awid),
        .m_axi_awaddr   (m.awaddr),
        .m_axi_awlen    (m.awlen),
        .m_axi_awsize   (m.awsize),
        .m_axi_awburst  (m.awburst),
        .m_axi_awlock   (m.awlock),
        .m_axi_awcache  (m.awcache),
        .m_axi_awprot   (m.awprot),
        .m_axi_awqos    (m.awqos),
        .m_axi_awregion (m.awregion),
        .m_axi_awuser   (),
        .m_axi_awvalid  (m.awvalid),
        .m_axi_awready  (m.awready),
        .m_axi_wdata    (m.wdata),
        .m_axi_wstrb    (m.wstrb),
        .m_axi_wlast    (m.wlast),
        .m_axi_wuser    (),
        .m_axi_wvalid   (m.wvalid),
        .m_axi_wready   (m.wready),
        .m_axi_bid      (m.bid),
        .m_axi_bresp    (m.bresp),
        .m_axi_buser    (),
        .m_axi_bvalid   (m.bvalid),
        .m_axi_bready   (m.bready),
        .m_axi_arid     (m.arid),
        .m_axi_araddr   (m.araddr),
        .m_axi_arlen    (m.arlen),
        .m_axi_arsize   (m.arsize),
        .m_axi_arburst  (m.arburst),
        .m_axi_arlock   (m.arlock),
        .m_axi_arcache  (m.arcache),
        .m_axi_arprot   (m.arprot),
        .m_axi_arqos    (m.arqos),
        .m_axi_arregion (m.arregion),
        .m_axi_aruser   (),
        .m_axi_arvalid  (m.arvalid),
        .m_axi_arready  (m.arready),
        .m_axi_rid      (m.rid),
        .m_axi_rdata    (m.rdata),
        .m_axi_rresp    (m.rresp),
        .m_axi_rlast    (m.rlast),
        .m_axi_ruser    (),
        .m_axi_rvalid   (m.rvalid),
        .m_axi_rready   (m.rready)
    );



endmodule