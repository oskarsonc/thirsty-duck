// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ThirstyDuck",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "DuckCore"),
        .executableTarget(name: "ThirstyDuck", dependencies: ["DuckCore"]),
        .testTarget(name: "DuckCoreTests", dependencies: ["DuckCore"]),
    ]
)
