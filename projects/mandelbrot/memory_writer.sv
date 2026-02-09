module mandelbrot_memory_writer #(
    int BURST_SIZE = 16,
    int AXI_ID     = 1
)(
    input clk,
    input rst,

    axis_intf s_axis,
    axi_intf  m_axi
);

    if (s_axis.DATA_WIDTH != 16 || m_axi.DATA_WIDTH != 16 || m_axi.ADDR_WIDTH != 32) begin
        $error();
    end

    assign m_axi.awid     = AXI_ID;
    assign m_axi.awlen    = BURST_SIZE - 1;
    assign m_axi.awsize   = $clog2(m_axi.DATA_WIDTH / 8);
    assign m_axi.awburst  = 2'b01;
    assign m_axi.awlock   = 0;
    assign m_axi.awcache  = 4'b0011;
    assign m_axi.awprot   = 0;
    assign m_axi.awqos    = 0;

    assign m_axi.wdata    = s_axis.data;
    assign m_axi.wstrb    = '1;
    assign m_axi.wlast    = s_axis.last;

    assign m_axi.bready   = 1;

    assign m_axi.arvalid  = 0;

    assign m_axi.rready   = 1;

    typedef enum logic {ADDR, DATA} state_t;
    state_t state;

    logic [0:0] ctr;

    always_comb begin
        s_axis.ready = 0;
        m_axi.wvalid = 0;
        case (state)
            ADDR: begin
                s_axis.ready = ~m_axi.awvalid;
                m_axi.wvalid = 0;
            end
            DATA: begin
                s_axis.ready = m_axi.wready;
                m_axi.wvalid = s_axis.valid;
            end
        endcase
    end

    always_ff @(posedge clk) begin

        if (m_axi.awready) begin
            m_axi.awvalid <= 0;
        end

        case (state)
            ADDR: begin
                if (s_axis.ready & s_axis.valid) begin
                    m_axi.awaddr <= {m_axi.awaddr[15:0], s_axis.data};

                    if (ctr == 1) begin
                        ctr           <= 0;
                        state         <= DATA;
                        m_axi.awvalid <= 1;
                    end else begin
                        ctr <= ctr + 1;
                    end
                end
            end

            DATA: begin
                if (s_axis.ready & s_axis.valid) begin
                    if (s_axis.last) begin
                        state <= ADDR;
                    end
                end
            end
        endcase

        if (rst) begin
            ctr           <= 0;
            state         <= ADDR;
            m_axi.awvalid <= 0;
        end
    end
endmodule
