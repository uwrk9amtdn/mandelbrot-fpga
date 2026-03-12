create_project mandelbrot . -part xc7a200tfbg676-2 -force

set_property board_part xilinx.com:ac701:part0:1.4 [current_project]

set PRJ_DIR $env(PRJ_DIR)
set TOP_DIR $env(TOP_DIR)

set design_files "
    $PRJ_DIR/src/top.sv
    $PRJ_DIR/src/cfg.sv
    $PRJ_DIR/src/wrapper.sv
    $PRJ_DIR/src/core_wrapper.sv
    $PRJ_DIR/src/core.sv
    $PRJ_DIR/src/single_iteration.sv
    $PRJ_DIR/src/color_converter.sv
    $PRJ_DIR/src/memory_reader.sv
    $PRJ_DIR/src/memory_writer.sv
    $TOP_DIR/memory_controllers/ddr3_intf.sv
    $TOP_DIR/memory_controllers/mig_ac701_axi_wrapper.sv
    $TOP_DIR/axis/axis_intf.sv
    $TOP_DIR/axis/axis_intf_connect.sv
    $TOP_DIR/axis/axis_wc.sv
    $TOP_DIR/axis/axis_afifo.sv
    $TOP_DIR/axis/axis_rr_arbiter.sv
    $TOP_DIR/axis/axis_rr_arbiter_tree.sv
    $TOP_DIR/axis/axis_skid_buffer.sv
    $TOP_DIR/hdmi/display_driver.sv
    $TOP_DIR/hdmi/ac701_adv7511_setup.sv
    $TOP_DIR/i2c/i2c_bit_ctrl.sv
    $TOP_DIR/i2c/i2c_byte_ctrl.sv
    $TOP_DIR/misc/clock_gen_7_series_pll.sv
    $TOP_DIR/misc/cdc_single.sv
    $TOP_DIR/misc/cdc_multi.sv
    $TOP_DIR/misc/cdc_handshake.sv
    $TOP_DIR/misc/power_on_reset.sv
    $TOP_DIR/misc/delayer.sv
    $TOP_DIR/misc/rise_detector.sv
    $TOP_DIR/misc/linear_interpolator.sv
    $TOP_DIR/axi/axi_intf.sv
    $TOP_DIR/axi/axi_wc.sv
    $TOP_DIR/arithmetic/constant_multiplier.sv
    $TOP_DIR/arithmetic/mul_dsp.sv
    $TOP_DIR/third_party/verilog-axi/rtl/axi_adapter.v
    $TOP_DIR/third_party/verilog-axi/rtl/axi_adapter_rd.v
    $TOP_DIR/third_party/verilog-axi/rtl/axi_adapter_wr.v
    $TOP_DIR/third_party/verilog-axis/rtl/axis_adapter.v
"

set sim_files "
    $PRJ_DIR/src/tb.sv
    $TOP_DIR/memory_controllers/ddr3_sim_model/ddr3_model.sv
"

set constraint_files "
    ../ac701.xdc
"

create_ip -name vio -vendor xilinx.com -library ip -module_name vio_0

set_property -dict {
    CONFIG.C_NUM_PROBE_IN      7
    CONFIG.C_NUM_PROBE_OUT     20
    CONFIG.C_PROBE_IN0_WIDTH   1
    CONFIG.C_PROBE_IN1_WIDTH   1
    CONFIG.C_PROBE_IN2_WIDTH   1
    CONFIG.C_PROBE_IN3_WIDTH   19
    CONFIG.C_PROBE_IN4_WIDTH   19
    CONFIG.C_PROBE_IN5_WIDTH   19
    CONFIG.C_PROBE_IN6_WIDTH   1
    CONFIG.C_PROBE_OUT0_WIDTH  19
    CONFIG.C_PROBE_OUT1_WIDTH  1
    CONFIG.C_PROBE_OUT2_WIDTH  1
    CONFIG.C_PROBE_OUT3_WIDTH  1
    CONFIG.C_PROBE_OUT4_WIDTH  19
    CONFIG.C_PROBE_OUT5_WIDTH  1
    CONFIG.C_PROBE_OUT6_WIDTH  1
    CONFIG.C_PROBE_OUT7_WIDTH  1
    CONFIG.C_PROBE_OUT8_WIDTH  19
    CONFIG.C_PROBE_OUT9_WIDTH  1
    CONFIG.C_PROBE_OUT10_WIDTH 1
    CONFIG.C_PROBE_OUT11_WIDTH 1
    CONFIG.C_PROBE_OUT12_WIDTH 16
    CONFIG.C_PROBE_OUT13_WIDTH 1
    CONFIG.C_PROBE_OUT14_WIDTH 4
    CONFIG.C_PROBE_OUT15_WIDTH 1
    CONFIG.C_PROBE_OUT16_WIDTH 24
    CONFIG.C_PROBE_OUT17_WIDTH 24
    CONFIG.C_PROBE_OUT18_WIDTH 24
    CONFIG.C_PROBE_OUT19_WIDTH 24
} [get_ips vio_0]

set_property -dict {
    CONFIG.C_PROBE_OUT0_INIT_VAL  240
    CONFIG.C_PROBE_OUT1_INIT_VAL  0
    CONFIG.C_PROBE_OUT2_INIT_VAL  0
    CONFIG.C_PROBE_OUT3_INIT_VAL  0
    CONFIG.C_PROBE_OUT4_INIT_VAL  0
    CONFIG.C_PROBE_OUT5_INIT_VAL  0
    CONFIG.C_PROBE_OUT6_INIT_VAL  0
    CONFIG.C_PROBE_OUT7_INIT_VAL  0
    CONFIG.C_PROBE_OUT8_INIT_VAL  0
    CONFIG.C_PROBE_OUT9_INIT_VAL  0
    CONFIG.C_PROBE_OUT10_INIT_VAL 0
    CONFIG.C_PROBE_OUT11_INIT_VAL 0
    CONFIG.C_PROBE_OUT12_INIT_VAL 100
    CONFIG.C_PROBE_OUT13_INIT_VAL 0
    CONFIG.C_PROBE_OUT14_INIT_VAL 4
    CONFIG.C_PROBE_OUT15_INIT_VAL 1
    CONFIG.C_PROBE_OUT16_INIT_VAL 0xff0000
    CONFIG.C_PROBE_OUT17_INIT_VAL 0x00ff00
    CONFIG.C_PROBE_OUT18_INIT_VAL 0x0000ff
    CONFIG.C_PROBE_OUT19_INIT_VAL 0xffff00
} [get_ips vio_0]

# generate_target all [get_ips vio_0]

add_files $design_files
add_files -fileset sim_1 $sim_files
add_files -fileset constrs_1 $constraint_files

import_files $TOP_DIR/memory_controllers/mig_ac701_axi/mig_ac701_axi.xci

set_property top top [current_fileset]
update_compile_order -fileset sources_1

set_property strategy Flow_PerfOptimized_high [get_runs synth_1]
set_property STEPS.SYNTH_DESIGN.ARGS.GLOBAL_RETIMING on [get_runs synth_1]
set_property STEPS.SYNTH_DESIGN.ARGS.NO_SRLEXTRACT true [get_runs synth_1]
