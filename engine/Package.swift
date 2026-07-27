// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PunctuationEngine",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [
        .library(name: "PunctuationEngine", targets: ["PunctuationEngine"]),
        .library(name: "TypingEngine", targets: ["TypingEngine"])
    ],
    targets: [
        .target(name: "PunctuationEngine"),
        .testTarget(name: "PunctuationEngineTests", dependencies: ["PunctuationEngine"]),
        .target(name: "TypingEngine", dependencies: ["PunctuationEngine"]),
        .testTarget(name: "TypingEngineTests", dependencies: ["TypingEngine"])
    ]
)
