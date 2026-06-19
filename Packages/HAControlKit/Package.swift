// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HAControlKit",
    platforms: [.iOS(.v18), .macOS(.v14)],
    products: [
        .library(name: "HAControlKit", targets: ["HAControlKit"]),
        .library(name: "HAControlMQTT", targets: ["HAControlMQTT"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swift-server-community/mqtt-nio.git", from: "2.12.0"),
    ],
    targets: [
        .target(name: "HAControlKit"),
        .target(
            name: "HAControlMQTT",
            dependencies: [
                "HAControlKit",
                .product(name: "MQTTNIO", package: "mqtt-nio"),
            ]
        ),
        .testTarget(name: "HAControlKitTests", dependencies: ["HAControlKit"]),
    ]
)
