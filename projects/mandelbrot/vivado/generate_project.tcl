set part xc7a200tfbg676-2

create_project mandelbrot . -part $part -force

set design_files {
    ../cfg.sv
    ../color_converter.sv
    ../core.sv
    ../core_wrapper.sv
    ../memory_reader.sv
    ../memory_writer.sv
    ../single_iteration.sv
    ../wrapper.sv
    ../top.sv
    ../../../axi/axi.sv
    ../../../axi/axi_wc.sv
    ../../../axis/axis.sv
    ../../../axis/axis_wc.sv
    ../../../axis/axis_afifo.sv
    ../../../axis/axis_rr_arbiter.sv
    ../../../axis/axis_rr_arbiter_tree.sv
    ../../../axis/axis_skid_buffer.sv
    ../../../hdmi/ac701_adv7511_setup.sv
    ../../../hdmi/display_driver.sv
    ../../../i2c/i2c_bit_ctrl.sv
    ../../../i2c/i2c_byte_ctrl.sv
    ../../../memory_controllers/ddr3.sv
    ../../../memory_controllers/uberddr3_wrapper_axi.sv
    ../../../arithmetic/mul_dsp.sv
    ../../../arithmetic/constant_multiplier.sv
    ../../../misc/delayer.sv
    ../../../misc/clock_gen_7_series_pll.sv
    ../../../third_party/UberDDR3/rtl/ddr3_top.v
    ../../../third_party/UberDDR3/rtl/ddr3_phy.v
    ../../../third_party/UberDDR3/rtl/ddr3_controller.v
    ../../../third_party/UberDDR3/rtl/axi/axi_addr.v
    ../../../third_party/UberDDR3/rtl/axi/axim2wbsp.v
    ../../../third_party/UberDDR3/rtl/axi/aximrd2wbsp.v
    ../../../third_party/UberDDR3/rtl/axi/aximwr2wbsp.v
    ../../../third_party/UberDDR3/rtl/axi/ddr3_top_axi.v
    ../../../third_party/UberDDR3/rtl/axi/sfifo.v
    ../../../third_party/UberDDR3/rtl/axi/skidbuffer.v
    ../../../third_party/UberDDR3/rtl/axi/wbarbiter.v
    ../../../third_party/verilog-axi/rtl/axi_adapter.v
    ../../../third_party/verilog-axi/rtl/axi_adapter_rd.v
    ../../../third_party/verilog-axi/rtl/axi_adapter_wr.v
    ../../../third_party/verilog-axis/rtl/axis_adapter.v
    ../../../third_party/wb2axip/rtl/afifo.v
}

set sim_files {
    ../tb.sv
}

set constraint_files {
    ../ac701_constraints.xdc
}

add_files $design_files
add_files -fileset sim_1 $sim_files
add_files -fileset constrs_1 $constraint_files

set_property top top [current_fileset]
update_compile_order -fileset sources_1
