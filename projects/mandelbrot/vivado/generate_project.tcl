create_project mandelbrot . -force

set_property board_part xilinx.com:ac701:part0:1.4 [current_project]

set design_files {
    ../top.sv
    ../cfg.sv
    ../wrapper.sv
    ../core_wrapper.sv
    ../core.sv
    ../single_iteration.sv
    ../color_converter.sv
    ../memory_reader.sv
    ../memory_writer.sv
    ../../../memory_controllers/ddr3_intf.sv
    ../../../memory_controllers/mig_ac701_axi_wrapper.sv
    ../../../axis/axis_intf.sv
    ../../../axis/axis_intf_connect.sv
    ../../../axis/axis_wc.sv
    ../../../axis/axis_afifo.sv
    ../../../axis/axis_rr_arbiter.sv
    ../../../axis/axis_rr_arbiter_tree.sv
    ../../../axis/axis_skid_buffer.sv
    ../../../hdmi/display_driver.sv
    ../../../hdmi/ac701_adv7511_setup.sv
    ../../../i2c/i2c_bit_ctrl.sv
    ../../../i2c/i2c_byte_ctrl.sv
    ../../../misc/clock_gen_7_series_pll.sv
    ../../../misc/cdc_single.sv
    ../../../misc/cdc_multi.sv
    ../../../misc/cdc_handshake.sv
    ../../../misc/power_on_reset.sv
    ../../../misc/delayer.sv
    ../../../misc/rise_detector.sv
    ../../../axi/axi_intf.sv
    ../../../axi/axi_wc.sv
    ../../../arithmetic/constant_multiplier.sv
    ../../../arithmetic/mul_dsp.sv
    ../../../third_party/verilog-axi/rtl/axi_adapter.v
    ../../../third_party/verilog-axi/rtl/axi_adapter_rd.v
    ../../../third_party/verilog-axi/rtl/axi_adapter_wr.v
    ../../../third_party/verilog-axis/rtl/axis_adapter.v
    ../../../third_party/wb2axip/rtl/afifo.v
}

set sim_files {
    ../tb.sv
    ../../../memory_controllers/ddr3_sim_model/ddr3_model.sv
}

set constraint_files {
    ../ac701.xdc
}

create_ip -name vio -vendor xilinx.com -library ip -module_name vio_0

set_property -dict [list \
    CONFIG.C_NUM_PROBE_IN      {6} \
    CONFIG.C_NUM_PROBE_OUT     {15} \
    CONFIG.C_PROBE_IN0_WIDTH   {1} \
    CONFIG.C_PROBE_IN1_WIDTH   {1} \
    CONFIG.C_PROBE_IN2_WIDTH   {1} \
    CONFIG.C_PROBE_IN3_WIDTH   {19} \
    CONFIG.C_PROBE_IN4_WIDTH   {19} \
    CONFIG.C_PROBE_IN5_WIDTH   {19} \
    CONFIG.C_PROBE_OUT0_WIDTH  {19} \
    CONFIG.C_PROBE_OUT1_WIDTH  {1} \
    CONFIG.C_PROBE_OUT2_WIDTH  {1} \
    CONFIG.C_PROBE_OUT3_WIDTH  {1} \
    CONFIG.C_PROBE_OUT4_WIDTH  {19} \
    CONFIG.C_PROBE_OUT5_WIDTH  {1} \
    CONFIG.C_PROBE_OUT6_WIDTH  {1} \
    CONFIG.C_PROBE_OUT7_WIDTH  {1} \
    CONFIG.C_PROBE_OUT8_WIDTH  {19} \
    CONFIG.C_PROBE_OUT9_WIDTH  {1} \
    CONFIG.C_PROBE_OUT10_WIDTH {1} \
    CONFIG.C_PROBE_OUT11_WIDTH {1} \
    CONFIG.C_PROBE_OUT12_WIDTH {16} \
    CONFIG.C_PROBE_OUT13_WIDTH {1} \
    CONFIG.C_PROBE_OUT14_WIDTH {4} \
] [get_ips vio_0]

# generate_target all [get_ips vio_0]

add_files $design_files
add_files -fileset sim_1 $sim_files
add_files -fileset constrs_1 $constraint_files

import_files ../../../memory_controllers/mig_ac701_axi/mig_ac701_axi.xci

set_property top top [current_fileset]
update_compile_order -fileset sources_1
