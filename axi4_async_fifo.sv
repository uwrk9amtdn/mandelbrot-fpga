module axi4_async_fifo #(
    ADDR_WIDTH = 32,
    DATA_WIDTH = 32,
    ID_WIDTH   = 1
)(
    input s_axi_clk,
    input m_axi_clk,

    input aresetn,

    axi.slave  s_axi,
    axi.master m_axi
);

    xpm_fifo_axif #(
        .AXI_ADDR_WIDTH           (ADDR_WIDTH),
        .AXI_DATA_WIDTH           (DATA_WIDTH),
        .AXI_ID_WIDTH             (ID_WIDTH),
        .AXI_LEN_WIDTH            (8),

        .AXI_ARUSER_WIDTH         (1),
        .AXI_AWUSER_WIDTH         (1),
        .AXI_RUSER_WIDTH          (1),
        .AXI_WUSER_WIDTH          (1),
        .AXI_BUSER_WIDTH          (1),

        .CASCADE_HEIGHT           (0),
        .CDC_SYNC_STAGES          (2),
        .CLOCKING_MODE            ("independent_clock"),
        .ECC_MODE_RDCH            ("no_ecc"),
        .ECC_MODE_WDCH            ("no_ecc"),
        .EN_RESET_SYNCHRONIZER    (1),
        .EN_SIM_ASSERT_ERR        ("warning"),

        .FIFO_DEPTH_RACH          (256),
        .FIFO_DEPTH_RDCH          (256),
        .FIFO_DEPTH_WACH          (256),
        .FIFO_DEPTH_WDCH          (256),
        .FIFO_DEPTH_WRCH          (256),

        .FIFO_MEMORY_TYPE_RACH    ("auto"),
        .FIFO_MEMORY_TYPE_RDCH    ("auto"),
        .FIFO_MEMORY_TYPE_WACH    ("auto"),
        .FIFO_MEMORY_TYPE_WDCH    ("auto"),
        .FIFO_MEMORY_TYPE_WRCH    ("auto"),

        .PACKET_FIFO              ("false"),
        .PROG_EMPTY_THRESH_RDCH   (10),
        .PROG_EMPTY_THRESH_WDCH   (10),
        .PROG_FULL_THRESH_RDCH    (10),
        .PROG_FULL_THRESH_WDCH    (10),

        .RD_DATA_COUNT_WIDTH_RDCH (1),
        .RD_DATA_COUNT_WIDTH_WDCH (1),
        .SIM_ASSERT_CHK           (0),
        .USE_ADV_FEATURES_RDCH    ("1000"),
        .USE_ADV_FEATURES_WDCH    ("1000"),
        .WR_DATA_COUNT_WIDTH_RDCH (1),
        .WR_DATA_COUNT_WIDTH_WDCH (1)
    ) xpm_fifo_axif_inst (
        .dbiterr_rdch       (),
        .dbiterr_wdch       (),
        .sbiterr_rdch       (),
        .sbiterr_wdch       (),

        .prog_empty_rdch    (),
        .prog_empty_wdch    (),
        .prog_full_rdch     (),
        .prog_full_wdch     (),

        .rd_data_count_rdch (),
        .rd_data_count_wdch (),
        .wr_data_count_rdch (),
        .wr_data_count_wdch (),

        .injectdbiterr_rdch (),
        .injectdbiterr_wdch (),
        .injectsbiterr_rdch (),
        .injectsbiterr_wdch (),

        .m_axi_aruser       (),
        .m_axi_awuser       (),
        .m_axi_wuser        (),
        .s_axi_buser        (),
        .s_axi_ruser        (),

        .m_axi_buser        (1'bx),
        .m_axi_ruser        (1'bx),
        .s_axi_aruser       (1'bx),
        .s_axi_awuser       (1'bx),
        .s_axi_wuser        (1'bx),

        .s_aclk             (s_axi_clk),
        .m_aclk             (m_axi_clk),
        .s_aresetn          (aresetn),

        // axi master
        .m_axi_awid    (m_axi.awid),
        .m_axi_awaddr  (m_axi.awaddr),
        .m_axi_awlen   (m_axi.awlen),
        .m_axi_awsize  (m_axi.awsize),
        .m_axi_awburst (m_axi.awburst),
        .m_axi_awlock  (m_axi.awlock),
        .m_axi_awcache (m_axi.awcache),
        .m_axi_awprot  (m_axi.awprot),
        .m_axi_awqos   (m_axi.awqos),
        .m_axi_awvalid (m_axi.awvalid),
        .m_axi_awready (m_axi.awready),

        .m_axi_wdata   (m_axi.wdata),
        .m_axi_wstrb   (m_axi.wstrb),
        .m_axi_wlast   (m_axi.wlast),
        .m_axi_wvalid  (m_axi.wvalid),
        .m_axi_wready  (m_axi.wready),

        .m_axi_bid     (m_axi.bid),
        .m_axi_bresp   (m_axi.bresp),
        .m_axi_bvalid  (m_axi.bvalid),
        .m_axi_bready  (m_axi.bready),

        .m_axi_arid    (m_axi.arid),
        .m_axi_araddr  (m_axi.araddr),
        .m_axi_arlen   (m_axi.arlen),
        .m_axi_arsize  (m_axi.arsize),
        .m_axi_arburst (m_axi.arburst),
        .m_axi_arlock  (m_axi.arlock),
        .m_axi_arcache (m_axi.arcache),
        .m_axi_arprot  (m_axi.arprot),
        .m_axi_arqos   (m_axi.arqos),
        .m_axi_arvalid (m_axi.arvalid),
        .m_axi_arready (m_axi.arready),

        .m_axi_rid     (m_axi.rid),
        .m_axi_rdata   (m_axi.rdata),
        .m_axi_rresp   (m_axi.rresp),
        .m_axi_rlast   (m_axi.rlast),
        .m_axi_rvalid  (m_axi.rvalid),
        .m_axi_rready  (m_axi.rready),

        // axi slave
        .s_axi_awid    (s_axi.awid),
        .s_axi_awaddr  (s_axi.awaddr),
        .s_axi_awlen   (s_axi.awlen),
        .s_axi_awsize  (s_axi.awsize),
        .s_axi_awburst (s_axi.awburst),
        .s_axi_awlock  (s_axi.awlock),
        .s_axi_awcache (s_axi.awcache),
        .s_axi_awprot  (s_axi.awprot),
        .s_axi_awqos   (s_axi.awqos),
        .s_axi_awvalid (s_axi.awvalid),
        .s_axi_awready (s_axi.awready),

        .s_axi_wdata   (s_axi.wdata),
        .s_axi_wstrb   (s_axi.wstrb),
        .s_axi_wlast   (s_axi.wlast),
        .s_axi_wvalid  (s_axi.wvalid),
        .s_axi_wready  (s_axi.wready),

        .s_axi_bid     (s_axi.bid),
        .s_axi_bresp   (s_axi.bresp),
        .s_axi_bvalid  (s_axi.bvalid),
        .s_axi_bready  (s_axi.bready),

        .s_axi_arid    (s_axi.arid),
        .s_axi_araddr  (s_axi.araddr),
        .s_axi_arlen   (s_axi.arlen),
        .s_axi_arsize  (s_axi.arsize),
        .s_axi_arburst (s_axi.arburst),
        .s_axi_arlock  (s_axi.arlock),
        .s_axi_arcache (s_axi.arcache),
        .s_axi_arprot  (s_axi.arprot),
        .s_axi_arqos   (s_axi.arqos),
        .s_axi_arvalid (s_axi.arvalid),
        .s_axi_arready (s_axi.arready),

        .s_axi_rid     (s_axi.rid),
        .s_axi_rdata   (s_axi.rdata),
        .s_axi_rresp   (s_axi.rresp),
        .s_axi_rlast   (s_axi.rlast),
        .s_axi_rvalid  (s_axi.rvalid),
        .s_axi_rready  (s_axi.rready)
    );
endmodule
