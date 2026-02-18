interface ddr3_intf #(
    DM_BITS    = 8,
    BA_BITS    = 3,
    ROW_BITS   = 14,
    COL_BITS   = 10,
    DQ_BITS    = 64,
    DQS_BITS   = 8
);
    logic                rst_n;
    logic                ck;
    logic                ck_n;
    logic                cke;
    logic                cs_n;
    logic                ras_n;
    logic                cas_n;
    logic                we_n;
    logic [DM_BITS-1:0]  dm;
    logic [BA_BITS-1:0]  ba;
    logic [ROW_BITS-1:0] addr;
    wire  [DQ_BITS-1:0]  dq;
    wire  [DQS_BITS-1:0] dqs;
    wire  [DQS_BITS-1:0] dqs_n;
    logic                odt;
endinterface