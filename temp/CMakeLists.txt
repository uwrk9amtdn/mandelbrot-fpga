cmake_minimum_required(VERSION 3.14)

project(test)

add_subdirectory(vgasim)

find_package(verilator HINTS $ENV{VERILATOR_ROOT})

add_executable(test main.cpp)
verilate(test SOURCES display_driver.sv VERILATOR_ARGS --clk clk --clk pixel_clk -O3 --x-assign fast --x-initial fast --noassert)

target_link_libraries(test vgasim)