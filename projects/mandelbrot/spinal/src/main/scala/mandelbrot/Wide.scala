package mandelbrot

import fpgalib._

import spinal.core._
import spinal.lib._

/** The wide number format and its squaring scheme (ROADMAP.md, phase 2). Bit-exact with
  * pc/mandelbrot/fixed.py (WideFormat), which documents the arithmetic.
  *
  * W-bit two's complement, I integer bits (sign included), F = W - I fraction bits. A square splits
  * its magnitude operand into 26-bit limbs and multiplies the pairs i <= j, leaving out the lowest
  * diagonals i + j < K whose products are worth less than a quarter ulp in total.
  */
case class WideParams(w: Int, i: Int = 10, r2: Int = 256) {
  require(w >= 32 && i >= 6)
  val f        = w - i
  val limbBits = 26
  val limbs    = (w + limbBits - 1) / limbBits // |x + y| has up to W magnitude bits

  /** K: partial products with i + j < K are left out. */
  val droppedDiagonals: Int = {
    val quarterUlp = BigInt(1) << (f - 2)
    val biggest    = ((BigInt(1) << limbBits) - 1).pow(2)
    var total      = BigInt(0)
    var k          = 0
    var done       = false
    while (!done && k <= 2 * (limbs - 1)) {
      val diag = (0 until limbs).filter(a => a <= k - a && k - a < limbs)
        .map(a => (biggest * (if (a == k - a) 1 else 2)) << (limbBits * k)).sum
      if (total + diag >= quarterUlp) done = true
      else {
        total += diag
        k += 1
      }
    }
    k
  }

  /** The limb pairs (i, j), i <= j, that are multiplied. */
  val products: Seq[(Int, Int)] =
    for (a <- 0 until limbs; b <- a until limbs if a + b >= droppedDiagonals) yield (a, b)

  /** Integer bits of a square's result: |x + y| < 2^I. */
  val sqIntBits = 2 * i
  val sqBits    = f + sqIntBits

  /** |z|^2 at escape is below 2^19 for I = 10 (|z_n| < 272, or z_1 = c with |c| < 512). It is
    * passed on as fixed point with magFrac fraction bits, enough for the 24 bits of an f32. */
  val magIntBits = 2 * i - 1
  val magFrac    = 29
  val magBits    = magIntBits + magFrac
  require(f >= magFrac)
}

/** Bit-exact software model, the same as fixed.py. Values are raw BigInts in units of 2^-F. */
object WideModel {
  def wrap(v: BigInt, bits: Int): BigInt = {
    val m = BigInt(1) << bits
    val r = ((v % m) + m) % m
    if (r >= (m >> 1)) r - m else r
  }

  def square(p: WideParams, m: BigInt): BigInt = {
    require(m >= 0 && m < (BigInt(1) << (p.limbBits * p.limbs)))
    val mask = (BigInt(1) << p.limbBits) - 1
    val limb = (0 until p.limbs).map(k => (m >> (p.limbBits * k)) & mask)
    p.products.map { case (a, b) =>
      (limb(a) * limb(b) * (if (a == b) 1 else 2)) << (p.limbBits * (a + b))
    }.sum >> p.f
  }

  /** One pass: (x', y', |z|^2 of the input). */
  def step(p: WideParams, x: BigInt, y: BigInt, cx: BigInt, cy: BigInt): (BigInt, BigInt, BigInt) = {
    val x2 = square(p, x.abs)
    val y2 = square(p, y.abs)
    val s2 = square(p, (x + y).abs)
    (wrap(x2 - y2 + cx, p.w), wrap(s2 - x2 - y2 + cy, p.w), x2 + y2)
  }

  val Unresolved = 0xFFFFFFFFL
  val Interior   = 0xFFFFFFFEL

  /** The periodicity check saves z_n after testing it when n has at most 3 significant bits
    * (`period_refresh` in pc/mandelbrot/fixed.py). */
  def periodRefresh(n: Long): Boolean = ((n & -n) << 3) > n

  /** (count, |z_n|^2 at escape in units 2^-F), or (Unresolved, 0), or with `periodic` (Interior, k):
    * z_k equals the saved z bit for bit (`pixel` in pc/mandelbrot/fixed.py). */
  def pixel(p: WideParams, cx: BigInt, cy: BigInt, maxIt: Long, periodic: Boolean = false): (Long, BigInt) = {
    val bail = BigInt(p.r2) << p.f
    var x, y   = BigInt(0)
    var sx, sy = BigInt(0)
    var n      = 0L
    while (n < maxIt) {
      val (nx, ny, _) = step(p, x, y, cx, cy)
      x = nx; y = ny; n += 1
      if (periodic) {
        if (x == sx && y == sy) return (Interior, BigInt(n))
        if (periodRefresh(n)) { sx = x; sy = y }
      }
      val mag = square(p, x.abs) + square(p, y.abs)
      if (mag >= bail) return (n, mag)
    }
    (Unresolved, BigInt(0))
  }

