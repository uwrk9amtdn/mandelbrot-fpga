// fpgalib: reusable SpinalHDL blocks shared by the projects in ../projects.
// Projects use it as a source dependency, e.g. in projects/<name>/spinal/build.sbt:
//   lazy val fpgalib = RootProject(file("../../../spinal"))
//   lazy val root = (project in file(".")).dependsOn(fpgalib)
ThisBuild / scalaVersion := "2.13.12" // must match the Scala version SpinalHDL is built with
ThisBuild / organization := "fpgalib"

val spinalVersion = "1.15.1"

lazy val fpgalib = (project in file("."))
  .settings(
    name := "fpgalib",
    libraryDependencies ++= Seq(
      "com.github.spinalhdl" %% "spinalhdl-core" % spinalVersion,
      "com.github.spinalhdl" %% "spinalhdl-lib"  % spinalVersion,
      compilerPlugin("com.github.spinalhdl" %% "spinalhdl-idsl-plugin" % spinalVersion),
      "org.scalatest" %% "scalatest" % "3.2.14" % Test
    ),
    fork := true,
    Test / parallelExecution := false
  )
