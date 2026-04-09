// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "TossKit",
  platforms: [
    .iOS(.v18),
    .macOS(.v15),
  ],
  products: [
    .library(name: "TossKit", targets: ["TossKit"])
  ],
  targets: [
    .target(name: "TossKit")
  ]
)
