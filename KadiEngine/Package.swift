// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KadiEngine",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "KadiEngine", targets: ["KadiEngine"]),
    ],
    targets: [
        .target(name: "KadiEngine"),
        .testTarget(name: "KadiEngineTests", dependencies: ["KadiEngine"]),
    ],
    swiftLanguageModes: [.v5]
)
