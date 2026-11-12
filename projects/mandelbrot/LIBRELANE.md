# Running LibreLane on the Mandelbrot Project

As of 2026-11-09. For Arch Linux under WSL2, with Nix installed through pacman.

## Overview

This guide hardens the Mandelbrot compute engine (`wrapper.sv`) on sky130 with LibreLane. The only extra tool to install is Nix. LibreLane brings every EDA tool with it.

**What gets hardened:** the compute engine (cores, round-robin arbiter tree, address/data streamer), wrapped in a new top called `mandelbrot_asic`. The FPGA top `projects/mandelbrot/src/top.sv` can't go through an ASIC flow. It uses a Xilinx PLL, the UberDDR3 PHY (Xilinx IOSERDES/IDELAY), the MIG and the ADV7511 HDMI setup.

| Tool | Status on this machine | Action |
| --- | --- | --- |
| Nix | not installed | Install with pacman (step 1) |
| LibreLane | not installed | Clone, then enter with `nix develop` (step 2) |
| Yosys + slang, OpenROAD, OpenSTA, Magic, Netgen, KLayout | not installed | Provided by LibreLane's Nix shell. Don't install them separately |
| sky130 PDK | not installed | Downloaded automatically on the first run (a few GB) |
| Verilator, Icarus Verilog | installed | Used for a lint check before each flow run |
| Docker | not installed | Not needed |

## Step 1 — Install Nix with pacman

The Arch package (`extra/nix`, 2.35.x) works under WSL2 as long as systemd is running as PID 1. Check with `ps -p 1 -o comm=`.

1. Install the package and start the daemon:

   ```bash
   sudo pacman -S nix
   sudo systemctl enable --now nix-daemon.service
   ```

2. Don't create a `nix-users` group, and don't add yourself to `nixbld`. The Arch package's daemon socket is world-writable and `allowed-users = *`, so your user can already connect. `nixbld` is only for the sandboxed build users.

3. Enable flakes and add the FOSSi binary cache. Without the cache, Nix builds OpenROAD and Yosys from source, which takes hours and can run out of memory. These lines must go in `/etc/nix/nix.conf`, because the daemon ignores cache settings in user config:

   ```bash
   sudo tee -a /etc/nix/nix.conf <<'EOF'
   experimental-features = nix-command flakes
   extra-substituters = https://nix-cache.fossi-foundation.org
   extra-trusted-public-keys = nix-cache.fossi-foundation.org:3+K59iFwXqKsL7BNu6Guy0v+uTlwsxYQxjspXzqLYQs=
   EOF
   sudo systemctl restart nix-daemon.service
   ```

4. Verify:

   ```bash
   nix --version
   nix store info                # Store URL: daemon
   nix config show | grep -E '^substituters|^trusted-public-keys'
   ```

   The last command must list `nix-cache.fossi-foundation.org` and its key next to the `cache.nixos.org` entries.

## Step 2 — Get LibreLane and enter its shell

Use `nix develop`, not `nix-shell`. With pacman's Nix there's no `<nixpkgs>` channel, so `nix-shell` fails with `file 'nixpkgs' was not found in the Nix search path`. `nix develop` uses only the inputs pinned in LibreLane's `flake.lock`.

```bash
git clone https://github.com/librelane/librelane ~/librelane
cd ~/librelane
nix develop
librelane --smoke-test
```

The first `nix develop` downloads a few GB. Most lines should say `copying path ... from 'https://nix-cache.fossi-foundation.org'`. If you see a long run of `building ...` lines for openroad, yosys or magic, press Ctrl+C and recheck step 1.

Every later step runs inside this shell. You can enter it from any directory by passing the flake's location: `nix develop ~/librelane`. The shell starts in your current directory, and only the tools come from `~/librelane`. Re-entering is fast because everything is already in `/nix/store`.

The tool versions are fixed by the commit checked out in `~/librelane`. To change versions, `git checkout` a different commit there and enter the shell again.

## Step 3 — Fetch the required submodule

`sv/axis/axis_wc.sv` instantiates `axis_adapter` from `third_party/verilog-axis`, which isn't checked out yet. The core path needs no other submodule.

```bash
cd ~/Desktop/work-github/mandelbrot-fpga
git submodule update --init third_party/verilog-axis
ls third_party/verilog-axis/rtl/axis_adapter.v
```

## Step 4 — Create the ASIC top

The new top is a copy of `projects/mandelbrot/verilator/wrapper_top.sv`, with the `localparam`s turned into parameters and `NCORES` lowered from 16 to 4 for the first run. A top-level port can't be a SystemVerilog interface, so the AXI-Stream interfaces are broken out into plain wires, as in `wrapper_top`. This file passes a Verilator lint at `NCORES` = 4 and 2.

Save as `projects/mandelbrot/asic/src/mandelbrot_asic.sv`:

