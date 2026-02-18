export MODELSIM   := ./modelsim.ini
export SIMLIB_DIR := C:/Xilinx/simlib/

VLOG := vlog -lint -pedanticerrors

SOURCES := \
	../tb.sv                                                \
    ../top.sv                                               \
    ../ddr3_model.sv                                        \
    ../../../axi/axi_intf.sv                                \
    ../../../memory_controllers/ddr3_intf.sv                \
    ../../../memory_controllers/uberddr3_wrapper_axi.sv     \
    ../../../misc/clock_gen_7_series_pll.sv                 \
    ../../../third_party/UberDDR3/rtl/ddr3_top.v            \
    ../../../third_party/UberDDR3/rtl/ddr3_phy.v            \
    ../../../third_party/UberDDR3/rtl/ddr3_controller.v     \
    ../../../third_party/UberDDR3/rtl/axi/axi_addr.v        \
    ../../../third_party/UberDDR3/rtl/axi/axim2wbsp.v       \
    ../../../third_party/UberDDR3/rtl/axi/aximrd2wbsp.v     \
    ../../../third_party/UberDDR3/rtl/axi/aximwr2wbsp.v     \
    ../../../third_party/UberDDR3/rtl/axi/ddr3_top_axi.v    \
    ../../../third_party/UberDDR3/rtl/axi/sfifo.v           \
    ../../../third_party/UberDDR3/rtl/axi/skidbuffer.v      \
    ../../../third_party/UberDDR3/rtl/axi/wbarbiter.v

rtl: .rtl.timestamp

.rtl.timestamp: $(SOURCES)
	$(VLOG) $(SOURCES)
	touch .rtl.timestamp

run: rtl
	vsim -voptargs=+acc work.tb glbl.glbl

clean:
	rm -rf work/
	rm -f .*.timestamp


