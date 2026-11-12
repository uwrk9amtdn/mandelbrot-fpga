`include "axi.svh"

module framebuffer_writer(
    input        clk,
    input        rst,

    output       s_ready,
    input        s_valid,
    input [31:0] s_addr,
    input [23:0] s_rgb,

    output       error,

    axi.master m_axi_ram
);
    typedef enum { IDLE, AW, W, B, ERROR } state_t;
    state_t state;

    assign s_ready = state == IDLE;
    assign error   = state == ERROR;

    reg [31:0] addr_reg;
    reg [23:0] rgb_reg;

    always @(posedge clk) begin

        case (state)
            IDLE: begin
                if (s_ready & s_valid) begin
                    state    <= AW;
                    addr_reg <= s_addr;
                    rgb_reg  <= s_rgb;
                end
            end

            AW: begin
                m_axi_ram.awvalid <= 1;
                m_axi_ram.awid    <= 0;
                m_axi_ram.awaddr  <= addr_reg;
                m_axi_ram.awlen   <= 0; // 1 transfer
                m_axi_ram.awsize  <= 2; // 4 bytes
                m_axi_ram.awburst <= 0; // fixed
                m_axi_ram.awlock  <= 0; // normal
                m_axi_ram.awcache <= 0; // bufferable
                m_axi_ram.awprot  <= 0;
                m_axi_ram.awqos   <= 0;
                if (m_axi_ram.awready & m_axi_ram.awvalid) begin
                    m_axi_ram.awvalid <= 0;
                    state             <= W;
                end
            end

            W: begin
                m_axi_ram.wvalid <= 1;
                m_axi_ram.wdata  <= {8'b0, rgb_reg};
                m_axi_ram.wstrb  <= '1;
                m_axi_ram.wlast  <= 1;
                if (m_axi_ram.wready & m_axi_ram.wvalid) begin
                    m_axi_ram.wvalid <= 0;
                    state            <= B;
                end
            end

            B: begin
                m_axi_ram.bready <= 1;
                if (m_axi_ram.bready & m_axi_ram.bvalid) begin
                    m_axi_ram.bready <= 0;
                    if (m_axi_ram.bresp = 0)
                        state <= IDLE;
                    else
                        state <= ERROR;
                end
            end

            ERROR: begin
            end

        endcase

        if (rst) begin
            state <= IDLE;
            m_axi_ram.awvalid <= 0;
            m_axi_ram.wvalid  <= 0;
            m_axi_ram.bready  <= 0;
            m_axi_ram.arvalid <= 0;
            m_axi_ram.rready  <= 0;
        end
    end

endmodule