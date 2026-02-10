// wrapper for wb2axip/axixbar
// unfinished
module axi_xbar #(
    int NS = 2,
    int NM = 1,
)(
    input clk,
    input rst,

    axi_intf s [NS],
    axi_intf m [NM]
);

    localparam DATA_WIDTH = s[0].DATA_WIDTH;
    localparam ADDR_WIDTH = s[0].ADDR_WIDTH;
    localparam ID_WIDTH   = s[0].ID_WIDTH;

    for (genvar i = 0; i < NS; i++) begin
        if (s[i].DATA_WIDTH != DATA_WIDTH || s[i].ADDR_WIDTH != ADDR_WIDTH || s[i].ID_WIDTH != ID_WIDTH) begin
            $error();
        end
    end

    for (genvar i = 0; i < NM; i++) begin
        if (m[i].DATA_WIDTH != DATA_WIDTH || m[i].ADDR_WIDTH != ADDR_WIDTH || m[i].ID_WIDTH != ID_WIDTH) begin
            $error();
        end
    end

    logic [NS-1:0]              S_AXI_AWVALID;
    logic [NS-1:0]              S_AXI_AWREADY;
    logic [NS*ID_WIDTH-1:0]     S_AXI_AWID;
    logic [NS*ADDR_WIDTH-1:0]   S_AXI_AWADDR;
    logic [NS*8-1:0]            S_AXI_AWLEN;
    logic [NS*3-1:0]            S_AXI_AWSIZE;
    logic [NS*2-1:0]            S_AXI_AWBURST;

    logic [NS-1:0]              S_AXI_AWLOCK;
    logic [NS*4-1:0]            S_AXI_AWCACHE;
    logic [NS*3-1:0]            S_AXI_AWPROT;
    logic [NS*4-1:0]            S_AXI_AWQOS;

    logic [NS-1:0]              S_AXI_WVALID;
    logic [NS-1:0]              S_AXI_WREADY;
    logic [NS*DATA_WIDTH-1:0]   S_AXI_WDATA;
    logic [NS*DATA_WIDTH/8-1:0] S_AXI_WSTRB;
    logic [NS-1:0]              S_AXI_WLAST;

    logic [NS-1:0]              S_AXI_BVALID;
    logic [NS-1:0]              S_AXI_BREADY;
    logic [NS*ID_WIDTH-1:0]     S_AXI_BID;
    logic [NS*2-1:0]            S_AXI_BRESP;

    logic [NS-1:0]              S_AXI_ARVALID;
    logic [NS-1:0]              S_AXI_ARREADY;
    logic [NS*ID_WIDTH-1:0]     S_AXI_ARID;
    logic [NS*ADDR_WIDTH-1:0]   S_AXI_ARADDR;
    logic [NS*8-1:0]            S_AXI_ARLEN;
    logic [NS*3-1:0]            S_AXI_ARSIZE;
    logic [NS*2-1:0]            S_AXI_ARBURST;

    logic [NS-1:0]              S_AXI_ARLOCK;
    logic [NS*4-1:0]            S_AXI_ARCACHE;
    logic [NS*3-1:0]            S_AXI_ARPROT;
    logic [NS*4-1:0]            S_AXI_ARQOS;

    logic [NS-1:0]              S_AXI_RVALID;
    logic [NS-1:0]              S_AXI_RREADY;
    logic [NS*ID_WIDTH-1:0]     S_AXI_RID;
    logic [NS*DATA_WIDTH-1:0]   S_AXI_RDATA;
    logic [NS*2-1:0]            S_AXI_RRESP;
    logic [NS-1:0]              S_AXI_RLAST;

    logic [NM-1:0]              M_AXI_AWVALID;
    logic [NM-1:0]              M_AXI_AWREADY;
    logic [NM*ID_WIDTH-1:0]     M_AXI_AWID;
    logic [NM*ADDR_WIDTH-1:0]   M_AXI_AWADDR;
    logic [NM*8-1:0]            M_AXI_AWLEN;
    logic [NM*3-1:0]            M_AXI_AWSIZE;
    logic [NM*2-1:0]            M_AXI_AWBURST;

    logic [NM-1:0]              M_AXI_AWLOCK;
    logic [NM*4-1:0]            M_AXI_AWCACHE;
    logic [NM*3-1:0]            M_AXI_AWPROT;
    logic [NM*4-1:0]            M_AXI_AWQOS;

    logic [NM-1:0]              M_AXI_WVALID;
    logic [NM-1:0]              M_AXI_WREADY;
    logic [NM*DATA_WIDTH-1:0]   M_AXI_WDATA;
    logic [NM*DATA_WIDTH/8-1:0] M_AXI_WSTRB;
    logic [NM-1:0]              M_AXI_WLAST;

    logic [NM-1:0]              M_AXI_BVALID;
    logic [NM-1:0]              M_AXI_BREADY;
    logic [NM*ID_WIDTH-1:0]     M_AXI_BID;
    logic [NM*2-1:0]            M_AXI_BRESP;

    logic [NM-1:0]              M_AXI_ARVALID;
    logic [NM-1:0]              M_AXI_ARREADY;
    logic [NM*ID_WIDTH-1:0]     M_AXI_ARID;
    logic [NM*ADDR_WIDTH-1:0]   M_AXI_ARADDR;
    logic [NM*8-1:0]            M_AXI_ARLEN;
    logic [NM*3-1:0]            M_AXI_ARSIZE;
    logic [NM*2-1:0]            M_AXI_ARBURST;

    logic [NM-1:0]              M_AXI_ARLOCK;
    logic [NM*4-1:0]            M_AXI_ARCACHE;
    logic [NM*4-1:0]            M_AXI_ARQOS;
    logic [NM*3-1:0]            M_AXI_ARPROT;

    logic [NM-1:0]              M_AXI_RVALID;
    logic [NM-1:0]              M_AXI_RREADY;
    logic [NM*ID_WIDTH-1:0]     M_AXI_RID;
    logic [NM*DATA_WIDTH-1:0]   M_AXI_RDATA;
    logic [NM*2-1:0]            M_AXI_RRESP;
    logic [NM-1:0]              M_AXI_RLAST;

    for (genvar i = 0; i < NS; i++) begin
        assign S_AXI_AWID    [i*(ID_WIDTH)+:(ID_WIDTH)]     = s[i].awid;
        assign S_AXI_AWADDR  [i*(ADDR_WIDTH)+:(ADDR_WIDTH)] = s[i].awaddr;
        assign S_AXI_AWLEN   [i*(8)+:(8)]                   = s[i].awlen;
        assign S_AXI_AWSIZE  [i*(3)+:(3)]                   = s[i].awsize;
        assign S_AXI_AWBURST [i*(2)+:(2)]                   = s[i].awburst;
        assign S_AXI_AWLOCK  [i*(1)+:(1)]                   = s[i].awlock;
        assign S_AXI_AWCACHE [i*(4)+:(4)]                   = s[i].awcache;
        assign S_AXI_AWPROT  [i*(3)+:(3)]                   = s[i].awprot;
        assign S_AXI_AWQOS   [i*(4)+:(4)]                   = s[i].awqos;
        assign S_AXI_AWVALID [i]                            = s[i].awvalid;
        assign s[i].awready                                 = S_AXI_AWREADY[i];

        assign S_AXI_WDATA  [i*(DATA_WIDTH)+:(DATA_WIDTH)]  = s[i].wdata;
        assign S_AXI_WSTRB  [i*(DATA_WIDTH)+:(DATA_WIDTH)]  = s[i].wstrb;
        assign S_AXI_WLAST  [i*(1)+:(1)]                    = s[i].wlast;
        assign S_AXI_WVALID [i]                             = s[i].wvalid;
        assign s[i].wready                                  = S_AXI_WREADY[i];

        assign s[i].bid                                     = S_AXI_BID    [i*(ID_WIDTH)+:(ID_WIDTH)];
        assign s[i].bresp                                   = S_AXI_BRESP  [i*(2)+:(2)];
        assign s[i].bvalid                                  = S_AXI_BVALID [i];
        assign S_AXI_BREADY[i]                              = s[i].bready;

        assign S_AXI_ARID    [i*(ID_WIDTH)+:(ID_WIDTH)]     = s[i].arid;
        assign S_AXI_ARADDR  [i*(ADDR_WIDTH)+:(ADDR_WIDTH)] = s[i].araddr;
        assign S_AXI_ARLEN   [i*(8)+:(8)]                   = s[i].arlen;
        assign S_AXI_ARSIZE  [i*(3)+:(3)]                   = s[i].arsize;
        assign S_AXI_ARBURST [i*(2)+:(2)]                   = s[i].arburst;
        assign S_AXI_ARLOCK  [i*(1)+:(1)]                   = s[i].arlock;
        assign S_AXI_ARCACHE [i*(4)+:(4)]                   = s[i].arcache;
        assign S_AXI_ARPROT  [i*(3)+:(3)]                   = s[i].arprot;
        assign S_AXI_ARQOS   [i*(4)+:(4)]                   = s[i].arqos;
        assign S_AXI_ARVALID [i]                            = s[i].arvalid;
        assign s[i].arready                                 = S_AXI_ARREADY[i];

        assign s[i].rid                                     = S_AXI_RID    [i*(ID_WIDTH)+:(ID_WIDTH)];
        assign s[i].rdata                                   = S_AXI_RDATA  [i*(DATA_WIDTH)+:(DATA_WIDTH)];
        assign s[i].rresp                                   = S_AXI_RRESP  [i*(2)+:(2)];
        assign s[i].rlast                                   = S_AXI_RLAST  [i*(1)+:(1)];
        assign s[i].rvalid                                  = S_AXI_RVALID [i];
        assign S_AXI_RREADY[i]                              = s[i].rready;
    end

    for (genvar i = 0; i < NM; i++) begin
        assign m[i].awid                                   = M_AXI_AWID    [i*(ID_WIDTH)+:(ID_WIDTH)];
        assign m[i].awaddr                                 = M_AXI_AWADDR  [i*(ADDR_WIDTH)+:(ADDR_WIDTH)];
        assign m[i].awlen                                  = M_AXI_AWLEN   [i*(8)+:(8)];
        assign m[i].awsize                                 = M_AXI_AWSIZE  [i*(3)+:(3)];
        assign m[i].awburst                                = M_AXI_AWBURST [i*(2)+:(2)];
        assign m[i].awlock                                 = M_AXI_AWLOCK  [i*(1)+:(1)];
        assign m[i].awcache                                = M_AXI_AWCACHE [i*(4)+:(4)];
        assign m[i].awprot                                 = M_AXI_AWPROT  [i*(3)+:(3)];
        assign m[i].awqos                                  = M_AXI_AWQOS   [i*(4)+:(4)];
        assign m[i].awvalid                                = M_AXI_AWVALID [i];
        assign M_AXI_AWREADY[i]                            = m[i].awready;

        assign m[i].wdata                                  = M_AXI_WDATA  [i*(DATA_WIDTH)+:(DATA_WIDTH)];
        assign m[i].wstrb                                  = M_AXI_WSTRB  [i*(DATA_WIDTH)+:(DATA_WIDTH)];
        assign m[i].wlast                                  = M_AXI_WLAST  [i*(1)+:(1)];
        assign m[i].wvalid                                 = M_AXI_WVALID [i];
        assign M_AXI_WREADY[i]                             = m[i].wready;

        assign M_AXI_BID    [i*(ID_WIDTH)+:(ID_WIDTH)]     = m[i].bid;
        assign M_AXI_BRESP  [i*(2)+:(2)]                   = m[i].bresp;
        assign M_AXI_BVALID [i]                            = m[i].bvalid;
        assign m[i].bready                                 = M_AXI_BREADY[i];

        assign  m[i].arid                                  = M_AXI_ARID    [i*(ID_WIDTH)+:(ID_WIDTH)];
        assign  m[i].araddr                                = M_AXI_ARADDR  [i*(ADDR_WIDTH)+:(ADDR_WIDTH)];
        assign  m[i].arlen                                 = M_AXI_ARLEN   [i*(8)+:(8)];
        assign  m[i].arsize                                = M_AXI_ARSIZE  [i*(3)+:(3)];
        assign  m[i].arburst                               = M_AXI_ARBURST [i*(2)+:(2)];
        assign  m[i].arlock                                = M_AXI_ARLOCK  [i*(1)+:(1)];
        assign  m[i].arcache                               = M_AXI_ARCACHE [i*(4)+:(4)];
        assign  m[i].arprot                                = M_AXI_ARPROT  [i*(3)+:(3)];
        assign  m[i].arqos                                 = M_AXI_ARQOS   [i*(4)+:(4)];
        assign  m[i].arvalid                               = M_AXI_ARVALID [i];
        assign  M_AXI_ARREADY[i]                           = m[i].arready;

        assign M_AXI_RID    [i*(ID_WIDTH)+:(ID_WIDTH)]     = m[i].rid;
        assign M_AXI_RDATA  [i*(DATA_WIDTH)+:(DATA_WIDTH)] = m[i].rdata;
        assign M_AXI_RRESP  [i*(2)+:(2)]                   = m[i].rresp;
        assign M_AXI_RLAST  [i*(1)+:(1)]                   = m[i].rlast;
        assign M_AXI_RVALID [i]                            = m[i].rvalid;
        assign m[i].rready                                 = M_AXI_RREADY[i];
    end

    axixbar #(
        .C_AXI_DATA_WIDTH (DATA_WIDTH),
        .C_AXI_ADDR_WIDTH (ADDR_WIDTH),
        .C_AXI_ID_WIDTH   (ID_WIDTH),
        .NM               (NS),
        .NS               (NM),
        //
        // SLAVE_ADDR is an array of addresses, describing each of
        // {{{
        // the slave channels.  It works tightly with SLAVE_MASK,
        // so that when (ADDR & MASK == ADDR), the channel in question
        // has been requested.
        //
        // It is an internal in the setup of this core to doubly map
        // an address, such that (addr & SLAVE_MASK[k])==SLAVE_ADDR[k]
        // for two separate values of k.
        //
        // Any attempt to access an address that is a hole in this
        // address list will result in a returned xRESP value of
        // INTERCONNECT_ERROR (2'b11)
        //
        // NOTE: This is only a nominal address set.  I expect that
        // any design using the crossbar will need to adjust both
        // SLAVE_ADDR and SLAVE_MASK, if not also NM and NS.
        parameter    [NS*C_AXI_ADDR_WIDTH-1:0]    SLAVE_ADDR = {
            3'b111,  {(C_AXI_ADDR_WIDTH-3){1'b0}},
            3'b110,  {(C_AXI_ADDR_WIDTH-3){1'b0}},
            3'b101,  {(C_AXI_ADDR_WIDTH-3){1'b0}},
            3'b100,  {(C_AXI_ADDR_WIDTH-3){1'b0}},
            3'b011,  {(C_AXI_ADDR_WIDTH-3){1'b0}},
            3'b010,  {(C_AXI_ADDR_WIDTH-3){1'b0}},
            4'b0001, {(C_AXI_ADDR_WIDTH-4){1'b0}},
            4'b0000, {(C_AXI_ADDR_WIDTH-4){1'b0}} },
        // }}}
        //
        // SLAVE_MASK: is an array, much like SLAVE_ADDR, describing
        // {{{
        // which of the bits in SLAVE_ADDR are relevant.  It is
        // important to maintain for every slave that
        //     (~SLAVE_MASK[i] & SLAVE_ADDR[i]) == 0.
        //
        // NOTE: This value should be overridden by any implementation.
        // Verilator lint_off WIDTH
        parameter    [NS*C_AXI_ADDR_WIDTH-1:0]    SLAVE_MASK = {
            3'b111,  {(C_AXI_ADDR_WIDTH-3){1'b0}},
            3'b111,  {(C_AXI_ADDR_WIDTH-3){1'b0}},
            3'b111,  {(C_AXI_ADDR_WIDTH-3){1'b0}},
            3'b111,  {(C_AXI_ADDR_WIDTH-3){1'b0}},
            3'b111,  {(C_AXI_ADDR_WIDTH-3){1'b0}},
            3'b111,  {(C_AXI_ADDR_WIDTH-3){1'b0}},
            4'b1111, {(C_AXI_ADDR_WIDTH-4){1'b0}},
            4'b1111, {(C_AXI_ADDR_WIDTH-4){1'b0}} },
        // Verilator lint_on  WIDTH
        // }}}
        //
        // OPT_LOWPOWER: If set, it forces all unused values to zero,
        // {{{
        // preventing them from unnecessarily toggling.  This will
        // raise the logic count of the core, but might also lower
        // the power used by the interconnect and the bus driven wires
        // which (in my experience) tend to have a high fan out.
        parameter [0:0]    OPT_LOWPOWER = 0,
        // }}}
        //
        // OPT_LINGER: Set this to the number of clocks an idle
        // {{{
        // channel shall be left open before being closed.  Once
        // closed, it will take a minimum of two clocks before the
        // channel can be opened and data transmitted through it again.
        parameter    OPT_LINGER = 4,
        // }}}
        //
        // [EXPERIMENTAL] OPT_QOS: If set, the QOS transmission values
        // {{{
        // will be honored when determining who wins arbitration for
        // accessing a given slave.  (This feature has not yet been
        // verified)
        .OPT_QOS (0),
        // }}}
        //
        // LGMAXBURST: Specifies the log based two of the maximum
        // {{{
        // number of bursts transactions that may be outstanding at any
        // given time.  This is different from the maximum number of
        // outstanding beats.
        .LGMAXBURST (3),

    ) (
        .S_AXI_ACLK     (clk),
        .S_AXI_ARESETN  (~rst),

        .S_AXI_AWVALID  (S_AXI_AWVALID),
        .S_AXI_AWREADY  (S_AXI_AWREADY),
        .S_AXI_AWID     (S_AXI_AWID),
        .S_AXI_AWADDR   (S_AXI_AWADDR),
        .S_AXI_AWLEN    (S_AXI_AWLEN),
        .S_AXI_AWSIZE   (S_AXI_AWSIZE),
        .S_AXI_AWBURST  (S_AXI_AWBURST),

        .S_AXI_AWLOCK   (S_AXI_AWLOCK),
        .S_AXI_AWCACHE  (S_AXI_AWCACHE),
        .S_AXI_AWPROT   (S_AXI_AWPROT),
        .S_AXI_AWQOS    (S_AXI_AWQOS),

        .S_AXI_WVALID   (S_AXI_WVALID),
        .S_AXI_WREADY   (S_AXI_WREADY),
        .S_AXI_WDATA    (S_AXI_WDATA),
        .S_AXI_WSTRB    (S_AXI_WSTRB),
        .S_AXI_WLAST    (S_AXI_WLAST),

        .S_AXI_BVALID   (S_AXI_BVALID),
        .S_AXI_BREADY   (S_AXI_BREADY),
        .S_AXI_BID      (S_AXI_BID),
        .S_AXI_BRESP    (S_AXI_BRESP),

        .S_AXI_ARVALID  (S_AXI_ARVALID),
        .S_AXI_ARREADY  (S_AXI_ARREADY),
        .S_AXI_ARID     (S_AXI_ARID),
        .S_AXI_ARADDR   (S_AXI_ARADDR),
        .S_AXI_ARLEN    (S_AXI_ARLEN),
        .S_AXI_ARSIZE   (S_AXI_ARSIZE),
        .S_AXI_ARBURST  (S_AXI_ARBURST),

        .S_AXI_ARLOCK   (S_AXI_ARLOCK),
        .S_AXI_ARCACHE  (S_AXI_ARCACHE),
        .S_AXI_ARPROT   (S_AXI_ARPROT),
        .S_AXI_ARQOS    (S_AXI_ARQOS),

        .S_AXI_RVALID   (S_AXI_RVALID),
        .S_AXI_RREADY   (S_AXI_RREADY),
        .S_AXI_RID      (S_AXI_RID),
        .S_AXI_RDATA    (S_AXI_RDATA),
        .S_AXI_RRESP    (S_AXI_RRESP),
        .S_AXI_RLAST    (S_AXI_RLAST),

        .M_AXI_AWVALID  (M_AXI_AWVALID),
        .M_AXI_AWREADY  (M_AXI_AWREADY),
        .M_AXI_AWID     (M_AXI_AWID),
        .M_AXI_AWADDR   (M_AXI_AWADDR),
        .M_AXI_AWLEN    (M_AXI_AWLEN),
        .M_AXI_AWSIZE   (M_AXI_AWSIZE),
        .M_AXI_AWBURST  (M_AXI_AWBURST),
        .M_AXI_AWLOCK   (M_AXI_AWLOCK),
        .M_AXI_AWCACHE  (M_AXI_AWCACHE),
        .M_AXI_AWPROT   (M_AXI_AWPROT),
        .M_AXI_AWQOS    (M_AXI_AWQOS),

        .M_AXI_WVALID   (M_AXI_WVALID),
        .M_AXI_WREADY   (M_AXI_WREADY),
        .M_AXI_WDATA    (M_AXI_WDATA),
        .M_AXI_WSTRB    (M_AXI_WSTRB),
        .M_AXI_WLAST    (M_AXI_WLAST),

        .M_AXI_BVALID   (M_AXI_BVALID),
        .M_AXI_BREADY   (M_AXI_BREADY),
        .M_AXI_BID      (M_AXI_BID),
        .M_AXI_BRESP    (M_AXI_BRESP),

        .M_AXI_ARVALID  (M_AXI_ARVALID),
        .M_AXI_ARREADY  (M_AXI_ARREADY),
        .M_AXI_ARID     (M_AXI_ARID),
        .M_AXI_ARADDR   (M_AXI_ARADDR),
        .M_AXI_ARLEN    (M_AXI_ARLEN),
        .M_AXI_ARSIZE   (M_AXI_ARSIZE),
        .M_AXI_ARBURST  (M_AXI_ARBURST),

        .M_AXI_ARLOCK   (M_AXI_ARLOCK),
        .M_AXI_ARCACHE  (M_AXI_ARCACHE),
        .M_AXI_ARQOS    (M_AXI_ARQOS),
        .M_AXI_ARPROT   (M_AXI_ARPROT),

        .M_AXI_RVALID   (M_AXI_RVALID),
        .M_AXI_RREADY   (M_AXI_RREADY),
        .M_AXI_RID      (M_AXI_RID),
        .M_AXI_RDATA    (M_AXI_RDATA),
        .M_AXI_RRESP    (M_AXI_RRESP),
        .M_AXI_RLAST    (M_AXI_RLAST)
    );


endmodule