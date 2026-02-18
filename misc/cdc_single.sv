/*

module cdc_single #(
    int   SYNC_STAGES   = 2,
    logic INITIAL_VALUE = 1'b1
)(
    input  clk,
    input  i,
    output o
);

    if (SYNC_STAGES < 2) begin
        $error();
    end

    (* async_reg = "true", shreg_extract = "no" *)
    logic [SYNC_STAGES-1:0] d = {SYNC_STAGES{INITIAL_VALUE}};

    assign o = d[SYNC_STAGES-1];

    always_ff @(posedge clk) d <= {d[SYNC_STAGES-2:0], i};

endmodule

*/

module cdc_single #(
    int   SYNC_STAGES   = 2,
    logic INITIAL_VALUE = 1'b1
)(
    input  clk,
    input  i,
    output o
);
    xpm_cdc_sync_rst #(
        .DEST_SYNC_FF   (SYNC_STAGES),
        .INIT           (INITIAL_VALUE),
        .INIT_SYNC_FF   (0),
        .SIM_ASSERT_CHK (0)
    ) cdc (
        .dest_rst (o),
        .dest_clk (clk),
        .src_rst  (i)
    );

endmodule