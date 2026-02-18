module uberddr3_wrapper_axi #(
    CLK_PERIOD_PS      = 12_000,
    DDR3_CLK_PERIOD_PS = 3_000,
    MICRON_SIM         = 0
)(
    input     clk,
    input     rst,

    input     ddr3_clk,
    input     ddr3_clk_90,
    input     ref_clk, // 200 MHz

    output    calib_complete,

    axi_intf  s_axi,

    ddr3_intf ddr3
);

    if (CLK_PERIOD_PS != 4 * DDR3_CLK_PERIOD_PS) begin
        $error();
    end

    if (s_axi.ADDR_WIDTH != (ddr3.ROW_BITS + ddr3.COL_BITS + ddr3.BA_BITS - 3) + ($clog2(ddr3.DQ_BITS * 8) - 3)) begin
        $error();
    end

    if (s_axi.DATA_WIDTH != ddr3.DQ_BITS * 8) begin
        $error();
    end

    if (s_axi.ID_WIDTH < 4) begin
        $error();
    end

    ddr3_top_axi #(
        .CONTROLLER_CLK_PERIOD (CLK_PERIOD_PS),
        .DDR3_CLK_PERIOD       (DDR3_CLK_PERIOD_PS),
        .ROW_BITS              (ddr3.ROW_BITS),
        .COL_BITS              (ddr3.COL_BITS),
        .BA_BITS               (ddr3.BA_BITS),
        .BYTE_LANES            (ddr3.DQ_BITS/8),
        .AXI_ID_WIDTH          (s_axi.ID_WIDTH),
        .WB2_ADDR_BITS         (7),
        .WB2_DATA_BITS         (32),
        .MICRON_SIM            (MICRON_SIM),
        .ODELAY_SUPPORTED      (0),
        .SECOND_WISHBONE       (0),
        .WB_ERROR              (0),
        .BIST_MODE             (1),
        .ECC_ENABLE            (0),
        .DIC                   (2'b00),
        .RTT_NOM               (3'b011),
        .SELF_REFRESH          (2'b00)
    ) ddr3_top_axi_0 (
        .i_controller_clk (clk),
        .i_ddr3_clk       (ddr3_clk),
        .i_ref_clk        (ref_clk),
        .i_ddr3_clk_90    (ddr3_clk_90),
        .i_rst_n          (~rst),

        .s_axi_awvalid    (s_axi.awvalid),
        .s_axi_awready    (s_axi.awready),
        .s_axi_awid       (s_axi.awid),
        .s_axi_awaddr     (s_axi.awaddr),
        .s_axi_awlen      (s_axi.awlen),
        .s_axi_awsize     (s_axi.awsize),
        .s_axi_awburst    (s_axi.awburst),
        .s_axi_awlock     (s_axi.awlock),
        .s_axi_awcache    (s_axi.awcache),
        .s_axi_awprot     (s_axi.awprot),
        .s_axi_awqos      (s_axi.awqos),

        .s_axi_wvalid     (s_axi.wvalid),
        .s_axi_wready     (s_axi.wready),
        .s_axi_wdata      (s_axi.wdata),
        .s_axi_wstrb      (s_axi.wstrb),
        .s_axi_wlast      (s_axi.wlast),

        .s_axi_bvalid     (s_axi.bvalid),
        .s_axi_bready     (s_axi.bready),
        .s_axi_bid        (s_axi.bid),
        .s_axi_bresp      (s_axi.bresp),

        .s_axi_arvalid    (s_axi.arvalid),
        .s_axi_arready    (s_axi.arready),
        .s_axi_arid       (s_axi.arid),
        .s_axi_araddr     (s_axi.araddr),
        .s_axi_arlen      (s_axi.arlen),
        .s_axi_arsize     (s_axi.arsize),
        .s_axi_arburst    (s_axi.arburst),
        .s_axi_arlock     (s_axi.arlock),
        .s_axi_arcache    (s_axi.arcache),
        .s_axi_arprot     (s_axi.arprot),
        .s_axi_arqos      (s_axi.arqos),

        .s_axi_rvalid     (s_axi.rvalid),
        .s_axi_rready     (s_axi.rready),
        .s_axi_rid        (s_axi.rid),
        .s_axi_rdata      (s_axi.rdata),
        .s_axi_rlast      (s_axi.rlast),
        .s_axi_rresp      (s_axi.rresp),

        .o_ddr3_clk_p     (ddr3.ck),
        .o_ddr3_clk_n     (ddr3.ck_n),
        .o_ddr3_reset_n   (ddr3.rst_n),
        .o_ddr3_cke       (ddr3.cke),
        .o_ddr3_cs_n      (ddr3.cs_n),
        .o_ddr3_ras_n     (ddr3.ras_n),
        .o_ddr3_cas_n     (ddr3.cas_n),
        .o_ddr3_we_n      (ddr3.we_n),
        .o_ddr3_addr      (ddr3.addr),
        .o_ddr3_ba_addr   (ddr3.ba),
        .io_ddr3_dq       (ddr3.dq),
        .io_ddr3_dqs      (ddr3.dqs),
        .io_ddr3_dqs_n    (ddr3.dqs_n),
        .o_ddr3_dm        (ddr3.dm),
        .o_ddr3_odt       (ddr3.odt),

        .o_calib_complete (calib_complete),

        .i_user_self_refresh ('0)
    );

endmodule
