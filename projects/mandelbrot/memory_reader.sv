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

    if (m_axi.DATA_WIDTH != 16 || m_axis.DATA_WIDTH != 16) begin
        $error();
    end

    if (COUNT < BURST_LENGTH || COUNT % BURST_LENGTH != 0) begin
        $error();
    end

    logic [$clog2(COUNT/BURST_LENGTH)-1:0] ctr;

    assign m_axi.rready  = m_axis.ready;
    assign m_axis.valid  = m_axi.rvalid;
    assign m_axis.data   = m_axi.rdata;

    assign m_axi.arid    = AXI_ID;
    assign m_axi.arlen   = BURST_LENGTH - 1;
    assign m_axi.arsize  = 1; // 2 bytes
    assign m_axi.arburst = 1; // INCR
    assign m_axi.arlock  = 0;
    assign m_axi.arcache = 0;
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
                    m_axi.araddr  <= m_axi.araddr + BURST_LENGTH * 2;

                    if (ctr == (COUNT/BURST_LENGTH) - 1) begin
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
            m_axi.arvalid <= 0;
            state         <= READY;
        end

    end

endmodule