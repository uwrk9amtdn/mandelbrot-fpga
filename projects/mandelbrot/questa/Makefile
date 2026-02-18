export MODELSIM   := ./modelsim.ini
export SIMLIB_DIR := C:/Xilinx/simlib/

VLOG := vlog -lint -pedanticerrors

TOP_DIR := ../../../

SOURCES := \
	$(TOP_DIR)/third_party/UberDDR3/rtl/ecc/ecc_dec.sv          \
	$(TOP_DIR)/third_party/UberDDR3/rtl/ecc/ecc_enc.sv          \
	$(TOP_DIR)/third_party/UberDDR3/rtl/ddr3_controller.v       \
	$(TOP_DIR)/third_party/UberDDR3/rtl/ddr3_phy.v              \
	$(TOP_DIR)/third_party/UberDDR3/rtl/ddr3_top.v              \
	$(TOP_DIR)/third_party/UberDDR3/rtl/axi/axim2wbsp.v         \
	$(TOP_DIR)/third_party/UberDDR3/rtl/axi/aximrd2wbsp.v       \
	$(TOP_DIR)/third_party/UberDDR3/rtl/axi/aximwr2wbsp.v       \
	$(TOP_DIR)/third_party/UberDDR3/rtl/axi/axi_addr.v          \
	$(TOP_DIR)/third_party/UberDDR3/rtl/axi/ddr3_top_axi.v      \
	$(TOP_DIR)/third_party/UberDDR3/rtl/axi/sfifo.v             \
	$(TOP_DIR)/third_party/UberDDR3/rtl/axi/skidbuffer.v        \
	$(TOP_DIR)/third_party/UberDDR3/rtl/axi/wbarbiter.v         \
	$(TOP_DIR)/third_party/verilog-axi/rtl/axi_adapter.v        \
	$(TOP_DIR)/third_party/verilog-axi/rtl/axi_adapter_rd.v     \
	$(TOP_DIR)/third_party/verilog-axi/rtl/axi_adapter_wr.v     \
	$(TOP_DIR)/third_party/verilog-axis/rtl/axis_adapter.v      \
	$(TOP_DIR)/projects/mandelbrot/cfg.sv                       \
	$(TOP_DIR)/projects/mandelbrot/tb.sv                        \
	$(TOP_DIR)/projects/mandelbrot/top.sv                       \
	$(TOP_DIR)/projects/mandelbrot/color_converter.sv           \
	$(TOP_DIR)/projects/mandelbrot/core.sv                      \
	$(TOP_DIR)/projects/mandelbrot/core_wrapper.sv              \
	$(TOP_DIR)/projects/mandelbrot/memory_reader.sv             \
	$(TOP_DIR)/projects/mandelbrot/memory_writer.sv             \
	$(TOP_DIR)/projects/mandelbrot/single_iteration.sv          \
	$(TOP_DIR)/projects/mandelbrot/wrapper.sv                   \
	$(TOP_DIR)/memory_controllers/ddr3.sv                       \
	$(TOP_DIR)/memory_controllers/uberddr3_wrapper_axi.sv       \
	$(TOP_DIR)/axis/axis.sv                                     \
	$(TOP_DIR)/axis/axis_wc.sv                                  \
	$(TOP_DIR)/axis/axis_afifo.sv                               \
	$(TOP_DIR)/axis/axis_rr_arbiter.sv                          \
	$(TOP_DIR)/axis/axis_rr_arbiter_tree.sv                     \
	$(TOP_DIR)/axis/axis_skid_buffer.sv                         \
	$(TOP_DIR)/hdmi/display_driver.sv                           \
	$(TOP_DIR)/hdmi/ac701_adv7511_setup.sv                      \
	$(TOP_DIR)/i2c/i2c_bit_ctrl.sv                              \
	$(TOP_DIR)/i2c/i2c_byte_ctrl.sv                             \
	$(TOP_DIR)/misc/clock_gen_7_series_pll.sv                   \
	$(TOP_DIR)/axi/axi.sv                                       \
	$(TOP_DIR)/axi/axi_wc.sv                                    \
	$(TOP_DIR)/arithmetic/constant_multiplier.sv                \
	$(TOP_DIR)/third_party/wb2axip/rtl/afifo.v

rtl: .rtl.timestamp

.rtl.timestamp: $(SOURCES)
	$(VLOG) $(SOURCES)
	touch .rtl.timestamp

run: rtl
	vsim -voptargs=+acc work.tb glbl.glbl

clean:
	rm -rf work/
	rm -f .*.timestamp


