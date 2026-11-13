# Turns the Terasic GHRD's qsys_top into the system De25NanoHpsTop instantiates.
# Run in the build directory, on a copy of the GHRD: qsys-script --script=../hps_qsys.tcl
#
#   lwhps2fpga -> Avalon-MM bridge -> exported as "reg" (the register block; 4 KB, 32-bit)
#   f2sdram (through Terasic's adapter) -> exported as "f2sdram" (AXI4, the result writer)
#   f2h_irq0 -> exported as "f2h_irq"
#
# The GHRD's PIOs and its JTAG master on f2sdram go away. Its JTAG masters on the on-chip RAM and
# on fpga2hps stay: they cost little and can read HPS memory for debugging.

package require -exact qsys 25.1
load_system qsys_top.qsys

remove_instance subsys_periph
remove_instance ext_hps_f2sdram_master
foreach i [get_interfaces] {
    if {[string equal [get_interface_property $i EXPORT_OF] ""]} { remove_interface $i }
}

add_instance reg_bridge altera_avalon_mm_bridge
foreach {p v} {
    DATA_WIDTH 32  SYMBOL_WIDTH 8  ADDRESS_WIDTH 12  USE_AUTO_ADDRESS_WIDTH 0  ADDRESS_UNITS SYMBOLS
    MAX_BURST_SIZE 1  MAX_PENDING_RESPONSES 4  PIPELINE_COMMAND 1  PIPELINE_RESPONSE 1
} { set_instance_parameter_value reg_bridge $p $v }
add_connection clk_100.out_clk reg_bridge.clk
add_connection rst_in.out_reset reg_bridge.reset
add_connection subsys_hps.lwhps2fpga reg_bridge.s0
set_connection_parameter_value subsys_hps.lwhps2fpga/reg_bridge.s0 baseAddress 0x0

add_interface reg avalon master
set_interface_property reg EXPORT_OF reg_bridge.m0
add_interface f2sdram axi4 slave
set_interface_property f2sdram EXPORT_OF subsys_hps.f2sdram_adapter_axi4_sub
add_interface f2h_irq interrupt receiver
set_interface_property f2h_irq EXPORT_OF subsys_hps.f2h_irq0_in

puts "exported: [get_interfaces]"
save_system qsys_top.qsys
