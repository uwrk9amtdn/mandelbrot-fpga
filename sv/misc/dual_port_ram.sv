module dual_port_ram #(
    parameter ADDR_WIDTH = 8,
    parameter DATA_WIDTH = 8
)(
    input                       wclk,
    input                       we,
    input      [ADDR_WIDTH-1:0] waddr,
    input      [DATA_WIDTH-1:0] wdata,

    input                       rclk,
    input      [ADDR_WIDTH-1:0] raddr,
    output reg [DATA_WIDTH-1:0] rdata
);

    (* RAM_STYLE = "BLOCK" *) reg [DATA_WIDTH-1:0] data [2**ADDR_WIDTH-1:0];

    always @(posedge wclk) if (we) data[waddr] <= wdata;

    always @(posedge rclk) rdata <= data[raddr];

endmodule