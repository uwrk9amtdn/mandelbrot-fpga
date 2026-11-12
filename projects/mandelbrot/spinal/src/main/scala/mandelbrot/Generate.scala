package mandelbrot

import fpgalib._

/** Generates Verilog for CoreWrapper.
  *
  * Usage: sbt "runMain mandelbrot.GenerateVerilog [key=value ...]"
  * Keys: startAddr xRes yRes n fracWidth siLatency targetDir
  * Numbers may be decimal or 0x-prefixed hex. Example:
  *   sbt "runMain mandelbrot.GenerateVerilog xRes=2048 yRes=512 n=16 fracWidth=16 siLatency=4"
  */
object GenerateVerilog {
  private val keys = Set("startAddr", "xRes", "yRes", "n", "fracWidth", "siLatency", "targetDir")

  private def num(s: String): BigInt =
    if (s.startsWith("0x") || s.startsWith("0X")) BigInt(s.drop(2), 16) else BigInt(s)

  def main(args: Array[String]): Unit = {
    val kv = args.map { a =>
      a.split("=", 2) match {
        case Array(k, v) if keys(k) => k -> v
        case _ => sys.error(s"bad argument '$a', expected key=value with key in ${keys.mkString(", ")}")
      }
    }.toMap

    val d = MandelbrotConfig()
    val cfg = MandelbrotConfig(
      startAddr = kv.get("startAddr").map(num).getOrElse(d.startAddr),
      xRes      = kv.get("xRes").map(num(_).toInt).getOrElse(d.xRes),
      yRes      = kv.get("yRes").map(num(_).toInt).getOrElse(d.yRes),
      n         = kv.get("n").map(num(_).toInt).getOrElse(d.n),
      fracWidth = kv.get("fracWidth").map(num(_).toInt).getOrElse(d.fracWidth),
      siLatency = kv.get("siLatency").map(num(_).toInt).getOrElse(d.siLatency)
    )
    println(s"[mandelbrot] generating CoreWrapper with $cfg")
    MandelbrotSpinalConfig(kv.getOrElse("targetDir", "gen")).generateVerilog(new CoreWrapper(cfg))
  }
}

/** Generates Verilog for Wrapper.
  *
  * Usage: sbt "runMain mandelbrot.GenerateWrapper [key=value ...]"
  * Keys: xRes yRes fracWidth nCores arbiterTreeSans burstLength fbStartAddr dataWidth siLatency targetDir
  */
object GenerateWrapper {
  private val keys = Set("xRes", "yRes", "fracWidth", "nCores", "arbiterTreeSans", "burstLength",
    "fbStartAddr", "dataWidth", "siLatency", "targetDir")

  private def num(s: String): BigInt =
    if (s.startsWith("0x") || s.startsWith("0X")) BigInt(s.drop(2), 16) else BigInt(s)

  def main(args: Array[String]): Unit = {
    val kv = args.map { a =>
      a.split("=", 2) match {
        case Array(k, v) if keys(k) => k -> v
        case _ => sys.error(s"bad argument '$a', expected key=value with key in ${keys.mkString(", ")}")
      }
    }.toMap
    def int(k: String, d: Int) = kv.get(k).map(num(_).toInt).getOrElse(d)

    val d = WrapperConfig()
    val cfg = WrapperConfig(
      xRes = int("xRes", d.xRes),
      yRes = int("yRes", d.yRes),
      fracWidth = int("fracWidth", d.fracWidth),
      nCores = int("nCores", d.nCores),
      arbiterTreeSans = int("arbiterTreeSans", d.arbiterTreeSans),
      burstLength = int("burstLength", d.burstLength),
      fbStartAddr = kv.get("fbStartAddr").map(num).getOrElse(d.fbStartAddr),
      dataWidth = int("dataWidth", d.dataWidth),
      siLatency = int("siLatency", d.siLatency)
    )
    println(s"[mandelbrot] generating Wrapper with $cfg")
    MandelbrotSpinalConfig(kv.getOrElse("targetDir", "gen")).generateVerilog(new Wrapper(cfg))
  }
}

/** Generates ColorConverter and DisplayDriver (1080p timing) for the co-simulation against the SV.
  *
  * Usage: sbt "runMain mandelbrot.GenerateParts [targetDir]"
  */
object GenerateParts {
  def main(args: Array[String]): Unit = {
    val dir = args.headOption.getOrElse("gen")
    MandelbrotSpinalConfig(dir).generateVerilog(new ColorConverter)
    MandelbrotSpinalConfig(dir).generateVerilog(new DisplayDriver(VideoTiming.p1080))
  }
}

/** Generates the DE25-Nano top level (De25NanoTop.v) for quartus/.
  *
  * Usage: sbt "runMain mandelbrot.GenerateDe25Nano [key=value ...]"
  * Keys: coreMHz nCores fracWidth arbiterTreeSans siLatency targetDir
  * coreMHz must match the core clock that quartus/Makefile asks the IOPLL for (CORE_MHZ there).
  */
object GenerateDe25Nano {
  private val keys = Set("coreMHz", "nCores", "fracWidth", "arbiterTreeSans", "siLatency", "targetDir")

  def main(args: Array[String]): Unit = {
    val kv = args.map { a =>
      a.split("=", 2) match {
        case Array(k, v) if keys(k) => k -> v
        case _ => sys.error(s"bad argument '$a', expected key=value with key in ${keys.mkString(", ")}")
      }
    }.toMap
    val d  = SystemConfig()
    val dw = d.wrapper
    def int(k: String, v: Int) = kv.get(k).map(_.toInt).getOrElse(v)
    val cfg = d.copy(
      wrapper = dw.copy(
        nCores = int("nCores", dw.nCores),
        fracWidth = int("fracWidth", dw.fracWidth),
        arbiterTreeSans = int("arbiterTreeSans", dw.arbiterTreeSans),
        siLatency = int("siLatency", dw.siLatency)
      ),
      coreHz = kv.get("coreMHz").map(_.toDouble * 1e6).getOrElse(d.coreHz)
    )
    println(s"[mandelbrot] generating De25NanoTop with $cfg")
    MandelbrotSpinalConfig(kv.getOrElse("targetDir", "gen"))
      .generateVerilog(new De25NanoTop(cfg))
  }
}
