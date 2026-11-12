# DE25-Nano mandelbrot timing constraints.

# CLOCK0_50 and CLOCK1_50 only feed IOPLLs, whose IP constraints already create the 50 MHz
# reference clocks (a create_clock here would be ignored with a warning).
derive_pll_clocks
derive_clock_uncertainty

# PLL lock / reset control is asynchronous to every clock: it only feeds reset synchronizers
# (SpinalHDL BufferCC in ResetCtrl.asyncAssertSyncDeassert, and the EMIF IP's own lock_sync and
# reset synchronizer chains). Without this, they show up as setup/recovery failures launched from
# the PLL reference clock.
set_false_path -from [get_keepers {*tennm_ph2_iopll~pll_ctrl_reg}]

# The design's clocks are unrelated; every crossing goes through SpinalHDL's BufferCC /
# StreamFifoCC / FlowCCByToggle. The IOPLL IP names its clocks <instance path>_outclk<n>:
#   pll|..._outclk0        pixel clock (148.5 MHz)
#   pll|..._outclk1        core clock
#   emif|iopll|..._outclk0 memory (AXI) clock, 310 MHz
#   emif|iopll|..._outclk1 EMIF AXI4-Lite clock
set mb_groups {}
foreach pattern {pll|*_outclk0 pll|*_outclk1 emif|iopll|*_outclk0 emif|iopll|*_outclk1} {
    set c [get_clocks -nowarn $pattern]
    if {[get_collection_size $c] == 0} {
        post_message -type critical_warning "mandelbrot.sdc: no clock matches '$pattern', check the clock names in the timing report"
    } else {
        foreach_in_collection clk $c { post_message -type info "mandelbrot.sdc: '$pattern' -> [get_clock_info -name $clk]" }
        lappend mb_groups -group $c
    }
}
if {[llength $mb_groups] >= 4} {
    set_clock_groups -asynchronous {*}$mb_groups
}

# Board I/O: slow or asynchronous, synchronized inside the design.
set_false_path -from [get_ports {KEY[*] HDMI_TX_INT FPGA_UART_RX HDMI_I2C_SCL HDMI_I2C_SDA}]
set_false_path -to   [get_ports {LED[*] FPGA_UART_TX HDMI_I2C_SCL HDMI_I2C_SDA}]

# HDMI video: HDMI_TX_CLK is the pixel clock forwarded straight from the PLL and the data comes from
# registers on the same clock, exactly like Terasic's HDMI_TX demo, which leaves these unconstrained
# too. If the picture shows sparkles or wrong colors, shift the ADV7513 input clock delay
# (register 0xBA bits 7:5 in Hdmi.scala, 0x60 = no delay, each step 0.4 ns) or invert HDMI_TX_CLK.
set_false_path -to [get_ports {HDMI_TX_D[*] HDMI_TX_HS HDMI_TX_VS HDMI_TX_DE HDMI_TX_CLK}]
