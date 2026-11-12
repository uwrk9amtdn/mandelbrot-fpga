module mig_ac701_axi_wrapper (
    input           sys_clk,
    input           sys_rst,

    ddr3_intf       ddr3,

    output          init_calib_complete,

    output          s_axi_clk,
    output          s_axi_rst,
    axi_intf        s_axi
);

    if (
        ddr3.DM_BITS  != 8  ||
        ddr3.BA_BITS  != 3  ||
        ddr3.ROW_BITS != 14 ||
        ddr3.COL_BITS != 10 ||
        ddr3.DQ_BITS  != 64 ||
        ddr3.DQS_BITS != 8
    ) begin
        $error();
    end

    if (
        s_axi.ID_WIDTH   != 4  ||
        s_axi.ADDR_WIDTH != 30 ||
        s_axi.DATA_WIDTH != 512
    ) begin
        $error();
    end

    wire ui_clk;
    wire ui_clk_sync_rst;

    assign s_axi_clk = ui_clk;
    assign s_axi_rst = ui_clk_sync_rst;

    mig_ac701_axi mig (
        .ddr3_dq                        (ddr3.dq),
        .ddr3_dqs_n                     (ddr3.dqs_n),
        .ddr3_dqs_p                     (ddr3.dqs),
        .ddr3_addr                      (ddr3.addr),
        .ddr3_ba                        (ddr3.ba),
        .ddr3_ras_n                     (ddr3.ras_n),
        .ddr3_cas_n                     (ddr3.cas_n),
        .ddr3_we_n                      (ddr3.we_n),
        .ddr3_reset_n                   (ddr3.rst_n),
        .ddr3_ck_p                      (ddr3.ck),
        .ddr3_ck_n                      (ddr3.ck_n),
        .ddr3_cke                       (ddr3.cke),
        .ddr3_cs_n                      (ddr3.cs_n),
        .ddr3_dm                        (ddr3.dm),
        .ddr3_odt                       (ddr3.odt),

        .ui_clk                         (ui_clk),
        .ui_clk_sync_rst                (ui_clk_sync_rst),
        .init_calib_complete            (init_calib_complete),
        .mmcm_locked                    (),
        .aresetn                        (~ui_clk_sync_rst),
        .app_sr_req                     (0),
        .app_ref_req                    (0),
        .app_zq_req                     (0),
        .app_sr_active                  (),
        .app_ref_ack                    (),
        .app_zq_ack                     (),

        .s_axi_awid                     (s_axi.awid),
        .s_axi_awaddr                   (s_axi.awaddr),
        .s_axi_awlen                    (s_axi.awlen),
        .s_axi_awsize                   (s_axi.awsize),
        .s_axi_awburst                  (s_axi.awburst),
        .s_axi_awlock                   (s_axi.awlock),
        .s_axi_awcache                  (s_axi.awcache),
        .s_axi_awprot                   (s_axi.awprot),
        .s_axi_awqos                    (s_axi.awqos),
        .s_axi_awvalid                  (s_axi.awvalid),
        .s_axi_awready                  (s_axi.awready),

        .s_axi_wdata                    (s_axi.wdata),
        .s_axi_wstrb                    (s_axi.wstrb),
        .s_axi_wlast                    (s_axi.wlast),
        .s_axi_wvalid                   (s_axi.wvalid),
        .s_axi_wready                   (s_axi.wready),

        .s_axi_bid                      (s_axi.bid),
        .s_axi_bresp                    (s_axi.bresp),
        .s_axi_bvalid                   (s_axi.bvalid),
        .s_axi_bready                   (s_axi.bready),

        .s_axi_arid                     (s_axi.arid),
        .s_axi_araddr                   (s_axi.araddr),
        .s_axi_arlen                    (s_axi.arlen),
        .s_axi_arsize                   (s_axi.arsize),
        .s_axi_arburst                  (s_axi.arburst),
        .s_axi_arlock                   (s_axi.arlock),
        .s_axi_arcache                  (s_axi.arcache),
        .s_axi_arprot                   (s_axi.arprot),
        .s_axi_arqos                    (s_axi.arqos),
        .s_axi_arvalid                  (s_axi.arvalid),
        .s_axi_arready                  (s_axi.arready),

        .s_axi_rid                      (s_axi.rid),
        .s_axi_rdata                    (s_axi.rdata),
        .s_axi_rresp                    (s_axi.rresp),
        .s_axi_rlast                    (s_axi.rlast),
        .s_axi_rvalid                   (s_axi.rvalid),
        .s_axi_rready                   (s_axi.rready),

        .sys_clk_i                      (sys_clk),
        .sys_rst                        (sys_rst)
    );

endmodule