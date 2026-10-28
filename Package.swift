// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TapeLogger",
    platforms: [
        .iOS(.v17),
        .macOS(.v14), // only so `swift test` can run locally: the target is iOS
    ],
    products: [
        .library(name: "TapeLogger", targets: ["TapeLogger"]),
        .library(name: "TapeLoggerUI", targets: ["TapeLoggerUI"]),
    ],
    targets: [
        .target(name: "TapeLogger"),
        .target(name: "TapeLoggerUI", dependencies: ["TapeLogger"]),
        .testTarget(name: "TapeLoggerTests", dependencies: ["TapeLogger"]),
    ],
    swiftLanguageModes: [.v6]
)
