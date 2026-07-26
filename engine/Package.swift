// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PunctuationEngine",
    products: [
        .library(name: "PunctuationEngine", targets: ["PunctuationEngine"])
    ],
    targets: [
        .target(name: "PunctuationEngine"),
        .testTarget(name: "PunctuationEngineTests", dependencies: ["PunctuationEngine"])
    ]
)
