// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HAControlKit",
    platforms: [.iOS(.v18), .macOS(.v14)],
    products: [.library(name: "HAControlKit", targets: ["HAControlKit"])],
    targets: [
        .target(name: "HAControlKit"),
        .testTarget(name: "HAControlKitTests", dependencies: ["HAControlKit"]),
    ]
)
