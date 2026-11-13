# Creates the Quartus Pro project of the HPS design in the current directory (quartus/build_hps/).
# Run through the Makefile: quartus_sh -t ../create_project_hps.tcl <GHRD golden_top.qsf>
#
# Expects in the current directory: sp_De25NanoHpsTop.v (SpinalHDL), core_pll.ip (ip-deploy), the GHRD's Platform Designer
# system after hps_qsys.tcl, jtag.sdc, and board_management_ip/ (all copied from the Terasic package).

package require ::quartus::project

set terasic_qsf [lindex $argv 0]
set here        [file dirname [file normalize [info script]]]

project_new mandelbrot_hps -overwrite

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
set_global_assignment -name POWER_APPLY_THERMAL_MARGIN ADDITIONAL

# ------------------------------------------------------------------ sources
set_global_assignment -name TOP_LEVEL_ENTITY sp_De25NanoHpsTop
set_global_assignment -name VERILOG_FILE sp_De25NanoHpsTop.v
foreach v [lsort [glob board_management_ip/*.v]] { set_global_assignment -name VERILOG_FILE $v }
foreach q {qsys_top.qsys hps_subsys/hps_subsys.qsys jtag_subsys/jtag_subsys.qsys} {
    set_global_assignment -name QSYS_FILE $q
}
# every IP the reshaped system still uses (hps_qsys.tcl deleted the files of the removed ones)
foreach ip [lsort [concat [glob ip/*.ip] [glob ip/qsys_top/*.ip] [glob hps_subsys/ip/*/*.ip] [glob jtag_subsys/ip/*/*.ip]]] {
    if {![string match *.BAK.ip $ip]} { set_global_assignment -name IP_FILE $ip } ;# the IP upgrade's backups
}
set_global_assignment -name IP_FILE core_pll.ip
set_global_assignment -name SDC_FILE [file join $here mandelbrot_hps.sdc]

# ------------------------------------------------------------------ synthesis
set_global_assignment -name OPTIMIZATION_MODE "SUPERIOR PERFORMANCE"

# ------------------------------------------------------------------ pins: Terasic's assignments for the ports we use
set ports {^(CLOCK0_50|CLOCK1_50|CLOCK2_50|LED|HDMI_I2C_SCL|HDMI_I2C_SDA|HPS_[A-Za-z0-9_]+|LPDDR4A_[A-Za-z_]+)(\[[0-9]+\])?$}
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
post_message "create_project_hps.tcl: $n pin assignments taken from $terasic_qsf"

project_close
