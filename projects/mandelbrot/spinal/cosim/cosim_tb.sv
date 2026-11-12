// Cycle-exact co-simulation: original SV core_wrapper vs SpinalHDL-generated sp_CoreWrapper.
// Both get the same inputs and the same random m_ready; outputs must match every cycle.
// Run with cosim/run.sh, which generates sp_CoreWrapper with matching parameters.
module cosim_tb #(
    parameter logic [31:0] START_ADDR = 32'h0000_FFC0,
    parameter int          X_RES      = 16,
    parameter int          Y_RES      = 8,
    parameter int          N          = 8,
    parameter int          FRAC_WIDTH = 8
);

    localparam int FRAMES   = 5;
    localparam int EXPECTED = FRAMES * (X_RES * Y_RES / N) * (N + 2);

    logic clk = 0;
    logic rst = 1;
    always #5 clk = ~clk;

    logic                 s_valid = 0;
    logic [2:-FRAC_WIDTH] s_x_start, s_y_start, s_xy_step;
    logic [15:0]          s_max_it;
    logic                 m_ready = 0;

    // ------------------------------------------------------------ original SV
    logic ref_s_ready;
    axis_intf #(16, 1) ref_m ();
    assign ref_m.ready = m_ready;

    core_wrapper #(
        .START_ADDR (START_ADDR),
        .X_RES      (X_RES),
        .Y_RES      (Y_RES),
        .N          (N),
        .FRAC_WIDTH (FRAC_WIDTH)
    ) ref_cw (
        .clk       (clk),
        .rst       (rst),
        .s_ready   (ref_s_ready),
        .s_valid   (s_valid),
        .s_x_start (s_x_start),
        .s_y_start (s_y_start),
        .s_xy_step (s_xy_step),
        .s_max_it  (s_max_it),
        .m         (ref_m)
    );

    // ------------------------------------------------------------ SpinalHDL
    logic        sp_s_ready, sp_m_valid, sp_m_last;
    logic [15:0] sp_m_data;

    sp_CoreWrapper sp_cw (
        .clk       (clk),
        .rst       (rst),
        .s_valid   (s_valid),
        .s_ready   (sp_s_ready),
        .s_x_start (s_x_start),
        .s_y_start (s_y_start),
        .s_xy_step (s_xy_step),
        .s_max_it  (s_max_it),
        .m_valid   (sp_m_valid),
        .m_ready   (m_ready),
        .m_last    (sp_m_last),
        .m_data    (sp_m_data)
    );

    // ------------------------------------------------------------ compare
    int words  = 0;
    int cycles = 0;
    int max_seen = 0;

    always @(negedge clk) if (!rst) begin
        if (ref_s_ready !== sp_s_ready)
            fail($sformatf("s_ready: sv=%b spinal=%b", ref_s_ready, sp_s_ready));
        if (ref_m.valid !== sp_m_valid)
            fail($sformatf("m_valid: sv=%b spinal=%b", ref_m.valid, sp_m_valid));
        if (ref_m.valid && (ref_m.data !== sp_m_data || ref_m.last !== sp_m_last))
            fail($sformatf("word %0d: sv=%h/%b spinal=%h/%b", words, ref_m.data, ref_m.last, sp_m_data, sp_m_last));
    end

    int pos = 0; // word position in the packet: 0, 1 = address, then N iteration counts

    always @(posedge clk) begin
        cycles <= cycles + 1;
        m_ready <= $urandom_range(0, 3) != 0; // 75% ready
        if (!rst && ref_m.valid && m_ready) begin
            words <= words + 1;
            pos   <= ref_m.last ? 0 : pos + 1;
            if (pos >= 2 && ref_m.data > max_seen) max_seen <= ref_m.data;
        end
    end

    task automatic fail(string msg);
        $display("FAIL at cycle %0d: %s", cycles, msg);
        $fatal(1);
    endtask

    // ------------------------------------------------------------ stimulus
    function automatic logic [2:-FRAC_WIDTH] fix(real v);
        return $rtoi(v * (2.0 ** FRAC_WIDTH));
    endfunction

    task automatic frame(real x0, real y0, real width, int max_it);
        s_x_start <= fix(x0);
        s_y_start <= fix(y0);
        s_xy_step <= fix(width / X_RES);
        s_max_it  <= max_it;
        s_valid   <= 1;
        @(posedge clk iff ref_s_ready);
        s_valid   <= 0;
        // at least one cycle: the next frame's `s_valid <= 1` must not land in this time step
        repeat ($urandom_range(1, 20)) @(posedge clk);
    endtask

    initial begin
        repeat (5) @(posedge clk);
        rst <= 0;
        // new commands are sent as soon as the wrapper is ready, so maxIt also
        // changes while the previous frame's last batch is still computing
        frame(-2.0,   1.0,  2.5,   40);
        frame(-1.0,   0.4,  0.6,  100);
        frame( 3.5,  -3.5,  4.0,    1);  // coordinates wrap around, maxIt = 1
        frame(-0.9,   0.3,  0.5,  300);  // mostly inside the set: long iterations
        frame(-2.0,   1.0,  2.5,    7);
        wait (words == EXPECTED);
        repeat (200) @(posedge clk);     // no extra words may follow
        if (words != EXPECTED) fail($sformatf("got %0d words, expected %0d", words, EXPECTED));
        $display("PASS: %0d words in %0d cycles identical (max iteration count seen: %0d)",
                 words, cycles, max_seen);
        $finish;
    end

    initial begin
        #50ms;
        fail("timeout");
    end

endmodule
