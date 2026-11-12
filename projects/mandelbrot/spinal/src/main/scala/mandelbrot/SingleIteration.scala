package mandelbrot

import fpgalib._

import spinal.core._
import spinal.lib._

/** One Mandelbrot iteration z' = z^2 + c, fully pipelined (SV: single_iteration.sv).
  *
  * Inputs: z = (a, b), c = (c, d). Outputs after `siLatency` cycles:
  *   m_a    = a^2 - b^2 + c   (wraps to dataWidth bits, like the SV)
  *   m_b    = 2ab + d
  *   m_stop = |z|^2 >= 4      (of the INPUT z)
  */
class SingleIteration(fracWidth: Int, siLatency: Int) extends Component {
  require(siLatency >= 4, "siLatency must be at least 4 (multipliers need latency >= 2)")

  val w          = fracWidth + 3
  val mulLatency = siLatency - 2
  val f          = fracWidth

  val io = new Bundle {
    val sA, sB, sC, sD = in SInt (w bits)
    val mA, mB         = out SInt (w bits)
    val mStop          = out Bool ()
  }

  private def mul(name: String, x: SInt, y: SInt): SInt = {
    val m = new MulPipe(w, mulLatency, signed = true).setName(name)
    m.io.a := x.asBits
    m.io.b := y.asBits
    m.io.q.asSInt // SV [5:-2F]
  }

  val a2 = mul("m0", io.sA, io.sA)
  val b2 = mul("m1", io.sB, io.sB)
  val ab = mul("m2", io.sA, io.sB)

  // c and d wait for the multipliers plus the add stage (SV: delayer, L + 1)
  val c = Delay(io.sC, mulLatency + 1)
  val d = Delay(io.sD, mulLatency + 1)

  // Stage 1 after the multipliers: full precision, SV [6:-2F] = 2w + 1 bits
  val a2PlusB2  = RegNext(a2.resize(2 * w + 1) + b2.resize(2 * w + 1))
  val a2MinusB2 = RegNext(a2.resize(2 * w + 1) - b2.resize(2 * w + 1))
  val abTimes2  = RegNext(ab << 1)

  // Stage 2: back to [2:-F]; SV slice [2:-F] of a [6:-2F] vector = bits (2F+2 downto F)
  private def toQ(v: SInt): SInt = v(2 * f + 2 downto f)

  io.mA    := RegNext(toQ(a2MinusB2) + c)
  io.mB    := RegNext(toQ(abTimes2) + d)
  io.mStop := RegNext(a2PlusB2(2 * f + 6 downto 2 * f + 2).asBits.orR) // SV |a2_plus_b2[6:2]
}