```systemverilog
module mandelbrot_asic #(
    parameter int          X_RES             = 2048,
    parameter int          Y_RES             = 2048,
    parameter int          FRAC_WIDTH        = 16,
    parameter int          NCORES            = 4,   // Y_RES % NCORES must be 0
    parameter int          ARBITER_TREE_SANS = 4,
    parameter int          BURST_LENGTH      = 16,
    parameter logic [31:0] FB_START_ADDR     = 0
)(
    input  logic                 clk,
    input  logic                 rst,

    output logic                 s_ready,
    input  logic                 s_valid,
    input  logic [15:0]          s_max_it,
    input  logic [2:-FRAC_WIDTH] s_center_x,
    input  logic [2:-FRAC_WIDTH] s_center_y,
    input  logic [2:-FRAC_WIDTH] s_xy_step,

    input  logic                 m_addr_ready,
    output logic                 m_addr_valid,
    output logic [31:0]          m_addr_data,

    input  logic                 m_data_ready,
    output logic                 m_data_valid,
    output logic [15:0]          m_data_data,
    output logic                 m_data_last
);

    axis_intf #(32, 0) m_addr ();
    axis_intf #(16, 1) m_data ();

    assign m_addr_valid = m_addr.valid;
    assign m_addr_data  = m_addr.data;
    assign m_addr.ready = m_addr_ready;

    assign m_data.ready = m_data_ready;
    assign m_data_valid = m_data.valid;
    assign m_data_data  = m_data.data;
    assign m_data_last  = m_data.last;

    wrapper #(
        .X_RES             (X_RES),
        .Y_RES             (Y_RES),
        .FRAC_WIDTH        (FRAC_WIDTH),
        .NCORES            (NCORES),
        .ARBITER_TREE_SANS (ARBITER_TREE_SANS),
        .BURST_LENGTH      (BURST_LENGTH),
        .FB_START_ADDR     (FB_START_ADDR)
    ) u_wrapper (
        .clk        (clk),
        .rst        (rst),
        .s_ready    (s_ready),
        .s_valid    (s_valid),
        .s_max_it   (s_max_it),
        .s_center_x (s_center_x),
        .s_center_y (s_center_y),
        .s_xy_step  (s_xy_step),
        .m_addr     (m_addr),
        .m_data     (m_data)
    );

endmodule
```

Lint it from the repo root before every flow run. Lint takes seconds; a failure in synthesis costs minutes:

```bash
cd ~/Desktop/work-github/mandelbrot-fpga
verilator --lint-only -Wno-fatal -Wno-WIDTHEXPAND -Wno-WIDTHTRUNC \
  -Wno-PINCONNECTEMPTY -Wno-PINMISSING -Wno-UNUSEDSIGNAL -Wno-GENUNNAMED \
  --top-module mandelbrot_asic \
  projects/mandelbrot/src/cfg.sv sv/axis/axis_intf.sv sv/axis/axis_intf_connect.sv \
  sv/axis/axis_skid_buffer.sv sv/axis/axis_rr_arbiter.sv sv/axis/axis_rr_arbiter_tree.sv \
  sv/axis/axis_wc.sv third_party/verilog-axis/rtl/axis_adapter.v \
  sv/arithmetic/mul_dsp.sv sv/arithmetic/constant_multiplier.sv sv/misc/delayer.sv \
  projects/mandelbrot/src/single_iteration.sv projects/mandelbrot/src/core.sv \
  projects/mandelbrot/src/core_wrapper.sv projects/mandelbrot/src/wrapper.sv \
  projects/mandelbrot/asic/src/mandelbrot_asic.sv
```

No `%Error` lines means you can move on to step 5.

## Step 5 — Write the LibreLane config

Save as `projects/mandelbrot/asic/config.json`. The `dir::` prefix makes each path relative to the config file. List the package (`cfg.sv`) and the interface first.

```json
{
  "DESIGN_NAME": "mandelbrot_asic",
  "VERILOG_FILES": [
    "dir::../src/cfg.sv",
    "dir::../../../sv/axis/axis_intf.sv",
    "dir::../../../sv/axis/axis_intf_connect.sv",
    "dir::../../../sv/axis/axis_skid_buffer.sv",
    "dir::../../../sv/axis/axis_rr_arbiter.sv",
    "dir::../../../sv/axis/axis_rr_arbiter_tree.sv",
    "dir::../../../sv/axis/axis_wc.sv",
    "dir::../../../third_party/verilog-axis/rtl/axis_adapter.v",
    "dir::../../../sv/arithmetic/mul_dsp.sv",
    "dir::../../../sv/arithmetic/constant_multiplier.sv",
    "dir::../../../sv/misc/delayer.sv",
    "dir::../src/single_iteration.sv",
    "dir::../src/core.sv",
    "dir::../src/core_wrapper.sv",
    "dir::../src/wrapper.sv",
    "dir::src/mandelbrot_asic.sv"
  ],
  "USE_SLANG": true,
  "SYNTH_PARAMETERS": ["NCORES=4"],
  "CLOCK_PORT": "clk",
  "CLOCK_PERIOD": 20,
  "FP_CORE_UTIL": 40,
  "PL_TARGET_DENSITY_PCT": 50
}
```

