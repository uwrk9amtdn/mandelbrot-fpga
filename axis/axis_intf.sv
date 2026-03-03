interface axis_intf #(int DATA_WIDTH = 32, bit LAST_EN = 0);
    // TODO: add keep
    // localparam KEEP_WIDTH = (DATA_WIDTH + 7) / 8;

    logic                  ready;
    logic                  valid;
    logic [DATA_WIDTH-1:0] data;
    logic                  last;
    // logic [KEEP_WIDTH-1:0] keep;
endinterface

// interface axis_intf #(
//     type T       = logic [7:0],
//     bit  LAST_EN = 0
// );
//     logic      ready;
//     logic      valid;
//     T          data;
//     logic      last;
// endinterface

// TODO: protocol checking assertions https://developer.arm.com/documentation/dui0534/b/Protocol-Assertions-Descriptions/AXI4-Stream-protocol-assertion-descriptions?lang=en