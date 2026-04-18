// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "PaktCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "PaktCore", targets: ["PaktCore"]),
    ],
    targets: [
        .target(name: "PaktCore"),
        .testTarget(name: "PaktCoreTests", dependencies: ["PaktCore"]),
    ]
)
