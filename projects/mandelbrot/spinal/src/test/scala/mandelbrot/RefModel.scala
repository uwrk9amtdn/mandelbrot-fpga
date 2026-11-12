package mandelbrot

import fpgalib._

/** Bit-accurate software model of the hardware (fixed-point values as raw BigInt bit patterns). */
object RefModel {

  /** Interpret the low `bits` bits of v as a two's complement number. */
  def wrap(v: BigInt, bits: Int): BigInt = {
    val m = BigInt(1) << bits
    val r = ((v % m) + m) % m
    if (r >= (m >> 1)) r - m else r
  }

  /** One SingleIteration step: (m_a, m_b, m_stop) for inputs z = (a, b), c = (c, d). */
  def iterate(a: BigInt, b: BigInt, c: BigInt, d: BigInt, fracWidth: Int): (BigInt, BigInt, Boolean) = {
    val w   = fracWidth + 3
    val a2  = a * a // exact: fits the 2w-bit product
    val b2  = b * b
    val ab  = a * b
    // slice [2:-F] of the [6:-2F] intermediates = arithmetic shift by F, then wrap to w bits
    val mA   = wrap(((a2 - b2) >> fracWidth) + c, w)
    val mB   = wrap(((ab << 1) >> fracWidth) + d, w)
    val sum  = wrap(a2 + b2, 2 * w + 1)
    val stop = ((sum >> (2 * fracWidth + 2)) & 0x1F) != 0 // |sum[6:2]
    (mA, mB, stop)
  }

  /** Iteration count reported by Core for point c = (cx, cy). */
  def iterations(cx: BigInt, cy: BigInt, maxIt: Int, fracWidth: Int): Int = {
    var za = BigInt(0)
    var zb = BigInt(0)
    var k  = 1
    while (true) {
      val (na, nb, stop) = iterate(za, zb, cx, cy, fracWidth) // stop refers to z_{k-1}
      if (stop || k >= maxIt) return k
      za = na
      zb = nb
      k += 1
    }
    k
  }

  case class Cmd(xStart: BigInt, yStart: BigInt, xyStep: BigInt, maxIt: Int)

  /** Output words (data, last) of one frame, starting at burst address `addr`. Returns the next address. */
  def frame(cfg: MandelbrotConfig, cmd: Cmd, addr: BigInt): (Seq[(Int, Boolean)], BigInt) = {
    val w = cfg.dataWidth
    val counts = for {
      yi <- 0 until cfg.yRes
      xi <- 0 until cfg.xRes
    } yield {
      val x = wrap(cmd.xStart + cmd.xyStep * xi, w)
      val y = wrap(cmd.yStart - cmd.xyStep * yi, w)
      iterations(x, y, cmd.maxIt, cfg.fracWidth)
    }
    var a     = addr
    val words = Seq.newBuilder[(Int, Boolean)]
    for (burst <- counts.grouped(cfg.n)) {
      words += (((a >> 16) & 0xFFFF).toInt -> false)
      words += ((a & 0xFFFF).toInt -> false)
      burst.zipWithIndex.foreach { case (it, i) => words += (it -> (i == cfg.n - 1)) }
      a = if (a == cfg.lastAddr) cfg.startAddr else (a + 2 * cfg.n) & 0xFFFFFFFFL
    }
    (words.result(), a)
  }

  case class View(centerX: BigInt, centerY: BigInt, xyStep: BigInt, maxIt: Int)

  /** Packets (address, iteration counts) a Wrapper produces for one view, per core in order.
    * `addrs(i)` is core i's current burst address; it is advanced in place.
    */
  def wrapperFrame(cfg: WrapperConfig, v: View, addrs: Array[BigInt]): Seq[(BigInt, Seq[Int])] = {
    val w         = cfg.w
    val topLeftX  = wrap(v.centerX - wrap(v.xyStep * (cfg.xRes / 2), w), w)
    val topLeftY  = wrap(v.centerY + wrap(v.xyStep * (cfg.yRes / 2), w), w)
    val coreYStep = wrap(v.xyStep * (cfg.yRes / cfg.nCores), w)
    (0 until cfg.nCores).flatMap { i =>
      val cmd           = Cmd(topLeftX, wrap(topLeftY - coreYStep * i, w), v.xyStep, v.maxIt)
      val (words, next) = frame(cfg.core(i), cmd, addrs(i))
      addrs(i) = next
      words.map(_._1).grouped(cfg.burstLength + 2).map { p =>
        ((BigInt(p(0)) << 16) | p(1), p.drop(2))
      }
    }
  }

  /** Fixed-point helper: real number to raw bits. */
  def fix(v: Double, fracWidth: Int): BigInt = BigInt(math.round(v * (1L << fracWidth)))
}
