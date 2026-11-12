package fpgalib

import spinal.core._

/** Names the implicit clock and reset `clk` / `rst` like the SV modules (default would be `reset`).
  * Mix into components that can be a top level.
  */
trait SvClockNames { this: Component =>
  ClockDomain.current.renamePulledWires(clock = "clk", reset = "rst")
}
