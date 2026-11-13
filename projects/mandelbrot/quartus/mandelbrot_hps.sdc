# DE25-Nano HPS design (De25NanoHpsTop) timing constraints.

set_time_format -unit ns -decimal_places 3

# CLOCK2_50 feeds the bridge PLL (100 MHz for the HPS bridges), CLOCK1_50 the core PLL. CLOCK0_50
# clocks Terasic's fan controller directly, which divides it down to its I2C clock in logic.
create_clock -name CLOCK2_50 -period 20 [get_ports CLOCK2_50]
create_clock -name CLOCK0_50 -period 20 [get_ports CLOCK0_50]
derive_pll_clocks
derive_clock_uncertainty

# The GHRD's JTAG masters (copied from the Terasic package at build time).
source ./jtag.sdc

# CLOCK1_50 only feeds core_pll, whose IP constraints create its reference clock.

# The three clocks are unrelated: every crossing goes through SpinalHDL's BufferCC, StreamCCByToggle
# or StreamFifoCC (the fan readings, the register bus, the AXI channels, the interrupt).
set_clock_groups -asynchronous -group {CLOCK0_50} -group [get_clocks {bridgePll|*}] -group [get_clocks {corePll|*}]

# The HPS's reset output (h2f_reset, launched by the HPS internal oscillator) only feeds the reset
# synchronizers of the bridge and core clock domains (ResetCtrl.asyncAssertSyncDeassert).
set_false_path -from [get_clocks -nowarn hps_internal_osc] -to [get_clocks {bridgePll|* corePll|*}]

# PLL lock / reset control only feeds reset synchronizers.
set_false_path -from [get_keepers {*tennm_ph2_iopll~pll_ctrl_reg}]

# Board I/O: slow, or synchronized inside the design.
set_false_path -from [get_ports {HDMI_I2C_SCL HDMI_I2C_SDA}]
set_false_path -to   [get_ports {LED[*] HDMI_I2C_SCL HDMI_I2C_SDA}]
