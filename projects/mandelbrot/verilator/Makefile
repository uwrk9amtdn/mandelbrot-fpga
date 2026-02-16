SOURCES := \
	../../../arithmetic/mul_dsp.sv             \
	../../../misc/delayer.sv                   \
	../cfg.sv                                  \
	../single_iteration.sv                     \
	../core.sv                                 \
	../../../axis/axis_intf.sv                 \
	../core_wrapper.sv                         \
	../../../arithmetic/constant_multiplier.sv \
	../../../axis/axis_rr_arbiter.sv           \
	../../../axis/axis_rr_arbiter_tree.sv      \
	../wrapper.sv


FLAGS := -Wall -Wpedantic -Wno-fatal -Wno-GENUNNAMED -Wno-EOFNEWLINE -Wno-WIDTHEXPAND -Wno-WIDTHTRUNC

# 	../wrapper.sv
# 	../../../third_party/verilog-axis/rtl/axis_adapter.v \
# 	../../../axis/axis.sv  								 \
# 	../../../arithmetic/constant_multiplier              \

# 	../../../axis/axis_wc.sv       \

lint:
	verilator $(FLAGS) --lint-only $(SOURCES)