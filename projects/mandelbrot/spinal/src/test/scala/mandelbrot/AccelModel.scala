package mandelbrot

/** Bit-accurate software model of the per-slot cores and of MandelbrotAccel's results. */
object AccelModel {
  import RefModel.wrap

  val Unresolved = 0xFFFFFFFFL
  val Interior   = 0xFFFFFFFEL

  /** A pixel's result: (count, |z|² at escape with cfg.magFrac fraction bits). count is the
    * smallest n >= 1 with |z_n|² >= 4, or Unresolved (then |z|² is 0) if there is none up to maxIt.
    */
  def pixel(cfg: AccelConfig, cx: BigInt, cy: BigInt, maxIt: Long, periodic: Boolean = false): (Long, Long) = {
    val f      = cfg.fracWidth
    var a, b   = BigInt(0)
    var sa, sb = BigInt(0)
    var n      = 0L
    while (n < maxIt) {
      val na = wrap(((a * a - b * b) >> f) + cx, cfg.w)
      val nb = wrap(((a * b * 2) >> f) + cy, cfg.w)
      a = na; b = nb; n += 1
      if (periodic) { // (Interior, k): see WideModel.pixel
        if (a == sa && b == sb) return (Interior, n)
        if (WideModel.periodRefresh(n)) { sa = a; sb = b }
      }
      val sum = a * a + b * b
      if ((sum >> (2 * f + 2)) != 0) {
        val mag = if (2 * f >= cfg.magFrac) sum >> (2 * f - cfg.magFrac) else sum << (cfg.magFrac - 2 * f)
        return (n, (mag & 0xFFFFFFFFL).toLong)
      }
    }
    (Unresolved, 0L)
  }

  /** The f32 the accelerator stores for a |z|² value: truncated, not rounded. */
  def magToFloatBits(cfg: AccelConfig, mag: Long): Long = {
    if (mag == 0) return 0L
    val top  = 63 - java.lang.Long.numberOfLeadingZeros(mag)
    val mant = if (top >= 23) (mag >> (top - 23)) else (mag << (23 - top))
    ((top - cfg.magFrac + 127).toLong << 23) | (mant & 0x7FFFFFL)
  }

  /** The 64-bit record of a pixel: count in the low half, f32 |z|² in the high half. */
  def record(cfg: AccelConfig, cx: BigInt, cy: BigInt, maxIt: Long, flags: Int = 0): BigInt = {
    if ((flags & AccelRegs.FLAG_CARDIOID) != 0 && CardioidCheck.inside(cx, cy, cfg.fracWidth)) return BigInt(Interior)
    val (count, mag) = pixel(cfg, cx, cy, maxIt, (flags & AccelRegs.FLAG_PERIODICITY) != 0)
    if (count == Interior) (BigInt(mag) << 32) | Interior
    else (BigInt(magToFloatBits(cfg, mag)) << 32) | count
  }

  /** Records of a tile, row-major: c = (x0 + col * step, y0 - row * step). */
  def tile(cfg: AccelConfig, x0: BigInt, y0: BigInt, step: BigInt, width: Int, height: Int, maxIt: Long,
           flags: Int = 0): Seq[BigInt] =
    for (row <- 0 until height; col <- 0 until width)
      yield record(cfg, wrap(x0 + step * col, cfg.w), wrap(y0 - step * row, cfg.w), maxIt, flags)

  /** DONE_ITERATIONS of a tile: the counts, max_it for unresolved pixels, the proof iteration for
    * proven ones (0 for the cardioid test). */
  def iterations(records: Seq[BigInt], maxIt: Long): BigInt =
    records.map { r =>
      (r & 0xFFFFFFFFL).toLong match {
        case Unresolved => BigInt(maxIt)
        case Interior   => r >> 32
        case c          => BigInt(c)
      }
    }.sum
}
