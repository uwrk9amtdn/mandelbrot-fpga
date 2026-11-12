ThisBuild / scalaVersion := "2.13.12" // must match the Scala version SpinalHDL is built with
ThisBuild / organization := "mandelbrot"

val spinalVersion = "1.15.1"

// Generic blocks (DisplayDriver, I2cWriter, UartControl, MemoryReader, ...) live in the repo-level
// SpinalHDL library ../../../spinal (package fpgalib), built from source with this project.
lazy val fpgalib = RootProject(file("../../../spinal"))

lazy val root = (project in file("."))
  .dependsOn(fpgalib)
  .settings(
    name := "mandelbrot-spinal",
    libraryDependencies ++= Seq(
      "com.github.spinalhdl" %% "spinalhdl-core" % spinalVersion,
      "com.github.spinalhdl" %% "spinalhdl-lib"  % spinalVersion,
      compilerPlugin("com.github.spinalhdl" %% "spinalhdl-idsl-plugin" % spinalVersion),
      "org.scalatest" %% "scalatest" % "3.2.14" % Test
    ),
    fork := true,
    // Verilator workspaces are per test; keep suites sequential to avoid clashes
    Test / parallelExecution := false
  )