| Setting | Value | Why |
| --- | --- | --- |
| `USE_SLANG` | `true` | Required. The RTL uses SV interfaces, interface arrays, a package and negative bit ranges (`[2:-16]`), which Yosys's built-in parser can't handle |
| `SYNTH_PARAMETERS` | `NCORES=4` | Changes the core count without editing RTL. `Y_RES % NCORES` must be 0 |
| `CLOCK_PERIOD` | 20 ns (50 MHz) | A safe first target on sky130. Tighten it after timing closes |
| `FP_CORE_UTIL` | 40 % | Leaves room for routing |
| `PL_TARGET_DENSITY_PCT` | 50 % | Placement density, slightly above core utilization |

The default PDK is sky130A with the `sky130_fd_sc_hd` cell library. The `(* use_dsp *)` attributes in `mul_dsp.sv` and `single_iteration.sv` are FPGA hints and are ignored. The multipliers become standard cells.

## Step 6 — Run the flow

Run from the `asic` folder, inside the LibreLane shell. The first run also downloads the sky130 PDK through ciel.

```bash
cd ~/Desktop/work-github/mandelbrot-fpga/projects/mandelbrot/asic
nix develop ~/librelane
librelane config.json
# optional: name the run
librelane --run-tag ncores4_50mhz config.json
```

To run a single command without opening a shell:

```bash
nix develop ~/librelane --command librelane config.json
```

Each run writes to `runs/<tag>/`, with one numbered folder per step (`01-verilator-lint`, `…-yosys-synthesis`, `…-openroad-globalrouting` and so on). If a step fails, its folder holds the log and the report. Add `projects/mandelbrot/asic/runs/` to `.gitignore`.

## Step 7 — Check the results

A run passes when timing has no violations and DRC, LVS and antenna checks are clean. Look in `runs/<tag>/final/`:

| File or folder | What to check |
| --- | --- |
| `metrics.csv` / `metrics.json` | Setup and hold WNS/TNS (both ≥ 0), DRC errors (0), LVS errors (0), antenna violations, cell count, die area |
| `gds/mandelbrot_asic.gds` | The final layout |
| `nl/`, `pnl/` | Gate-level netlists, for gate-level simulation |
| `spef/`, `sdf/` | Parasitics and delays, for sign-off timing and back-annotated simulation |

Open the last run in a viewer. WSLg shows the windows directly:

```bash
librelane --last-run --flow OpenInKLayout config.json
librelane --last-run --flow OpenInOpenROAD config.json
```

## Step 8 — Scale up

Once a run is clean, change one thing at a time and re-run:

1. Raise the core count through `SYNTH_PARAMETERS`: 4 → 8 → 16. `Y_RES` (2048) must divide evenly by `NCORES`.
2. Lower `CLOCK_PERIOD`: 20 → 15 → 12 ns. Stop at the first run with negative setup slack, then go back one step.
3. If placement or routing fails from congestion, lower `FP_CORE_UTIL` (for example 40 → 30).

More than about 8 cores needs more memory than WSL's default of roughly 7 GB, because detailed routing uses a lot of RAM. Raise it in `%UserProfile%\.wslconfig` on Windows, then run `wsl --shutdown`:

```ini
[wsl2]
memory=12GB
```

## Troubleshooting

| Symptom | Cause | Fix |
| --- | --- | --- |
| `file 'nixpkgs' was not found in the Nix search path` | `nix-shell` needs a `<nixpkgs>` channel, and pacman's Nix has none | Use `nix develop` (step 2) |
| `experimental Nix feature 'nix-command' is disabled` | Flakes not enabled | Add the `experimental-features` line (step 1) |
| Long run of `building ...` lines in `nix develop` | FOSSi cache not used | Recheck `/etc/nix/nix.conf`, restart `nix-daemon` |
| `Cannot find file containing module: 'axis_adapter'` | Submodule not checked out | Step 3 |
| Synthesis errors on `interface`, `modport` or `[2:-16]` | Yosys's built-in parser in use | Set `"USE_SLANG": true` |
| `Verilator.Lint` step fails on warnings | LibreLane's built-in lint is stricter than the command in step 4 | Read `runs/<tag>/*-verilator-lint/` and fix, or set `"RUN_LINTER": false` while bringing up the flow |
| Setup violations (negative WNS) | Clock too fast for the multiplier path | Raise `CLOCK_PERIOD` |
| Routing step killed or very slow | Out of memory | Fewer cores, or raise WSL memory (step 8) |

## Notes

- The top has about 107 I/O signals. That's fine for a macro, but too many for a padframe like Tiny Tapeout's.
- Run the Verilator lint from step 4 after every RTL change.
