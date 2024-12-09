val chiselVersion = "6.6.0"



lazy val commonSettings = Seq(
  name := "Chisel Example",
  version := "1.0",
  scalaVersion := "2.13.12",
  libraryDependencies ++= Seq(
    "org.scala-lang" %% "toolkit" % "0.1.7",
    "org.chipsalliance" %% "chisel" % chiselVersion),
    addCompilerPlugin("org.chipsalliance" % "chisel-plugin" % chiselVersion cross CrossVersion.full),
    scalacOptions ++= Seq("-deprecation","-unchecked","-language:reflectiveCalls", "-feature", "-Xcheckinit", "-Xfatal-warnings", "-Ywarn-dead-code", "-Ywarn-unused", "-Ymacro-annotations"),
    trapExit := false
  )

lazy val hello = (project in file("."))
  //.dependsOn(_)
  .settings(commonSettings)
//  .settings(assemblyJarName in assembly := "system.jar")
//  .settings(assemblyMergeStrategy in assembly := {
//    case PathList("META-INF", xs @ _*) => MergeStrategy.discard
//    case x => MergeStrategy.first
//  })




