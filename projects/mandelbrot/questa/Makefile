export MODELSIM   := ./modelsim.ini
export SIMLIB_DIR ?= C:/Xilinx/simlib/

VLOG := vlog -lint -pedanticerrors

SOURCES := \
	../tb.sv                                                  \
	../../../memory_controllers/ddr3_sim_model/ddr3_model.sv  \
	../top.sv                                                 \
	../cfg.sv                                                 \
	../single_iteration.sv                                    \
	../core.sv                                                \
	../core_wrapper.sv                                        \
	../wrapper.sv                                             \
	../color_converter.sv                                     \
	../memory_reader.sv                                       \
	../memory_writer.sv                                       \
	../../../memory_controllers/ddr3_intf.sv                  \
	../../../memory_controllers/uberddr3_wrapper_axi.sv       \
	../../../axis/axis_intf.sv                                \
	../../../axis/axis_wc.sv                                  \
	../../../axis/axis_afifo.sv                               \
	../../../axis/axis_rr_arbiter.sv                          \
	../../../axis/axis_rr_arbiter_tree.sv                     \
	../../../axis/axis_skid_buffer.sv                         \
	../../../hdmi/display_driver.sv                           \
	../../../hdmi/ac701_adv7511_setup.sv                      \
	../../../i2c/i2c_bit_ctrl.sv                              \
	../../../i2c/i2c_byte_ctrl.sv                             \
	../../../misc/clock_gen_7_series_pll.sv                   \
	../../../misc/cdc_single.sv                               \
	../../../misc/power_on_reset.sv                           \
	../../../misc/delayer.sv                                  \
	../../../axi/axi_intf.sv                                  \
	../../../axi/axi_wc.sv                                    \
	../../../arithmetic/constant_multiplier.sv                \
	../../../arithmetic/mul_dsp.sv                            \
    ../../../third_party/UberDDR3/rtl/ddr3_top.v              \
    ../../../third_party/UberDDR3/rtl/ddr3_phy.v              \
    ../../../third_party/UberDDR3/rtl/ddr3_controller.v       \
    ../../../third_party/UberDDR3/rtl/axi/axi_addr.v          \
    ../../../third_party/UberDDR3/rtl/axi/axim2wbsp.v         \
    ../../../third_party/UberDDR3/rtl/axi/aximrd2wbsp.v       \
    ../../../third_party/UberDDR3/rtl/axi/aximwr2wbsp.v       \
    ../../../third_party/UberDDR3/rtl/axi/ddr3_top_axi.v      \
    ../../../third_party/UberDDR3/rtl/axi/sfifo.v             \
    ../../../third_party/UberDDR3/rtl/axi/skidbuffer.v        \
    ../../../third_party/UberDDR3/rtl/axi/wbarbiter.v         \
	../../../third_party/verilog-axi/rtl/axi_adapter.v        \
	../../../third_party/verilog-axi/rtl/axi_adapter_rd.v     \
	../../../third_party/verilog-axi/rtl/axi_adapter_wr.v     \
	../../../third_party/verilog-axis/rtl/axis_adapter.v      \
	../../../third_party/wb2axip/rtl/afifo.v

rtl: .rtl.timestamp

.rtl.timestamp: $(SOURCES)
	$(VLOG) $(SOURCES)
	touch .rtl.timestamp

run: rtl
	vsim -voptargs=+acc work.tb glbl.glbl

clean:
	rm -rf work/
	rm -f .*.timestamp


