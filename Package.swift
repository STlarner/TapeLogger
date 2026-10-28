// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TapeLogger",
    platforms: [
        .iOS(.v17),
        .macOS(.v14), // solo per `swift test` in locale: il target è iOS
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
