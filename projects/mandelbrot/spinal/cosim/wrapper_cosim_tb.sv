// Co-simulation: original SV wrapper vs SpinalHDL-generated sp_Wrapper.
// The arbiters choose differently, so packets from different cores interleave differently;
// the check is that every address receives exactly the same bursts, in the same order.
// Run with cosim/run_wrapper.sh, which generates sp_Wrapper with matching parameters.

// Takes m_addr / m_data with random backpressure and stores packets per address.
module packet_collector #(
    parameter int DATA_WIDTH   = 32,
    parameter int BURST_LENGTH = 8
)(
    input  logic                  clk,
    input  logic                  rst,
    input  logic                  addr_valid,
    output logic                  addr_ready,
    input  logic [31:0]           addr_data,
    input  logic                  data_valid,
    output logic                  data_ready,
    input  logic [DATA_WIDTH-1:0] data_data,
    input  logic                  data_last
);
    typedef logic [BURST_LENGTH*16-1:0] pkt_t;

    pkt_t        pkts [logic [31:0]][$];
    logic [31:0] addrs[$];
    pkt_t        cur   = '0;
    pkt_t        next;
    int          beat  = 0;
    int          count = 0;

    always @(posedge clk) begin
        addr_ready <= $urandom_range(0, 3) != 0;
        data_ready <= $urandom_range(0, 3) != 0;
        if (!rst && addr_valid && addr_ready) addrs.push_back(addr_data);
        if (!rst && data_valid && data_ready) begin
            next = cur | (pkt_t'(data_data) << (beat * DATA_WIDTH));
            if (data_last) begin
                if (addrs.size() == 0) begin
                    $display("FAIL %m: data packet without address");
                    $fatal(1);
                end
                if ((beat + 1) * DATA_WIDTH != BURST_LENGTH * 16) begin
                    $display("FAIL %m: packet of %0d beats", beat + 1);
                    $fatal(1);
                end
                pkts[addrs.pop_front()].push_back(next);
                cur   <= '0;
                beat  <= 0;
                count <= count + 1;
            end else begin
                cur  <= next;
                beat <= beat + 1;
            end
        end
    end
endmodule

module wrapper_cosim_tb #(
    parameter int          X_RES             = 16,
    parameter int          Y_RES             = 8,
    parameter int          FRAC_WIDTH        = 8,
    parameter int          NCORES            = 4,
    parameter int          ARBITER_TREE_SANS = 2,
    parameter int          BURST_LENGTH      = 8,
    parameter logic [31:0] FB_START_ADDR     = 32'h0001_0000,
    parameter int          DATA_WIDTH        = 32
);
    localparam int PER_VIEW = X_RES * Y_RES / BURST_LENGTH;
    localparam int VIEWS    = 5;

    logic clk = 0;
    logic rst = 1;
    always #5 clk = ~clk;

    // view list; a view is sent only after the previous one is finished when its maxIt
    // differs (the cores read maxIt live, so overlap would make the result timing dependent)
    real cx    [VIEWS] = '{-0.75, -0.5, -0.8,  3.5, -0.9};
    real cy    [VIEWS] = '{ 0.0,   0.5,  0.2, -3.5,  0.3};
    real width [VIEWS] = '{ 2.5,   1.0,  0.6,  4.0,  0.5};
    int  max_it[VIEWS] = '{ 40,    40,   100,  1,    300};

    function automatic logic [2:-FRAC_WIDTH] fix(real v);
        return $rtoi(v * (2.0 ** FRAC_WIDTH));
    endfunction

    // ------------------------------------------------------------ original SV
    logic                 sv_s_ready, sv_s_valid = 0;
    logic [2:-FRAC_WIDTH] sv_cx, sv_cy, sv_step;
    logic [15:0]          sv_max_it;
    axis_intf #(32, 0)         sv_m_addr ();
    axis_intf #(DATA_WIDTH, 1) sv_m_data ();

    wrapper #(
        .X_RES             (X_RES),
        .Y_RES             (Y_RES),
        .FRAC_WIDTH        (FRAC_WIDTH),
        .NCORES            (NCORES),
        .ARBITER_TREE_SANS (ARBITER_TREE_SANS),
        .BURST_LENGTH      (BURST_LENGTH),
        .FB_START_ADDR     (FB_START_ADDR)
    ) sv_dut (
        .clk        (clk),
        .rst        (rst),
        .s_ready    (sv_s_ready),
        .s_valid    (sv_s_valid),
        .s_max_it   (sv_max_it),
        .s_center_x (sv_cx),
        .s_center_y (sv_cy),
        .s_xy_step  (sv_step),
        .m_addr     (sv_m_addr),
        .m_data     (sv_m_data)
    );

    packet_collector #(DATA_WIDTH, BURST_LENGTH) sv_out (
        .clk        (clk),
        .rst        (rst),
        .addr_valid (sv_m_addr.valid),
        .addr_ready (sv_m_addr.ready),
        .addr_data  (sv_m_addr.data),
        .data_valid (sv_m_data.valid),
        .data_ready (sv_m_data.ready),
        .data_data  (sv_m_data.data),
        .data_last  (sv_m_data.last)
    );

    // ------------------------------------------------------------ SpinalHDL
    logic                 sp_s_ready, sp_s_valid = 0;
    logic [2:-FRAC_WIDTH] sp_cx, sp_cy, sp_step;
    logic [15:0]          sp_max_it;
    logic                 sp_addr_valid, sp_addr_ready, sp_data_valid, sp_data_ready, sp_data_last;
    logic [31:0]          sp_addr_data;
    logic [DATA_WIDTH-1:0] sp_data_data;

    sp_Wrapper sp_dut (
        .clk          (clk),
        .rst          (rst),
        .s_valid      (sp_s_valid),
        .s_ready      (sp_s_ready),
        .s_center_x   (sp_cx),
        .s_center_y   (sp_cy),
        .s_xy_step    (sp_step),
        .s_max_it     (sp_max_it),
        .m_addr_valid (sp_addr_valid),
        .m_addr_ready (sp_addr_ready),
        .m_addr_data  (sp_addr_data),
        .m_data_valid (sp_data_valid),
        .m_data_ready (sp_data_ready),
        .m_data_last  (sp_data_last),
        .m_data_data  (sp_data_data)
    );

    packet_collector #(DATA_WIDTH, BURST_LENGTH) sp_out (
        .clk        (clk),
        .rst        (rst),
        .addr_valid (sp_addr_valid),
        .addr_ready (sp_addr_ready),
        .addr_data  (sp_addr_data),
        .data_valid (sp_data_valid),
        .data_ready (sp_data_ready),
        .data_data  (sp_data_data),
        .data_last  (sp_data_last)
    );

    // ------------------------------------------------------------ stimulus (each DUT at its own pace)
    // Inputs change on the falling edge, so they never race the rising edge the DUTs sample on.
    task automatic send_sv(int k);
        @(negedge clk);
        sv_cx = fix(cx[k]); sv_cy = fix(cy[k]); sv_step = fix(width[k] / X_RES); sv_max_it = max_it[k];
        sv_s_valid = 1;
        do @(posedge clk); while (!sv_s_ready);
        @(negedge clk);
        sv_s_valid = 0;
    endtask

    task automatic send_sp(int k);
        @(negedge clk);
        sp_cx = fix(cx[k]); sp_cy = fix(cy[k]); sp_step = fix(width[k] / X_RES); sp_max_it = max_it[k];
        sp_s_valid = 1;
        do @(posedge clk); while (!sp_s_ready);
        @(negedge clk);
        sp_s_valid = 0;
    endtask

    initial begin
        repeat (5) @(posedge clk);
        rst <= 0;
        for (int k = 0; k < VIEWS; k++) begin
            if (k > 0 && max_it[k] != max_it[k-1])
                wait (sv_out.count == k * PER_VIEW && sp_out.count == k * PER_VIEW);
            fork
                send_sv(k);
                send_sp(k);
            join
            $display("[%0t] view %0d accepted by both (packets so far: sv %0d, spinal %0d)", $time, k, sv_out.count, sp_out.count);
        end
        wait (sv_out.count == VIEWS * PER_VIEW && sp_out.count == VIEWS * PER_VIEW);
        repeat (500) @(posedge clk);
        compare();
        $finish;
    end

    task automatic compare();
        int addresses = 0;
        if (sv_out.count != sp_out.count || sv_out.count != VIEWS * PER_VIEW) begin
            $display("FAIL: packet counts sv=%0d spinal=%0d expected=%0d", sv_out.count, sp_out.count, VIEWS * PER_VIEW);
            $fatal(1);
        end
        if (sv_out.pkts.size() != sp_out.pkts.size()) begin
            $display("FAIL: %0d addresses in sv, %0d in spinal", sv_out.pkts.size(), sp_out.pkts.size());
            $fatal(1);
        end
        foreach (sv_out.pkts[a]) begin
            if (!sp_out.pkts.exists(a) || sp_out.pkts[a].size() != sv_out.pkts[a].size()) begin
                $display("FAIL: address %h written %0d times by sv, %0d by spinal", a,
                         sv_out.pkts[a].size(), sp_out.pkts.exists(a) ? sp_out.pkts[a].size() : 0);
                $fatal(1);
            end
            foreach (sv_out.pkts[a][i])
                if (sv_out.pkts[a][i] !== sp_out.pkts[a][i]) begin
                    $display("FAIL: address %h burst %0d:\n  sv     %h\n  spinal %h", a, i,
                             sv_out.pkts[a][i], sp_out.pkts[a][i]);
                    $fatal(1);
                end
            addresses++;
        end
        $display("PASS: %0d packets to %0d addresses identical (finished at %0t)", sv_out.count, addresses, $time);
    endtask

    initial begin
        #200ms;
        $display("FAIL: timeout (sv %0d, spinal %0d packets)", sv_out.count, sp_out.count);
        $fatal(1);
    end

endmodule
