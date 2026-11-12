package mandelbrot

import fpgalib._

import org.scalatest.funsuite.AnyFunSuite
import spinal.core._
import spinal.core.sim._
import spinal.lib.sim._

import scala.collection.mutable

/** Software model of color_converter.sv / ColorConverter. */
object ColorModel {
  case class Pal(startIndex: Int, twoColor: Boolean, colors: Seq[Int])
  val default = Pal(4, twoColor = true, Seq(0xff0000, 0x00ff00, 0x0000ff, 0xffff00))

  /** a + alpha * (b - a), rounded down (linear_interpolator.sv, unsigned 8 bit, 8-bit alpha). */
  def lerp(a: Int, b: Int, alpha: Int): Int = (((a << 8) + alpha * (b - a)) >> 8) & 0xff

  def rgb(it: Int, p: Pal): Int = {
    val padded = it.toLong << 8
    val ci     = ((padded >> (p.startIndex + 8)) & 3).toInt
    val alpha  = ((padded >> p.startIndex) & 0xff).toInt
    val mask   = if (p.twoColor) 1 else 3
    val a      = p.colors(ci & mask)
    val b      = p.colors((ci + 1) & mask)
    (0 until 3).map(c => lerp((a >> (8 * c)) & 0xff, (b >> (8 * c)) & 0xff, alpha) << (8 * c)).sum
  }
}

class ColorConverterSim extends AnyFunSuite {
  test("random counts and palettes, random valid/ready") {
    MandelbrotSpinalConfig.sim.workspaceName("ColorConverter").compile(new ColorConverter).doSim(seed = 7) { dut =>
      val cd = dut.clockDomain
      dut.io.s.valid #= false
      cd.forkStimulus(10)
      cd.waitSampling(3)

      val expected = mutable.Queue[Int]()
      var round    = 0
      var got      = 0
      StreamMonitor(dut.io.m, cd) { p =>
        val e = expected.dequeue()
        assert(p.toInt == e, f"round $round: got ${p.toInt}%06x, expected $e%06x")
        got += 1
      }
      StreamReadyRandomizer(dut.io.m, cd)

      val n = 2000
      for (r <- 0 until 6) {
        round = r
        // the palette only changes while the pipeline is empty
        val pal = if (r == 0) ColorModel.default
                  else ColorModel.Pal(simRandom.nextInt(16), simRandom.nextBoolean(), Seq.fill(4)(simRandom.nextInt(1 << 24)))
        dut.io.palette.startIndex #= pal.startIndex
        dut.io.palette.twoColor   #= pal.twoColor
        for (i <- 0 until 4) dut.io.palette.colors(i) #= pal.colors(i)

        var sent = 0
        while (sent < n) {
          val it = if (simRandom.nextBoolean()) simRandom.nextInt(1 << 16) else simRandom.nextInt(512)
          dut.io.s.payload #= it
          dut.io.s.valid   #= simRandom.nextInt(4) != 0
          cd.waitSampling()
          if (dut.io.s.valid.toBoolean && dut.io.s.ready.toBoolean) {
            expected += ColorModel.rgb(it, pal)
            sent += 1
          }
        }
        dut.io.s.valid #= false
        cd.waitSamplingWhere(got == n * (r + 1))
        cd.waitSampling(10)
      }
    }
  }
}
