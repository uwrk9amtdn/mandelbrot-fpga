#!/usr/bin/env bash
# Co-simulation of the original SV wrapper against the SpinalHDL version.
# Override the configuration with environment variables, e.g.:
#   NCORES=3 ARBITER_TREE_SANS=2 DATA_WIDTH=64 ./run_wrapper.sh
# SI_LATENCY is read from ../../src/cfg.sv (the SV can only use that one value).
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
spinal=$(dirname "$here")
src=$(cd "$spinal/../src" && pwd)
repo=$(cd "$spinal/../../.." && pwd)
build=$here/build_wrapper

X_RES=${X_RES:-16}
Y_RES=${Y_RES:-8}
FRAC_WIDTH=${FRAC_WIDTH:-8}
NCORES=${NCORES:-4}
ARBITER_TREE_SANS=${ARBITER_TREE_SANS:-2}
BURST_LENGTH=${BURST_LENGTH:-8}
FB_START_ADDR=${FB_START_ADDR:-0x10000}
DATA_WIDTH=${DATA_WIDTH:-32}
SI_LATENCY=$(grep -oP 'SI_LATENCY\s*=\s*\K[0-9]+' "$src/cfg.sv")

echo "config: X_RES=$X_RES Y_RES=$Y_RES FRAC_WIDTH=$FRAC_WIDTH NCORES=$NCORES ARBITER_TREE_SANS=$ARBITER_TREE_SANS" \
     "BURST_LENGTH=$BURST_LENGTH FB_START_ADDR=$FB_START_ADDR DATA_WIDTH=$DATA_WIDTH SI_LATENCY=$SI_LATENCY (cfg.sv)"
mkdir -p "$build"

(cd "$spinal" && sbt -batch "runMain mandelbrot.GenerateWrapper targetDir=$build \
    xRes=$X_RES yRes=$Y_RES fracWidth=$FRAC_WIDTH nCores=$NCORES arbiterTreeSans=$ARBITER_TREE_SANS \
    burstLength=$BURST_LENGTH fbStartAddr=$FB_START_ADDR dataWidth=$DATA_WIDTH siLatency=$SI_LATENCY")

verilator --binary --timing -j 0 -Wno-fatal -Wno-lint -Wno-style -Wno-TIMESCALEMOD \
    --Mdir "$build/obj" -o cosim --top-module wrapper_cosim_tb \
    -GX_RES="$X_RES" -GY_RES="$Y_RES" -GFRAC_WIDTH="$FRAC_WIDTH" -GNCORES="$NCORES" \
    -GARBITER_TREE_SANS="$ARBITER_TREE_SANS" -GBURST_LENGTH="$BURST_LENGTH" \
    "-GFB_START_ADDR=$(printf "32'h%X" "$FB_START_ADDR")" -GDATA_WIDTH="$DATA_WIDTH" \
    "$src/cfg.sv" "$repo/sv/axis/axis_intf.sv" "$repo/sv/axis/axis_intf_connect.sv" \
    "$repo/sv/axis/axis_skid_buffer.sv" "$repo/sv/axis/axis_rr_arbiter.sv" "$repo/sv/axis/axis_rr_arbiter_tree.sv" \
    "$repo/sv/axis/axis_wc.sv" "$repo/third_party/verilog-axis/rtl/axis_adapter.v" \
    "$repo/sv/arithmetic/mul_dsp.sv" "$repo/sv/arithmetic/constant_multiplier.sv" "$repo/sv/misc/delayer.sv" \
    "$src/single_iteration.sv" "$src/core.sv" "$src/core_wrapper.sv" "$src/wrapper.sv" \
    "$build/sp_Wrapper.v" "$here/wrapper_cosim_tb.sv" > "$build/verilator.log" 2>&1 \
    || { tail -30 "$build/verilator.log"; exit 1; }

"$build/obj/cosim"
