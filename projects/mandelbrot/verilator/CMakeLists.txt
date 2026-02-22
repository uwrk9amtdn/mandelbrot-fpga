cmake_minimum_required(VERSION 3.14)

project(mandelbrot)

add_subdirectory(hd)

add_executable(mandelbrot main.cpp)
target_compile_features(mandelbrot PUBLIC cxx_std_17)

add_resource_dir(mandelbrot res)

target_link_libraries(mandelbrot PRIVATE Hd)

find_package(verilator HINTS $ENV{VERILATOR_ROOT})

verilate(mandelbrot
    SOURCES
	wrapper_top.sv
	../wrapper.sv
	../core_wrapper.sv
	../core.sv
	../single_iteration.sv
	../cfg.sv
	../../../axis/axis_intf.sv
	../../../axis/axis_intf_connect.sv
	../../../axis/axis_skid_buffer.sv
	../../../axis/axis_rr_arbiter.sv
	../../../axis/axis_rr_arbiter_tree.sv
	../../../axis/axis_wc.sv
	../../../arithmetic/mul_dsp.sv
	../../../arithmetic/constant_multiplier.sv
	../../../misc/delayer.sv
	../../../third_party/verilog-axis/rtl/axis_adapter.v
    TOP_MODULE wrapper_top
	TRACE_VCD
    VERILATOR_ARGS --clk clk -O3 --x-assign fast --x-initial fast --noassert --Wno-fatal
)