package fpgalib

import spinal.core._
import spinal.lib._

/** q = a + alpha * (b - a), rounded down (SV: misc/linear_interpolator.sv).
  *
  * `alpha` is an unsigned fraction with `precision` bits (SV `[-1:-PRECISION]`).
  * Four register stages, all enabled by `s.ready = m.ready || !m.valid`, so the
  * pipeline only stalls when its output is blocked. Cycle-for-cycle identical to the SV.
  */
case class LerpIn(width: Int, precision: Int) extends Bundle {
  val a, b  = Bits(width bits)
  val alpha = UInt(precision bits)
}

class LinearInterpolator(width: Int = 8, precision: Int = 8, signed: Boolean = false) extends Component {
  val io = new Bundle {
    val s = slave Stream (LerpIn(width, precision))
    val m = master Stream (Bits(width bits))
  }

  private def ext(v: Bits): SInt = if (signed) v.asSInt.resize(width + 1) else (False ## v).asSInt

  val mValid  = RegInit(False)
  val enable  = io.m.ready || !mValid
  io.s.ready := enable

  val a     = ext(io.s.a)
  val b     = ext(io.s.b)
  val alpha = (False ## io.s.alpha).asSInt // SV [0:-P], always positive

  val aReg     = Vec(Reg(SInt(width + 1 bits)), 3)
  val bReg     = Reg(SInt(width + 1 bits))
  val alphaReg = Vec(Reg(SInt(precision + 1 bits)), 2)
  val validReg = Vec(RegInit(False), 3)

  val bMinusA          = Reg(SInt(width + 2 bits))
  val alphaTimesBMinusA = Reg(SInt(width + 2 + precision bits)) // SV [WIDTH+1:-PRECISION]
  val q                = Reg(SInt(width + 3 + precision bits))  // SV [WIDTH+2:-PRECISION]

  when(enable) {
    aReg(0)     := a
    aReg(1)     := aReg(0)
    aReg(2)     := aReg(1)
    bReg        := b
    alphaReg(0) := alpha
    alphaReg(1) := alphaReg(0)
    validReg(0) := io.s.valid
    validReg(1) := validReg(0)
    validReg(2) := validReg(1)

    bMinusA           := bReg.resize(width + 2) - aReg(0).resize(width + 2)
    alphaTimesBMinusA := (bMinusA * alphaReg(1)).resize(width + 2 + precision)
    q                 := (aReg(2) << precision).resize(width + 3 + precision) + alphaTimesBMinusA.resize(width + 3 + precision)
    mValid            := validReg(2)
  }

  io.m.valid   := mValid
  io.m.payload := q(precision + width - 1 downto precision).asBits // SV q[WIDTH-1:0]
}
