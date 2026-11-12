SOURCES := \
	../../../sv/axis/axis_intf.sv                            \
	../../../sv/axis/axis_intf_connect.sv                    \
	../../../sv/axis/axis_skid_buffer.sv                     \
	../../../sv/axis/axis_rr_arbiter.sv                      \
	../../../sv/axis/axis_rr_arbiter_tree.sv                 \
	../../../sv/axis/axis_wc.sv                              \
	../../../sv/arithmetic/mul_dsp.sv                        \
	../../../sv/arithmetic/constant_multiplier.sv            \
	../../../sv/misc/delayer.sv                              \
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
# 	../../../sv/axis/axis.sv  								 \
# 	../../../sv/arithmetic/constant_multiplier              \

# 	../../../sv/axis/axis_wc.sv       \

lint:
	verilator $(FLAGS) --lint-only $(SOURCES)