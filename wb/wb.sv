interface wishbone_intf #(AW = 32, DW = 32);
    logic            cyc;
    logic            stb;
    logic            we;
    logic [AW-1:0]   addr;
    logic [DW-1:0]   data_i;
    logic [DW-1:0]   data_o;
    logic [DW/8-1:0] sel;
    logic            stall;
    logic            ack;
    logic            err;
endinterface