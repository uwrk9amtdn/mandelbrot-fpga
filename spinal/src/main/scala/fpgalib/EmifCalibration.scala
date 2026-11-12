package fpgalib

import spinal.core._
import spinal.lib._
import spinal.lib.bus.amba4.axilite._

/** Polls the Agilex 5 EMIF calibration status register over the EMIF's AXI4-Lite port until
  * calibration passed (bit 0) or failed (bit 1). Same behaviour as Terasic's
  * axil_driver_calibration.sv (RTL_LPDDR4_AXI4_Test demo), which must be connected for the EMIF
  * to be usable.
  */
class EmifCalibration(statusAddr: BigInt = 0x05000400, addressWidth: Int = 27) extends Component {
  val io = new Bundle {
    val axil   = master(AxiLite4(AxiLite4Config(addressWidth, 32)))
    val done   = out Bool ()
    val failed = out Bool ()
  }

  io.axil.aw.valid   := False
  io.axil.aw.payload.assignDontCare()
  io.axil.w.valid    := False
  io.axil.w.payload.assignDontCare()
  io.axil.b.ready    := False

  object State extends SpinalEnum { val DELAY, READ, WAIT, FINISHED = newElement() }
  val state  = RegInit(State.DELAY)
  val delay  = Reg(UInt(4 bits)) init (7)
  val done   = RegInit(False)
  val failed = RegInit(False)
  io.done   := done
  io.failed := failed

  io.axil.ar.valid := state === State.READ
  io.axil.ar.addr  := statusAddr
  io.axil.ar.prot  := 0
  io.axil.r.ready  := state === State.WAIT

  switch(state) {
    is(State.DELAY) {
      delay := delay - 1
      when(delay === 0) { state := State.READ }
    }
    is(State.READ) {
      when(io.axil.ar.ready) { state := State.WAIT }
    }
    is(State.WAIT) {
      when(io.axil.r.valid) {
        done   := io.axil.r.data(0)
        failed := io.axil.r.data(1)
        delay  := 7
        state  := Mux(io.axil.r.data(0) || io.axil.r.data(1), State.FINISHED, State.DELAY)
      }
    }
    default {}
  }
}
