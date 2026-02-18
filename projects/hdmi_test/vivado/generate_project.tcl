set part xc7a200tfbg676-2

create_project hdmi_test . -part $part -force

set design_files {
    ../top.sv
    ../../../axis/axis_intf.sv
    ../../../misc/cdc_single.sv
    ../../../misc/cdc_handshake.sv
    ../../../misc/cdc_multi.sv
    ../../../hdmi/ac701_adv7511_setup.sv
    ../../../hdmi/display_driver.sv
    ../../../i2c/i2c_bit_ctrl.sv
    ../../../i2c/i2c_byte_ctrl.sv
    ../../../misc/clock_gen_7_series_pll.sv
}

set constraint_files {
    ac701.xdc
}

create_ip -name vio -vendor xilinx.com -library ip -module_name vio_0

set_property -dict [list \
    CONFIG.C_NUM_PROBE_IN     {2} \
    CONFIG.C_NUM_PROBE_OUT    {5} \
    CONFIG.C_PROBE_IN0_WIDTH  {1} \
    CONFIG.C_PROBE_IN1_WIDTH  {1} \
    CONFIG.C_PROBE_OUT0_WIDTH {1} \
    CONFIG.C_PROBE_OUT1_WIDTH {8} \
    CONFIG.C_PROBE_OUT2_WIDTH {8} \
    CONFIG.C_PROBE_OUT3_WIDTH {8} \
    CONFIG.C_PROBE_OUT4_WIDTH {8} \
] [get_ips vio_0]

# generate_target all [get_ips vio_0]

add_files $design_files
add_files -fileset constrs_1 $constraint_files

set_property top top [current_fileset]
update_compile_order -fileset sources_1
