package fpgalib

import spinal.core._
import spinal.lib._
import spinal.lib.bus.avalon._

/** Clock crossing for a pipelined Avalon-MM bus (read, write, waitrequest, readdatavalid,
  * byteenable; no bursts). One access at a time: the input waits until the output side has
  * finished the access, so it is slow (about 10 cycles) and meant for control registers.
  */
class AvalonMMCC(config: AvalonMMConfig, inCd: ClockDomain, outCd: ClockDomain) extends Component {
  require(!config.useBurstCount && config.useWaitRequestn && config.useReadDataValid)
  val io = new Bundle {
    val input  = slave(AvalonMM(config))
    val output = master(AvalonMM(config))
  }

  case class Cmd() extends Bundle {
    val write      = Bool()
    val address    = UInt(config.addressWidth bits)
    val data       = Bits(config.dataWidth bits)
    val byteEnable = Bits(config.dataWidth / 8 bits)
  }
  val cmdCC = new StreamCCByToggle(Cmd(), inCd, outCd)
  val rspCC = new StreamCCByToggle(Bits(config.dataWidth bits), outCd, inCd)

  val in = new ClockingArea(inCd) {
    val pending = RegInit(False)
    val cmd     = cmdCC.io.input
    cmd.valid           := (io.input.read || io.input.write) && !pending
    cmd.write           := io.input.write
    cmd.address         := io.input.address
    cmd.data            := io.input.writeData
    cmd.byteEnable      := (if (config.useByteEnable) io.input.byteEnable else B(cmd.byteEnable.getWidth bits, default -> True))
    when(cmd.fire)(pending := True)

    // The access is accepted (waitrequest low) when its response is back.
    val rsp = rspCC.io.output
    rsp.ready                := True
    io.input.waitRequestn    := rsp.valid
    when(rsp.fire)(pending := False)
    io.input.readDataValid   := RegNext(rsp.fire && io.input.read) init (False)
    io.input.readData        := RegNext(rsp.payload)
  }

  val out = new ClockingArea(outCd) {
    val cmd      = cmdCC.io.output
    val reading  = RegInit(False) // read accepted, waiting for its data
    val rspValid = RegInit(False)
    val rspData  = Reg(Bits(config.dataWidth bits))
    val free     = !reading && !rspValid
    io.output.read      := cmd.valid && !cmd.write && free
    io.output.write     := cmd.valid && cmd.write && free
    io.output.address   := cmd.address
    io.output.writeData := cmd.data
    if (config.useByteEnable) io.output.byteEnable := cmd.byteEnable
    val accepted = (io.output.read || io.output.write) && io.output.waitRequestn
    cmd.ready := accepted
    when(accepted) {
      when(cmd.write) {
        rspValid := True
        rspData  := 0
      } otherwise (reading := True)
    }
    when(reading && io.output.readDataValid) {
      reading  := False
      rspValid := True
      rspData  := io.output.readData
    }
    rspCC.io.input.valid   := rspValid
    rspCC.io.input.payload := rspData
    when(rspCC.io.input.fire)(rspValid := False)
  }
}
