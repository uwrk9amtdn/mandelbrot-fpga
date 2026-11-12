package fpgalib

import spinal.core._
import spinal.lib._

/** Pipelined multiplier (SV: arithmetic/mul_dsp.sv).
  *
  * Registers both inputs, multiplies, then delays the product by `latency - 1`
  * registers, so the total latency is `latency` cycles. On FPGAs the registers
  * map onto the DSP block's input / output pipeline registers.
  */
class MulPipe(width: Int, latency: Int, signed: Boolean) extends Component {
  require(latency >= 2, "MulPipe latency must be at least 2")

  val io = new Bundle {
    val a = in Bits (width bits)
    val b = in Bits (width bits)
    val q = out Bits (2 * width bits)
  }

  addAttribute("use_dsp", "true")

  val aReg = RegNext(io.a)
  val bReg = RegNext(io.b)

  val product =
    if (signed) (aReg.asSInt * bReg.asSInt).asBits
    else (aReg.asUInt * bReg.asUInt).asBits

  io.q := Delay(product, latency - 1)
}
