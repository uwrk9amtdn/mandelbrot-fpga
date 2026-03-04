module memory_reader #(
    bit [31:0] START_ADDR   = 0,
    int        AXI_ID       = 0,
    int        COUNT        = 1920 * 1080,
    int        BURST_LENGTH = 128
)(
    input clk,
    input rst,

    output s_ready,
    input  s_valid,

    axi_intf m_axi,

    axis_intf m_axis
);

    if (m_axi.DATA_WIDTH < 16 || m_axi.DATA_WIDTH % 16 != 0) begin
        $error();
    end

    if (m_axis.DATA_WIDTH % 16 != 0 || m_axis.LAST_EN != 0) begin
        $error();
    end

    localparam int N = m_axi.DATA_WIDTH / 16;

    if (COUNT < (BURST_LENGTH * N) || COUNT % (BURST_LENGTH * N) != 0) begin
        $error();
    end

    localparam int NB = COUNT / (BURST_LENGTH * N);

    logic [$clog2(NB)-1:0] ctr;

    axis_intf #(m_axi.DATA_WIDTH, 1) wc_s ();
    axis_intf #(m_axis.DATA_WIDTH, 1) wc_m ();

    assign wc_m.ready   = m_axis.ready;
    assign m_axis.valid = wc_m.valid;
    assign m_axis.data  = wc_m.data;

    axis_wc wc (
        .clk (clk),
        .rst (rst),
        .s   (wc_s),
        .m   (wc_m)
    );

    assign m_axi.rready = rst ? 1'b1 : wc_s.ready;
    assign wc_s.valid   = m_axi.rvalid;
    assign wc_s.data    = m_axi.rdata;
    assign wc_s.last    = m_axi.rlast;

    assign m_axi.arid    = AXI_ID;
    assign m_axi.arlen   = BURST_LENGTH - 1;
    assign m_axi.arsize  = $clog2(m_axi.DATA_WIDTH / 8);
    assign m_axi.arburst = 1; // INCR
    assign m_axi.arlock  = 0;
    assign m_axi.arcache = 4'b0011;
    assign m_axi.arprot  = 0;
    assign m_axi.arqos   = 0;

    typedef enum {READY, AR} state_t;
    state_t state;

    assign s_ready = state == READY;

    always_ff @(posedge clk) begin

        case (state)
            READY: begin
                if (s_ready & s_valid) begin
                    m_axi.arvalid <= 1;
                    m_axi.araddr  <= START_ADDR;
                    state         <= AR;
                end
            end

            AR: begin
                if (m_axi.arready & m_axi.arvalid) begin
                    m_axi.araddr  <= m_axi.araddr + (BURST_LENGTH * N * 2);

                    if (ctr == NB - 1) begin
                        ctr           <= 0;
                        state         <= READY;
                        m_axi.arvalid <= 0;
                    end else begin
                        ctr <= ctr + 1;
                    end
                end
            end
        endcase

        if (rst) begin
            ctr           <= 0;
            m_axi.arvalid <= 0; // TODO: axi protocol violation
            state         <= READY;
        end

    end

endmodule