#!/usr/bin/env bash
# Cycle-exact co-simulation of the original SV core_wrapper against the SpinalHDL version.
# Override the configuration with environment variables, e.g.:
#   X_RES=32 Y_RES=4 N=16 FRAC_WIDTH=12 ./run.sh
# SI_LATENCY is read from ../../src/cfg.sv (the SV can only use that one value).
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
spinal=$(dirname "$here")
src=$(cd "$spinal/../src" && pwd)
repo=$(cd "$spinal/../../.." && pwd)
build=$here/build

START_ADDR=${START_ADDR:-0xFFC0}
X_RES=${X_RES:-16}
Y_RES=${Y_RES:-8}
N=${N:-8}
FRAC_WIDTH=${FRAC_WIDTH:-8}
SI_LATENCY=$(grep -oP 'SI_LATENCY\s*=\s*\K[0-9]+' "$src/cfg.sv")

echo "config: START_ADDR=$START_ADDR X_RES=$X_RES Y_RES=$Y_RES N=$N FRAC_WIDTH=$FRAC_WIDTH SI_LATENCY=$SI_LATENCY (cfg.sv)"
mkdir -p "$build"

(cd "$spinal" && sbt -batch "runMain mandelbrot.GenerateVerilog targetDir=$build \
    startAddr=$START_ADDR xRes=$X_RES yRes=$Y_RES n=$N fracWidth=$FRAC_WIDTH siLatency=$SI_LATENCY")

verilator --binary --timing -j 0 -Wno-fatal -Wno-lint -Wno-style -Wno-TIMESCALEMOD \
    --Mdir "$build/obj" -o cosim --top-module cosim_tb \
    "-GSTART_ADDR=$(printf "32'h%X" "$START_ADDR")" \
    -GX_RES="$X_RES" -GY_RES="$Y_RES" -GN="$N" -GFRAC_WIDTH="$FRAC_WIDTH" \
    "$src/cfg.sv" "$repo/sv/axis/axis_intf.sv" "$repo/sv/arithmetic/mul_dsp.sv" "$repo/sv/misc/delayer.sv" \
    "$src/single_iteration.sv" "$src/core.sv" "$src/core_wrapper.sv" \
    "$build/sp_CoreWrapper.v" "$here/cosim_tb.sv" > "$build/verilator.log" 2>&1 \
    || { tail -30 "$build/verilator.log"; exit 1; }

"$build/obj/cosim"
