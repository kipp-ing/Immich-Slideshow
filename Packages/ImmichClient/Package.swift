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
        .library(name: "ImmichClientTestSupport", targets: ["ImmichClientTestSupport"]),
    ],
    targets: [
        .target(name: "ImmichClient"),
        .target(
            name: "ImmichClientTestSupport",
            dependencies: ["ImmichClient"]
        ),
        .testTarget(
            name: "ImmichClientTests",
            dependencies: ["ImmichClient", "ImmichClientTestSupport"]
        ),
    ]
)
