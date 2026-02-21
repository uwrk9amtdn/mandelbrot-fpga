SOURCES := \
	../../../axis/axis_intf.sv                            \
	../../../axis/axis_intf_connect.sv                    \
	../../../axis/axis_skid_buffer.sv                     \
	../../../axis/axis_rr_arbiter.sv                      \
	../../../axis/axis_rr_arbiter_tree.sv                 \
	../../../axis/axis_wc.sv                              \
	../../../arithmetic/mul_dsp.sv                        \
	../../../arithmetic/constant_multiplier.sv            \
	../../../misc/delayer.sv                              \
	../../../third_party/verilog-axis/rtl/axis_adapter.v  \
	../cfg.sv                                             \
	../single_iteration.sv                                \
	../core.sv                                            \
	../core_wrapper.sv                                    \
	../wrapper.sv                                         \
	wrapper_top.sv


FLAGS := -Wall -Wpedantic -Wno-fatal -Wno-GENUNNAMED -Wno-EOFNEWLINE -Wno-WIDTHEXPAND -Wno-WIDTHTRUNC -Wno-PINCONNECTEMPTY -Wno-PINMISSING -Wno-TIMESCALEMOD -Wno-UNUSEDSIGNAL

# 	../wrapper.sv
# 	../../../third_party/verilog-axis/rtl/axis_adapter.v \
# 	../../../axis/axis.sv  								 \
# 	../../../arithmetic/constant_multiplier              \

# 	../../../axis/axis_wc.sv       \

lint:
	verilator $(FLAGS) --lint-only $(SOURCES)