// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Cornerworld",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "GameCore", targets: ["GameCore"]),
        .executable(name: "cornerworld-cli", targets: ["GameCLI"]),
        .executable(name: "cornerworld", targets: ["TrailApp"]),
    ],
    targets: [
        .target(name: "GameCore"),
        .executableTarget(name: "GameCLI", dependencies: ["GameCore"]),
        .executableTarget(
            name: "TrailApp",
            dependencies: ["GameCore"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SpriteKit"),
            ]
        ),
        .testTarget(name: "GameCoreTests", dependencies: ["GameCore"]),
    ]
)
