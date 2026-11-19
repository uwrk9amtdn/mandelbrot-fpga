package mandelbrot

import spinal.core._
import spinal.lib._

/** A pixel from the issuer, and whether its job asked for the cardioid/bulb test. */
case class CheckIn(cfg: AccelConfig) extends Bundle {
  val px   = CorePixel(cfg)
  val test = Bool()
}

/** The cardioid / period-2 bulb test (ROADMAP.md, phase 3), between the issuer and the cores.
  *
  * Bit-exact with `cardioid_bulb` in pc/mandelbrot/fixed.py: c = (x, y) truncated to G = 24 fraction
  * bits (X, Y), tested only for -1.25 <= X < 0.5 and |Y| < 0.75, then
  *   cardioid: a = X - 1/4, Q = floor((a² + Y²) / 2^G), S = Q + a:  4 Q S - Y² <= -2^32
  *   bulb:     c = X + 1:                                              c² + Y² <= 2^44 - 2^27
  * (units 2^-G and 2^-2G). Every operand fits 27 bits, so the four products take one DSP block
  * each. The margins cover all truncation: a pixel marked interior is inside.
  *
  * Five stages; all advance together when the output can move (one stall signal).
  */
class CardioidCheck(cfg: AccelConfig) extends Component {
  import cfg._
  val G = CardioidCheck.G

  val io = new Bundle {
    val s = slave Stream (CheckIn(cfg))
    val m = master Stream (CorePixel(cfg))
  }

  val en = Bool()
  io.s.ready := en
  private def stage[T <: Data](v: T): T = RegNextWhen(v, en)
  private def valid(v: Bool): Bool      = RegNextWhen(v, en) init (False)

  // stage 1: truncate to G fraction bits, range check, a and c
  def trunc(v: SInt): SInt = if (fracWidth >= G) v >> (fracWidth - G) else v << (G - fracWidth)
  val x = trunc(io.s.px.x)
  val y = trunc(io.s.px.y)
  private def lit(v: Long, like: SInt) = S(v, like.getWidth bits)
  val inRange = x >= lit(-5L << (G - 2), x) && x < lit(1L << (G - 1), x) &&
    y > lit(-(3L << (G - 2)), y) && y < lit(3L << (G - 2), y)
  val v1  = valid(io.s.valid)
  val px1 = stage(io.s.px)
  val t1  = stage(io.s.test && inRange)
  val a1  = stage(x.resize(27) - S(1 << (G - 2), 27 bits))
  val c1  = stage(x.resize(27) + S(1 << G, 27 bits))
  val y1  = stage(y.resize(27))

  // stage 2: the three squares
  val v2  = valid(v1)
  val px2 = stage(px1)
  val t2  = stage(t1)
  val a2  = stage(a1)
  val aa2 = stage(a1 * a1)
  val yy2 = stage(y1 * y1)
  val cc2 = stage(c1 * c1)

  // stage 3: Q, S and the bulb
  val q    = ((aa2 + yy2) >> G).resize(27)
  val v3   = valid(v2)
  val px3  = stage(px2)
  val t3   = stage(t2)
  val q3   = stage(q)
  val s3   = stage(q + a2)
  val yy3  = stage(yy2)
  val bulb = stage((cc2.resize(56) + yy2.resize(56)) <= S((BigInt(1) << 44) - (BigInt(1) << 27), 56 bits))

  // stage 4: Q S
  val v4    = valid(v3)
  val px4   = stage(px3)
  val t4    = stage(t3)
  val qs4   = stage(q3 * s3)
  val yy4   = stage(yy3)
  val bulb4 = stage(bulb)

  // stage 5: the cardioid
  val card = (qs4.resize(58) << 2).resize(58) - yy4.resize(58) <= S(-(BigInt(1) << 32), 58 bits)
  val v5   = valid(v4)
  val px5  = stage(px4)
  val in5  = stage(t4 && (card || bulb4))

  io.m.valid    := v5
  io.m.x        := px5.x
  io.m.y        := px5.y
  io.m.tag      := px5.tag
  io.m.interior := in5
  en := !v5 || io.m.ready
}

object CardioidCheck {
  val G = 24

  /** The model: whether c = (x, y), in units of 2^-F, is marked interior (`cardioid_bulb` in
    * pc/mandelbrot/fixed.py). */
  def inside(x: BigInt, y: BigInt, f: Int): Boolean = {
    def t(v: BigInt) = if (f >= G) v >> (f - G) else v << (G - f)
    val (xx, yy) = (t(x), t(y))
    if (!(xx >= -(BigInt(5) << (G - 2)) && xx < (BigInt(1) << (G - 1)) &&
          yy > -(BigInt(3) << (G - 2)) && yy < (BigInt(3) << (G - 2)))) return false
    val y2 = yy * yy
    val a  = xx - (BigInt(1) << (G - 2))
    val q  = (a * a + y2) >> G
    if (4 * q * (q + a) - y2 <= -(BigInt(1) << 32)) return true
    val c = xx + (BigInt(1) << G)
    c * c + y2 <= (BigInt(1) << 44) - (BigInt(1) << 27)
  }
}
