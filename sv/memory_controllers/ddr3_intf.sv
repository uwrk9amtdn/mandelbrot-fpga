interface ddr3_intf #(
    DM_BITS    = 8,
    BA_BITS    = 3,
    ROW_BITS   = 14,
    COL_BITS   = 10,
    DQ_BITS    = 64,
    DQS_BITS   = 8
)(
    output logic                rst_n,
    output logic                ck,
    output logic                ck_n,
    output logic                cke,
    output logic                cs_n,
    output logic                ras_n,
    output logic                cas_n,
    output logic                we_n,
    output logic [DM_BITS-1:0]  dm,
    output logic [BA_BITS-1:0]  ba,
    output logic [ROW_BITS-1:0] addr,
    inout  logic [DQ_BITS-1:0]  dq,
    inout  logic [DQS_BITS-1:0] dqs,
    inout  logic [DQS_BITS-1:0] dqs_n,
    output logic                odt
);
endinterface