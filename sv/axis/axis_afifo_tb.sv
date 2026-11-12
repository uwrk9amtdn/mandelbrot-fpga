module tb;

    axis_intf #(8, 1) s ();

    axis_intf #(8, 1) m ();

    axis_afifo #(
        .SYNC_STAGES (4),
        .DEPTH       (32)
    ) f (
        .arst  (),

        .s_clk (),
        .m_clk (),

        .s     (s),
        .m     (m)
    );

endmodule