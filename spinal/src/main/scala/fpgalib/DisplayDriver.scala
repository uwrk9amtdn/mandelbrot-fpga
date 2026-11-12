package fpgalib

import spinal.core._
import spinal.lib._

/** Video timing for one axis. Polarity: true = sync pulse is high. */
case class AxisTiming(active: Int, frontPorch: Int, syncWidth: Int, backPorch: Int, syncPositive: Boolean) {
  val total     = active + frontPorch + syncWidth + backPorch
  val syncStart = active + frontPorch
  val syncEnd   = syncStart + syncWidth
}

case class VideoTiming(h: AxisTiming, v: AxisTiming) {
  def pixelsPerFrame: Int = h.active * v.active
}

object VideoTiming {
  /** 1920x1080 @ 60 Hz, 148.5 MHz pixel clock (CEA-861 VIC 16), as used by top.sv. */
  val p1080 = VideoTiming(AxisTiming(1920, 88, 44, 148, true), AxisTiming(1080, 4, 5, 36, true))
}

/** Video timing generator (SV: hdmi/display_driver.sv).
  *
  * The counters start at the end of the sync pulses, like the SV. `rgb` is shown in the cycle
  * where `de` is high, combinationally (like the SV): register the outputs at the top level.
  * The SV `addr`, `x`, `y` outputs were unused and are left out.
  */
class DisplayDriver(t: VideoTiming) extends Component with SvClockNames {
  val io = new Bundle {
    val rgb   = in Bits (24 bits)
    val r, g, b = out Bits (8 bits)
    val hsync, vsync, de = out Bool ()
    val inVSync = out Bool () // inside the vertical sync pulse, whatever the polarity
  }

  val h = Reg(UInt(log2Up(t.h.total) bits)) init (t.h.syncEnd)
  val v = Reg(UInt(log2Up(t.v.total) bits)) init (t.v.syncEnd)

  val hLast = h === t.h.total - 1
  h := Mux(hLast, U(0), h + 1)
  when(hLast) { v := Mux(v === t.v.total - 1, U(0), v + 1) }

  private def inSync(c: UInt, a: AxisTiming) = c >= a.syncStart && c < a.syncEnd
  private def sync(c: UInt, a: AxisTiming)   = Bool(!a.syncPositive) ^ inSync(c, a)

  io.inVSync := inSync(v, t.v)

  io.r     := io.rgb(23 downto 16)
  io.g     := io.rgb(15 downto 8)
  io.b     := io.rgb(7 downto 0)
  io.hsync := sync(h, t.h)
  io.vsync := sync(v, t.v)
  io.de    := h < t.h.active && v < t.v.active
}
