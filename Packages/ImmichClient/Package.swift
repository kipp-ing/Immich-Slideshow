// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ImmichClient",
    platforms: [
        // iPadOS-Ziel der App; macOS, damit `swift test` auf dem Host (ohne Simulator) läuft.
        .iOS(.v18),
        .macOS(.v14),
    ],
    products: [
        .library(name: "ImmichClient", targets: ["ImmichClient"]),
    ],
    targets: [
        .target(name: "ImmichClient"),
        .testTarget(
            name: "ImmichClientTests",
            dependencies: ["ImmichClient"]
        ),
    ]
)
