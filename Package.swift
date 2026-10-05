// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Rivet",
    platforms: [.macOS("27.0")],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0")
    ],
    targets: [
        .executableTarget(
            name: "rivet",
            dependencies: [
                "RivetKit",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .target(name: "RivetKit"),
        .testTarget(name: "RivetKitTests", dependencies: ["RivetKit"]),
    ]
)
