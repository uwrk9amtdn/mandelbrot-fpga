# Phase 4 design study: perturbation on the DE25-Nano (2026-11-19)

**Status: decision open.** The user will choose among the options of section 7 later (2026-11-19).
Nothing of phase 4 is built; experiments E1-E3 (section 6) are proposed, not run.

The question: how to make deep views fast, and deeper than 128 bits allow. Phase 3 left the deep view
of `bench_views.py` (7e-12 per pixel, max_it 10000) untouched: every pixel escapes, so only a faster
iteration helps. Perturbation is the standard answer. This study estimates what it would give on
this FPGA, **compares it with the PC**, and proposes three cheap experiments to run before any RTL.

## 1. Where we are

| engine | format | depth limit (pixel) | rate | source |
|---|---|---|---|---|
| FPGA, 12 cores, W = 64 | fixed point, F = 54 | about 1e-13 (16 ulps) | 2.37 G it/s | ROADMAP phase 3 |
| FPGA, 5 cores, W = 128 | fixed point, F = 118 | about 3e-35 | 0.78 G it/s | ROADMAP phase 2 |
| PC CPU (Ryzen 9 9900X, 24 threads) | double, AVX-512 | about 1e-13 | **11.2 G it/s** | `pc/bench`, phase 2 step 6 |
| PC CPU | 64-bit / 128-bit fixed point | as W | 1.1 / 0.2 G it/s | same |

The FPGA wins today only where the CPU has no fast format: between 1e-13 and 3e-35, against fixed point
on the CPU. **With perturbation, the CPU gets a fast format at every depth** (rescaled double), so
phase 4 is a race against roughly the CPU's double-precision rate, not its fixed-point one.

## 2. The method

For a reference point C (computed once, at high precision) and a pixel c = C + δ₀:

    z_n = Z_n + δ_n,   δ_{n+1} = (2 Z_n + δ_n) · δ_n + δ₀

- **Z_n** is computed with MPFR on the HPS (or the PC) and rounded to low precision; it is bounded
  (|Z| ≤ 2 until it escapes), so it is stored as fixed point.
- **δ_n** is tiny at depth (about the pixel size times growth), so it needs a wide exponent but only
  a modest mantissa: what matters is δ's relative precision.
- **Rebasing** (Zhuoran): when |Z_n + δ_n| < |δ_n|, set δ := Z_n + δ_n and n := 0. It removes most
  glitches with a single reference, and a pixel that reaches the end of the reference rebases too, so
  the stored orbit can be shorter than max_it. In hardware: a low-precision compare and a counter reset.
- **BLA** (bilinear approximation, the modern form of series approximation): per-pixel jumps of many
  iterations at once, δ_{n+l} ≈ A·δ_n + B·δ₀ while |δ_n| is under a validity radius. In software it is
  the main speed-up at depth (often 10-1000x at high iteration counts). It is a table lookup and a branch
  per step: natural on a CPU, awkward in this pipeline (section 5).

## 3. An FPGA perturbation core

### Number format: rescaled fixed point, not floating point

A floating-point adder in logic costs several hundred ALMs, and one iteration needs about nine
additions; with 46.8k ALMs that would leave fewer than 10 cores. The cheaper form, used by
software too ("rescaled iterations"): per pixel, **δ = 2^e · d** with d a fixed-point complex
mantissa (|d| in [1/2, 2) most of the time) and e an integer exponent (16 bits: depth 2^-32768).

- W = 2Z + δ is computed at Z's scale (fixed point, about 56 bits). When δ is below Z's last bit it
  drops out, which is right: δ² is then below the precision of 2Zδ anyway.
- **One complex multiply per iteration**, d' = W · d, then + d₀ · 2^(e₀ − e) (a barrel shift of the
  pixel's constant mantissa), then renormalise (if |d'| ≥ 2: shift right, e += 1). Three real
  multiplies with Gauss's trick (or four).
- Escape (|z|² ≥ R²) and the rebasing test (|Z + δ| < |δ|) need only a few bits: small multipliers in
  18x19 DSP halves or LUTs.

### Resources per core, by mantissa width M of d

Agilex 5 here: 188 DSP blocks (each one 27x27, or two 18x19), 358 M20K, 46.8k ALMs; 198 MHz, one
iteration per core per cycle (the slot pipeline of `SlotCore`, unchanged).

| M | multiplier per real product | DSP per core (3 real + small tests) | cores by DSP | likely limit | rate at 198 MHz |
|---|---|---|---|---|---|
| 54 | 2x2 limbs of 27, lowest product dropped: 3 blocks | about 11 | 16 | ALMs: about 12-14 | **2.4-3.2 G it/s** |
| 36 | 2x2 limbs of 18 in halves: about 2 blocks | about 7 | 26 | ALMs: about 18-22 | 3.6-4.4 G it/s |
| 27 | one 27x27 block | about 4 | 45 | ALMs and M20K: about 25-30 | 5-6 G it/s |

