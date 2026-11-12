// unfinished
module axil_xbar #(
    int N_SLAVES  = 2,
    int N_MASTERS = 1
)(
    axil_intf s[N_SLAVES],
    axis_intf m[N_MASTERS]
);

    axilxbar #(
		// {{{
		parameter integer C_AXI_DATA_WIDTH = 32,
		parameter integer C_AXI_ADDR_WIDTH = 32,
		//
		// NM is the number of master interfaces this core supports
		parameter	NM = 4,
		//
		// NS is the number of slave interfaces
		parameter	NS = 8,
		//
		// AW, and DW, are short-hand abbreviations used locally.
		localparam	AW = C_AXI_ADDR_WIDTH,
		localparam	DW = C_AXI_DATA_WIDTH,
		// SLAVE_ADDR is a bit vector containing AW bits for each of the
		// slaves indicating the base address of the slave.  This
		// goes with SLAVE_MASK below.
		parameter	[NS*AW-1:0]	SLAVE_ADDR = {
			3'b111,  {(AW-3){1'b0}},
			3'b110,  {(AW-3){1'b0}},
			3'b101,  {(AW-3){1'b0}},
			3'b100,  {(AW-3){1'b0}},
			3'b011,  {(AW-3){1'b0}},
			3'b010,  {(AW-3){1'b0}},
			4'b0001, {(AW-4){1'b0}},
			4'b0000, {(AW-4){1'b0}} },
		//
		// SLAVE_MASK indicates which bits in the SLAVE_ADDR bit vector
		// need to be checked to determine if a given address request
		// maps to the given slave or not
		// Verilator lint_off WIDTH
		parameter	[NS*AW-1:0]	SLAVE_MASK =
			(NS <= 1) ? { 4'b1111, {(AW-4){1'b0}} }
			: { {(NS-2){ 3'b111, {(AW-3){1'b0}} }},
				{(2){ 4'b1111, {(AW-4){1'b0}} }} },
		// Verilator lint_on WIDTH
		//
		// If set, OPT_LOWPOWER will set all unused registers, both
		// internal and external, to zero anytime their corresponding
		// *VALID bit is clear
		parameter [0:0]	OPT_LOWPOWER = 1,
		//
		// OPT_LINGER is the number of cycles to wait, following a
		// transaction, before tearing down the bus grant.
		parameter	OPT_LINGER = 4,
		//
		// LGMAXBURST is the log (base two) of the maximum number of
		// requests that can be outstanding on any given channel at any
		// given time.  It is used within this core to control the
		// counters that are used to determine if a particular channel
		// grant must stay open, or if it may be closed.
		parameter	LGMAXBURST = 5
		// }}}
	) (
		// {{{
		input	wire	S_AXI_ACLK,
		input	wire	S_AXI_ARESETN,
		// Incoming AXI4-lite slave port(s)
		// {{{
		input	wire	[NM-1:0]			S_AXI_AWVALID,
		output	wire	[NM-1:0]			S_AXI_AWREADY,
		input	wire	[NM*C_AXI_ADDR_WIDTH-1:0]	S_AXI_AWADDR,
		// Verilator coverage_off
		input	wire	[NM*3-1:0]			S_AXI_AWPROT,
		// Verilator coverage_on
		//
		input	wire	[NM-1:0]			S_AXI_WVALID,
		output	wire	[NM-1:0]			S_AXI_WREADY,
		input	wire	[NM*C_AXI_DATA_WIDTH-1:0]	S_AXI_WDATA,
		input	wire	[NM*C_AXI_DATA_WIDTH/8-1:0]	S_AXI_WSTRB,
		//
		output	wire	[NM-1:0]			S_AXI_BVALID,
		input	wire	[NM-1:0]			S_AXI_BREADY,
		output	wire	[NM*2-1:0]			S_AXI_BRESP,
		//
		input	wire	[NM-1:0]			S_AXI_ARVALID,
		output	wire	[NM-1:0]			S_AXI_ARREADY,
		input	wire	[NM*C_AXI_ADDR_WIDTH-1:0]	S_AXI_ARADDR,
		// Verilator coverage_off
		input	wire	[NM*3-1:0]			S_AXI_ARPROT,
		// Verilator coverage_on
		//
		output	wire	[NM-1:0]			S_AXI_RVALID,
		input	wire	[NM-1:0]			S_AXI_RREADY,
		output	wire	[NM*C_AXI_DATA_WIDTH-1:0]	S_AXI_RDATA,
		output	wire	[NM*2-1:0]			S_AXI_RRESP,
		// }}}
		// Outgoing AXI4-lite master port(s)
		// {{{
		output	wire	[NS*C_AXI_ADDR_WIDTH-1:0]	M_AXI_AWADDR,
		output	wire	[NS*3-1:0]			M_AXI_AWPROT,
		output	wire	[NS-1:0]			M_AXI_AWVALID,
		input	wire	[NS-1:0]			M_AXI_AWREADY,
		//
		output	wire	[NS*C_AXI_DATA_WIDTH-1:0]	M_AXI_WDATA,
		output	wire	[NS*C_AXI_DATA_WIDTH/8-1:0]	M_AXI_WSTRB,
		output	wire	[NS-1:0]			M_AXI_WVALID,
		input	wire	[NS-1:0]			M_AXI_WREADY,
		//
		input	wire	[NS*2-1:0]			M_AXI_BRESP,
		input	wire	[NS-1:0]			M_AXI_BVALID,
		output	wire	[NS-1:0]			M_AXI_BREADY,
		//
		output	wire	[NS*C_AXI_ADDR_WIDTH-1:0]	M_AXI_ARADDR,
		output	wire	[NS*3-1:0]			M_AXI_ARPROT,
		output	wire	[NS-1:0]			M_AXI_ARVALID,
		input	wire	[NS-1:0]			M_AXI_ARREADY,
		//
		input	wire	[NS*C_AXI_DATA_WIDTH-1:0]	M_AXI_RDATA,
		input	wire	[NS*2-1:0]			M_AXI_RRESP,
		input	wire	[NS-1:0]			M_AXI_RVALID,
		output	wire	[NS-1:0]			M_AXI_RREADY
		// }}}
		// }}}
	);

endmodule