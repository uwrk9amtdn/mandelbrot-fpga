module cdc_handshake #(
    int SYNC_STAGES = 4,
    int DATA_WIDTH  = 8
)(
    input  logic                  s_clk,
    input  logic                  s_rst,
    output logic                  s_ready,
    input  logic                  s_valid,
    input  logic [DATA_WIDTH-1:0] s_data,

    input  logic                  m_clk,
    input  logic                  m_rst,
    input  logic                  m_ready,
    output logic                  m_valid,
    output logic [DATA_WIDTH-1:0] m_data
);

    logic m_req;
    logic s_ack;
    logic s_req   = 0;
    logic m_ack   = 0;
    logic m_req_d = 0;

    logic [DATA_WIDTH-1:0] s_data_;
    logic [DATA_WIDTH-1:0] m_data_;

    xpm_cdc_handshake #(
        .DEST_EXT_HSK   (1),
        .DEST_SYNC_FF   (SYNC_STAGES),
        .INIT_SYNC_FF   (0),
        .SIM_ASSERT_CHK (0),
        .SRC_SYNC_FF    (SYNC_STAGES),
        .WIDTH          (DATA_WIDTH)
    ) cdc (
        .dest_out  (m_data_),
        .dest_req  (m_req),
        .src_rcv   (s_ack),
        .dest_ack  (m_ack),
        .dest_clk  (m_clk),
        .src_clk   (s_clk),
        .src_in    (s_data_),
        .src_send  (s_req)
    );

    assign s_ready = ~s_req & ~s_ack & ~s_rst;

    always_ff @(posedge s_clk) begin
        if (s_ready & s_valid) begin
            s_data_ <= s_data;
            s_req   <= 1;
        end
        if (s_ack) begin
            s_req <= 0;
        end
        if (s_rst) begin
            s_req <= 0;
        end
    end

    always_ff @(posedge m_clk) begin
        m_req_d <= m_req;
        if (m_req & ~m_req_d) begin
            m_valid <= 1;
            m_data  <= m_data_;
        end
        if (m_ready & m_valid) begin
            m_valid <= 0;
            m_ack   <= 1;
        end
        if (~m_req) begin
            m_ack <= 0;
        end
        if (m_rst) begin
            m_ack   <= 0;
            m_req_d <= 0;
            m_valid <= 0;
        end
    end

endmodule