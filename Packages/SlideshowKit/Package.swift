// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SlideshowKit",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v18),
        .macOS(.v14),
    ],
    products: [
        .library(name: "SlideshowKit", targets: ["SlideshowKit"]),
    ],
    dependencies: [
        .package(path: "../ImmichClient"),
    ],
    targets: [
        .target(
            name: "SlideshowKit",
            dependencies: [
                .product(name: "ImmichClient", package: "ImmichClient"),
            ]
        ),
        .testTarget(
            name: "SlideshowKitTests",
            dependencies: [
                "SlideshowKit",
                .product(name: "ImmichClient", package: "ImmichClient"),
                .product(name: "ImmichClientTestSupport", package: "ImmichClient"),
            ]
        ),
    ]
)
