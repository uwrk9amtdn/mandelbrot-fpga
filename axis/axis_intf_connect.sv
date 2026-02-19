module axis_intf_connect(
    axis_intf s,
    axis_intf m
);
    if (s.DATA_WIDTH != m.DATA_WIDTH || s.LAST_EN != m.LAST_EN) begin
        $error();
    end
    assign s.ready = m.ready;
    assign m.valid = s.valid;
    assign m.data  = s.data;
    assign m.last  = s.last;
endmodule