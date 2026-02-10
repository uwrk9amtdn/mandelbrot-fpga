module memory_reader #(
    bit [31:0] START_ADDR = 0,
    int        AXI_ID     = 0
)(
    axi_intf m_axi_mem,

    axis_intf m_axis
);

endmodule

module memory_reader #(
    X_RES         = 1920,
    Y_RES         = 1080,
    AXI_ID        = 1,
    BURST_SIZE    = 128,
    FB_START_ADDR = 0
)(
    input clk,
    input rst,

    axi m_axi_mem,

    input         pixel_clk,
    input         vsync,
    input         de
    output [15:0] d,
);

    reg  [29:0] addr_counter;
    wire        vsync_synced;
    reg         vsync_synced_d1 = 0;

    reg  [23:0] fifo_din;
    reg         fifo_wr_en = 0;
    wire        fifo_full;
    wire        fifo_empty;


    axis_intf #(16) fifo_s ();
    axis_intf #(16) fifo_m ();

    axis_afifo #(
        .SYNC_STAGES (2),
        .DEPTH       (32)
    )(
        .s_clk (),
        .s_rst (),
        .m_clk (),
        .m_rst (),

        .s (fifo_s),
        .m (fifo_m)
    );

    fifo_generator_0 fifo0 (
        .wr_clk      (clk),
        .rd_clk      (pixel_clk),
        .din         (fifo_din),
        .wr_en       (fifo_wr_en),
        .rd_en       (de),
        .dout        (rgb),
        .full        (fifo_full),
        .empty       (fifo_empty)
    );

    xpm_cdc_single #(
        .DEST_SYNC_FF   (4),
        .INIT_SYNC_FF   (0),
        .SIM_ASSERT_CHK (0),
        .SRC_INPUT_REG  (0)
    ) vsync_sync (
       .dest_out (vsync_synced),
       .dest_clk (clk),
       .src_clk  (pixel_clk),
       .src_in   (vsync)
    );

    assign m_axi_ram.awvalid = 0;
    assign m_axi_ram.wvalid  = 0;
    assign m_axi_ram.bready  = 0;
    assign m_axi_ram.rready  = ~fifo_full;

    typedef enum {WAIT_VSYNC, AR} state_t;
    state_t state = WAIT_VSYNC;

    always @(posedge clk) begin

        vsync_synced_d1  <= vsync_synced;
        fifo_wr_en       <= 0;

        case (state)
            WAIT_VSYNC: begin
                addr_counter <= BASE_ADDR;
                if (vsync_synced_d1 & ~vsync_synced) begin
                    state        <= AR;
                end
            end

            AR: begin

                m_axi_ram.arid    <= 0;
                m_axi_ram.araddr  <= addr_counter << 2;
                m_axi_ram.arlen   <= BURST_SIZE;
                m_axi_ram.arsize  <= 2; // 4 bytes
                m_axi_ram.arburst <= 0;
                m_axi_ram.arlock  <= 0;
                m_axi_ram.arcache <= 0;
                m_axi_ram.arprot  <= 0;
                m_axi_ram.arqos   <= 0;
                m_axi_ram.arvalid <= 1;

                if (m_axi_ram.arready & m_axi_ram.arvalid) begin
                    if (addr_counter == BASE_ADDR + WIDTH * HEIGHT) begin
                        m_axi_ram.arvalid <= 0;
                        addr_counter      <= BASE_ADDR;
                        state             <= WAIT_VSYNC;
                    end else begin
                        addr_counter <= addr_counter + BURST_SIZE;
                    end
                end
            end
        endcase

        if (m_axi_ram.rready & m_axi_ram.rvalid) begin
            fifo_wr_en <= 1;
            fifo_din   <= m_axi_ram.rdata[23:0];
        end

        if (rst) begin
            m_axi_ram.arvalid <= 0;
            vsync_synced_d1   <= 0;
            fifo_wr_en        <= 0;
            state             <= WAIT_VSYNC;
        end
    end

endmodule