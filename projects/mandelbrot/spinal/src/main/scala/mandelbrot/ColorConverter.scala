package mandelbrot

import fpgalib._

import spinal.core._
import spinal.lib._

/** Palette settings for ColorConverter. Colors are 0xRRGGBB. */
case class Palette() extends Bundle {
  val startIndex = UInt(4 bits) // which iteration-count bits select the color (see ColorConverter)
  val twoColor   = Bool()       // only use colors 0 and 1
  val colors     = Vec(Bits(24 bits), 4)
}

object Palette {
  /** Reset values (SV: the vio_0 probe_out init values in vivado/generate_project.tcl). */
  def default: Palette = {
    val p = Palette()
    p.startIndex := 4
    p.twoColor   := True
    p.colors(0)  := B"x_ff0000"
    p.colors(1)  := B"x_00ff00"
    p.colors(2)  := B"x_0000ff"
    p.colors(3)  := B"x_ffff00"
    p
  }
}

/** Iteration count -> RGB (SV: color_converter.sv). Cycle-for-cycle identical to the SV.
  *
  * The count is viewed as `{2'b0, it[15:0], 8'b0}`. The 2 bits at `startIndex + 8` select a pair
  * of neighbouring colors (a, b), the 8 bits below them are the blend factor:
  * rgb = a + (b - a) * alpha, per channel. Latency: 3 stages here + 4 in LinearInterpolator.
  */
class ColorConverter extends Component with SvClockNames {
  val io = new Bundle {
    val palette = in(Palette())
    val s       = slave Stream (UInt(16 bits))
    val m       = master Stream (Bits(24 bits))
  }

  val lerps = for (c <- 0 until 3) yield new LinearInterpolator(8, 8, signed = false).setName(s"li_$c") // b, g, r

  val liValid = RegInit(False)
  val enable  = lerps(0).io.s.ready || !liValid
  io.s.ready := enable

  val padded = B(0, 2 bits) ## io.s.payload ## B(0, 8 bits) // SV it_zero_padded, 26 bits
  val mask   = Mux(io.palette.twoColor, U"01", U"11")

  val colorIndex  = Reg(UInt(2 bits))
  val colorIndexA = Reg(UInt(2 bits))
  val colorIndexB = Reg(UInt(2 bits))
  val a, b        = Reg(Bits(24 bits))
  val alphaReg    = Vec(Reg(UInt(8 bits)), 2)
  val alpha       = Reg(UInt(8 bits))
  val validReg    = Vec(RegInit(False), 2)

  when(enable) {
    colorIndex  := padded(io.palette.startIndex.resize(5) + 8, 2 bits).asUInt
    colorIndexA := mask & colorIndex
    colorIndexB := mask & (colorIndex + 1)
    a           := io.palette.colors(colorIndexA)
    b           := io.palette.colors(colorIndexB)

    alphaReg(0) := padded(io.palette.startIndex.resize(5), 8 bits).asUInt
    alphaReg(1) := alphaReg(0)
    alpha       := alphaReg(1)

    validReg(0) := io.s.valid
    validReg(1) := validReg(0)
    liValid     := validReg(1)
  }

  for ((li, c) <- lerps.zipWithIndex) {
    li.io.s.valid := liValid
    li.io.s.a     := a(8 * c, 8 bits)
    li.io.s.b     := b(8 * c, 8 bits)
    li.io.s.alpha := alpha
    li.io.m.ready := io.m.ready
  }
  io.m.valid   := lerps(0).io.m.valid
  io.m.payload := lerps(2).io.m.payload ## lerps(1).io.m.payload ## lerps(0).io.m.payload
}
