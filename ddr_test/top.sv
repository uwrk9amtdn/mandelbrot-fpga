module top();

    axi axi0();

    crc16 crc16_i0(
        .clk           (clk),
        .rst           (rst),

        .s_axis_ready  (),
        .s_axis_valid  (),
        .s_axis_data   (),
        .s_axis_last   (),

        .m_axis_valid  (),
        .m_axis_data   ()
    );

    always @(posedge clk) begin
        case (state)
            IDLE: begin
                if (start_test & ~start_test_d1) begin
                end
            end
            WRITE: begin
                if (axi0.awready & axi0.awvalid) begin
                end
            end
            READ: begin
            end
        endcase
    end


endmodule