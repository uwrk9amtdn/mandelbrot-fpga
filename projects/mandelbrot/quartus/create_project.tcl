# Creates the Quartus Pro project in the current directory (quartus/build/).
# Run through the Makefile: quartus_sh -t ../create_project.tcl <terasic golden_top.qsf>
#
# Expects in the current directory: sp_De25NanoTop.v (SpinalHDL), sys_pll.ip (ip-deploy),
# EMIF_Qsys.qsys + ip/EMIF_Qsys/*.ip + agilex_reset_release.ip (copied from the Terasic package).

package require ::quartus::project

set terasic_qsf [lindex $argv 0]
set here        [file dirname [file normalize [info script]]]

project_new mandelbrot -overwrite

# ------------------------------------------------------------------ device (from golden_top.qsf)
set_global_assignment -name FAMILY "Agilex 5"
set_global_assignment -name DEVICE A5EB013BB23BE4SCS
set_global_assignment -name DEVICE_FILTER_PACKAGE VPBGA
set_global_assignment -name USE_CONF_DONE SDM_IO16
set_global_assignment -name USE_HPS_COLD_RESET SDM_IO11
set_global_assignment -name STRATIXV_CONFIGURATION_SCHEME "ACTIVE SERIAL X4"
set_global_assignment -name ACTIVE_SERIAL_CLOCK AS_FREQ_125MHZ
set_global_assignment -name DEVICE_INITIALIZATION_CLOCK OSC_CLK_1_125MHZ
set_global_assignment -name PWRMGT_VOLTAGE_OUTPUT_FORMAT "LINEAR FORMAT"
set_global_assignment -name PWRMGT_LINEAR_FORMAT_N "-12"
set_global_assignment -name BOARD default
set_global_assignment -name PROJECT_OUTPUT_DIRECTORY output_files

# ------------------------------------------------------------------ sources
set_global_assignment -name TOP_LEVEL_ENTITY sp_De25NanoTop
set_global_assignment -name VERILOG_FILE sp_De25NanoTop.v
set_global_assignment -name QSYS_FILE EMIF_Qsys.qsys
foreach ip [lsort [glob ip/EMIF_Qsys/*.ip]] {
    if {![string match *.BAK.ip $ip]} { set_global_assignment -name IP_FILE $ip }
}
set_global_assignment -name IP_FILE agilex_reset_release.ip
set_global_assignment -name IP_FILE sys_pll.ip
set_global_assignment -name SDC_FILE [file join $here mandelbrot.sdc]

# ------------------------------------------------------------------ synthesis
set_global_assignment -name OPTIMIZATION_MODE "SUPERIOR PERFORMANCE"

# ------------------------------------------------------------------ pins: Terasic's assignments for the ports we use
set ports {^(CLOCK0_50|CLOCK1_50|KEY|LED|HDMI_TX_CLK|HDMI_TX_HS|HDMI_TX_VS|HDMI_TX_DE|HDMI_TX_D|HDMI_I2C_SCL|HDMI_I2C_SDA|HDMI_TX_INT|FPGA_UART_TX|FPGA_UART_RX|LPDDR4A_[A-Za-z_]+|LPDDR4B_[A-Za-z_]+)(\[[0-9]+\])?$}
set n 0
set f [open $terasic_qsf r]
while {[gets $f line] >= 0} {
    set line [string trim $line]
    if {![regexp {^set_(location|instance)_assignment\s} $line]} continue
    if {![regexp -- {-to\s+"?([^\s"]+)"?\s*$} $line -> target]} continue
    if {![regexp $ports $target]} continue
    eval [string map {\[ \\\[ \] \\\]} $line] ;# LED[0] is a pin name, not a command
    incr n
}
close $f
post_message "create_project.tcl: $n pin assignments taken from $terasic_qsf"

project_close