The ALM column is an estimate (about 2-2.5k ALMs per core at M = 54: the Gauss adders, the d₀ shifter,
renormalisation, per-slot state in MLABs), checked against the phase 2 cores; a trial synthesis of one
core would replace it (section 6, E4).

### Reference orbit storage

Every core reads Z at its own n each cycle (the slots are at different iterations, and rebasing makes
them diverge further). An entry is 2 × about 56 bits at M = 54 (2 × 30 at M = 27).

- **On chip:** about 300 free M20K blocks (6 Mbit). A dual-port M20K serves 2 cores, or 4 if run at
  twice the core clock (396 MHz, to be checked). For 14 cores at M = 54: 4-7 copies, so **about 7-13k
  entries**; for 28 cores at M = 27: 7-14 copies of half-size entries, about 7-14k.
- **LPDDR4B** (free since phase 1) can't serve random reads: 14 cores × 14 bytes × 198 MHz is 39 GB/s.
  It could hold a long orbit streamed in windows, but only if pixels stay near the same n, which
  rebasing breaks.
- So the reference length is capped at about 10k. Rebasing lets pixels run longer than the reference,
  but how often a capped reference forces a rebase, and what that does to accuracy, is open (E2).

### What the rest of the system needs

- HPS (or PC): an MPFR reference orbit per view (A76: milliseconds for 10k iterations at a few
  hundred bits), loaded into the M20K copies through a new register window or a DMA.
- Protocol: a "perturbation tile" request carrying C, δ₀ per pixel (or x0, y0, step relative to C) and
  the exponent; INFO feature bit. The arithmetic id changes completely; `fixed.py` gets a bit-exact
  model of the rescaled core, as for phases 2 and 3.
- The viewer: pick the reference (the view centre, or a nucleus found by Newton's method), resend on
  large pans.

## 4. Against the PC

| engine | precision of δ | rate (estimate) | with BLA |
|---|---|---|---|
| FPGA, M = 54 | about double | 2.4-3.2 G it/s | no |
| FPGA, M = 27 | about 8 digits | 5-6 G it/s | no |
| PC CPU, rescaled double, AVX-512 | double | about 5-8 G it/s (the 11.2 G of plain double, less the orbit loads, rebasing tests and rescaling) | yes, often 10-1000x fewer iterations at depth |

**At equal precision the FPGA would be about 2x slower than the PC, and much slower once BLA is
counted.** Only a narrow mantissa (M = 27-36) gets the FPGA to the CPU's raw rate, and only if that
precision is enough (E1). This is the main result of the study: as a speed project, perturbation on
this FPGA does not beat the machine it is attached to. Reasons to build it anyway would be learning,
or a board that renders deep views on its own (the HDMI design, a demo without a PC).

## 5. Why not BLA in hardware

BLA needs per step: a table read at (n, level) (A, B complex, a radius), a compare of |δ| with the
radius, then either the jump (two complex multiplies, n += 2^level) or a normal iteration. The table
is about twice the orbit length and every core reads it at its own n and level, so it has the orbit's
storage problem twice over; the variable step breaks the one-iteration-per-cycle slot pipeline into
a data-dependent one. Possible, but a different engine; not for a first perturbation core.

## 6. Experiments before any RTL (each a day or less, on the PC)

- **E1, precision of narrow deltas.** In numpy/Python (MPFR through `gmpy2` for references): render
  deep tiles (1e-20 to 1e-100 per pixel, seahorse and minibrot-rich locations) with rescaled deltas at
  M = 27, 36, 54, against M = 54 with a fresh reference per tile and against exact MPFR on a sample.
  Measure wrong counts and visible artefacts. Decides M, so the core count.
- **E2, orbit length and rebasing.** On the same views: the reference length needed, how often a
  10k cap forces a rebase, and whether forced rebases change counts. Decides whether on-chip orbits
  are enough.
- **E3, the CPU yardstick.** Add perturbation (rescaled double, rebasing; then BLA) to `pc/bench`
  (C++, OpenMP, AVX-512), on the same deep views. Replaces the "5-8 G it/s" guess with a number.
- **E4, one core in Quartus** (only if E1-E3 leave a case for the FPGA): synthesise one rescaled core
  at the chosen M, for ALMs and timing at 198 MHz.

## 7. Options

1. **Run E1-E3, then decide** (recommended). They are cheap and decide everything: if E3 shows the
   CPU far ahead and E1 shows M = 54 is needed, the FPGA perturbation core is a learning project
   only, and the deep views are better served by perturbation on the PC.
2. **Build the M = 54 core** directly (about 13 cores, 2.4-3.2 G it/s, any depth). Safe on accuracy,
   slower than the PC.
3. **Build a narrow core** (M = 27-36) directly: 2x the rate, unknown accuracy.
4. **Perturbation on the PC** (in the viewer or the simulated server, C++ or numba), with BLA: the
   fastest deep zooms, but software, not FPGA work. Fits beside the FPGA: the board for views down to
   1e-35 at 64/128 bits, the PC deeper.