  def magToF32Bits(p: WideParams, mag: BigInt): Long = {
    if (mag == 0) return 0L
    val top  = mag.bitLength - 1
    val mant = if (top >= 23) mag >> (top - 23) else mag << (23 - top)
    ((top - p.f + 127).toLong << 23) | (mant & 0x7FFFFF).toLong
  }
}

/** Truncated square of a magnitude (WideModel.square), pipelined: the partial products in DSP
  * blocks (26x26 unsigned), then an adder tree with a register after each level.
  * Latency: mulLatency + ceil(log2(products)).
  */
class WideSquare(p: WideParams, mulLatency: Int = 3) extends Component {
  import p._
  val io = new Bundle {
    val a = in UInt (limbBits * limbs bits)
    val q = out UInt (sqBits bits) // the square >> F, low sqBits bits
  }
  val base  = limbBits * droppedDiagonals // the lowest kept product starts here
  val width = limbBits * (2 * limbs - 2) + 2 * limbBits + 1 - base

  val terms = products.map { case (a, b) =>
    val m = new MulPipe(limbBits, mulLatency, signed = false)
    m.io.a := io.a(limbBits * a, limbBits bits).asBits
    m.io.b := io.a(limbBits * b, limbBits bits).asBits
    val shift = limbBits * (a + b) + (if (a == b) 0 else 1) - base
    (m.io.q.asUInt.resize(width) |<< shift).setName(s"pp_${a}_$b")
  }

  def tree(xs: Seq[UInt]): UInt =
    if (xs.size == 1) xs.head
    else tree(xs.grouped(2).map(g => if (g.size == 1) RegNext(g.head) else RegNext(g(0) + g(1))).toSeq)
  val sum = tree(terms)
  io.q := (sum >> (f - base)).resize(sqBits)

  val levels  = log2Up(products.size)
  val latency = mulLatency + levels
}

/** The wide iteration (phase 2): z' = z² + c from three truncated squares (WideModel.step).
  *
  *   stage 0          the inputs registered (the slot logic in front of them is long)
  *   stage 1          |x|, |y|, x + y
  *   stage 2          |x + y|
  *   WideSquare x 3   X2, Y2, S2
  *   stage A          |z|² = X2 + Y2, X2 - Y2 + cx, S2 + cy
  *   stage B          x', y' = S2 + cy - |z|², escape test |z|² >= R², |z|² for the output
  *
  * x' and y' are computed modulo 2^W: only the low W bits of each term matter (no overflow can
  * happen while a pixel iterates, see fixed.py).
  */
class WideIteration(cfg: AccelConfig) extends IterationUnit(cfg) {
  val p = cfg.wideParams
  import p._
  require(isPow2(r2), "the escape test looks at the bits above R^2")

  val opBits = limbBits * limbs
  // stage 0: one carry chain per stage below, nothing in front of it
  val x0  = RegNext(io.sA)
  val y0  = RegNext(io.sB)
  // stage 1
  val ax1 = RegNext(x0.abs.resize(opBits))
  val ay1 = RegNext(y0.abs.resize(opBits))
  val s1  = RegNext(x0.resize(w + 1) + y0.resize(w + 1))
  // stage 2
  val ax  = RegNext(ax1)
  val ay  = RegNext(ay1)
  val as  = RegNext(s1.abs.resize(opBits))
  val c0  = Delay(io.sC, 3)
  val d0  = Delay(io.sD, 3)

  def square(name: String, a: UInt): (UInt, Int) = {
    val sq = new WideSquare(p).setName(name)
    sq.io.a := a
    (sq.io.q, sq.latency)
  }
  val (x2, lat) = square("sqX", ax)
  val (y2, _)   = square("sqY", ay)
  val (s2, _)   = square("sqS", as)
  val c         = Delay(c0, lat)
  val d         = Delay(d0, lat)

  // stage A
  val mag = RegNext(x2.resize(sqBits + 1) + y2.resize(sqBits + 1))
  val re  = RegNext(x2.resize(w) - y2.resize(w) + c.asUInt)
  val im  = RegNext(s2.resize(w) + d.asUInt)

  // stage B
  io.mA    := RegNext(re).asSInt
  io.mB    := RegNext(im - mag.resize(w)).asSInt
  io.mStop := RegNext(mag(sqBits downto f + log2Up(r2)).orR)
  io.mMag  := RegNext((mag >> (f - magFrac)).resize(magBits))
}

object WideIteration {
  def latency(p: WideParams, mulLatency: Int = 3): Int = 3 + mulLatency + log2Up(p.products.size) + 2
}
