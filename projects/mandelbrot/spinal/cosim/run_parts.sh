#!/usr/bin/env bash
# Cycle-exact co-simulation of color_converter and display_driver against the SpinalHDL versions.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
spinal=$(dirname "$here")
src=$(cd "$spinal/../src" && pwd)
repo=$(cd "$spinal/../../.." && pwd)
build=$here/build_parts
mkdir -p "$build"

(cd "$spinal" && sbt -batch "runMain mandelbrot.GenerateParts $build")

verilator --binary --timing -j 0 -Wno-fatal -Wno-lint -Wno-style -Wno-TIMESCALEMOD \
    --Mdir "$build/obj" -o cosim --top-module parts_cosim_tb \
    "$repo/sv/axis/axis_intf.sv" "$repo/sv/misc/linear_interpolator.sv" "$src/color_converter.sv" \
    "$repo/sv/hdmi/display_driver.sv" \
    "$build/sp_ColorConverter.v" "$build/sp_DisplayDriver.v" "$here/parts_cosim_tb.sv" > "$build/verilator.log" 2>&1 \
    || { tail -30 "$build/verilator.log"; exit 1; }

"$build/obj/cosim"
