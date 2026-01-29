module skid_buffer #(
    DATA_WIDTH = 32
)(
    input  logic                  clk,
    input  logic                  rst,

    output logic                  s_ready,
    input  logic                  s_valid,
    input  logic [DATA_WIDTH-1:0] s_data,

    input  logic                  m_ready,
    output logic                  m_valid,
    output logic [DATA_WIDTH-1:0] m_data
);

    logic [DATA_WIDTH-1:0] skid_data;
    logic                  skid_valid;

    always_ff @(posedge clk) begin

        s_ready <= m_ready;

        if (s_valid & s_ready & ~m_ready) begin
            skid_valid <= 1;
            skid_data  <= s_data;
        end

        if (m_ready | ~m_valid) begin
            if (skid_valid) begin
                skid_valid <= 0;
                m_valid    <= 1;
                m_data     <= skid_data;
            end else begin
                m_valid <= s_valid;
                m_data  <= s_data;
            end
        end

        if (rst) begin
            skid_valid <= 0;
            s_ready    <= 0;
            m_valid    <= 0;
        end
    end


endmodule

module tb;

    logic       s_ready;
    logic       s_valid;
    logic [7:0] s_data;

    logic       m_ready;
    logic       m_valid;
    logic [7:0] m_data;

    logic clk;
    logic rst;

    skid_buffer #(8) dut (.*);

    initial begin

        logic [7:0] q [$];

        clk = 0;

        m_ready = 0;
        s_valid = 0;

        rst = 1;

        #5 clk = 1;

        rst = 0;

        #5 clk = 0;

        fork
            forever #10 clk <= ~clk;

            forever begin
                @(posedge clk);

                s_valid <= $urandom;
                s_data  <= $urandom;

                m_ready <= $urandom;
            end

            forever @(posedge clk) begin
                if (s_ready & s_valid) begin
                    q.push_back(s_data);
                end
                if (m_ready & m_valid) begin
                    logic [7:0] d;

                    if (q.size == 0) $error("q is empty");

                    d = q.pop_front();

                    if (d != m_data) begin
                        $error("wrong data");
                    end
                end
            end

            begin
                #10ms;
                $finish;
            end
        join
    end

endmodule