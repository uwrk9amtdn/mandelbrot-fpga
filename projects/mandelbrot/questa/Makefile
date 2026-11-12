export MODELSIM   := ./modelsim.ini
export SIMLIB_DIR ?= C:/Xilinx/simlib/

VLOG := vlog -lint -pedanticerrors

SOURCES := \
	../tb.sv                                                  \
	../../../sv/memory_controllers/ddr3_sim_model/ddr3_model.sv  \
	../top.sv                                                 \
	../cfg.sv                                                 \
	../single_iteration.sv                                    \
	../core.sv                                                \
	../core_wrapper.sv                                        \
	../wrapper.sv                                             \
	../color_converter.sv                                     \
	../memory_reader.sv                                       \
	../memory_writer.sv                                       \
	../../../sv/memory_controllers/ddr3_intf.sv                  \
	../../../sv/memory_controllers/uberddr3_wrapper_axi.sv       \
	../../../sv/axis/axis_intf.sv                                \
	../../../sv/axis/axis_intf_connect.sv                        \
	../../../sv/axis/axis_wc.sv                                  \
	../../../sv/axis/axis_afifo.sv                               \
	../../../sv/axis/axis_rr_arbiter.sv                          \
	../../../sv/axis/axis_rr_arbiter_tree.sv                     \
	../../../sv/axis/axis_skid_buffer.sv                         \
	../../../sv/hdmi/display_driver.sv                           \
	../../../sv/hdmi/ac701_adv7511_setup.sv                      \
	../../../sv/i2c/i2c_bit_ctrl.sv                              \
	../../../sv/i2c/i2c_byte_ctrl.sv                             \
	../../../sv/misc/clock_gen_7_series_pll.sv                   \
	../../../sv/misc/cdc_single.sv                               \
	../../../sv/misc/power_on_reset.sv                           \
	../../../sv/misc/delayer.sv                                  \
	../../../sv/axi/axi_intf.sv                                  \
	../../../sv/axi/axi_wc.sv                                    \
	../../../sv/arithmetic/constant_multiplier.sv                \
	../../../sv/arithmetic/mul_dsp.sv                            \
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


