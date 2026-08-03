// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Cornerworld",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "GameCore", targets: ["GameCore"]),
        .library(name: "FarmCore", targets: ["FarmCore"]),
        .executable(name: "cornerworld-cli", targets: ["GameCLI"]),
        .executable(name: "cornerworld-farm-cli", targets: ["FarmCLI"]),
        .executable(name: "cornerworld", targets: ["TrailApp"]),
    ],
    targets: [
        .target(name: "GameCore"),
        .target(name: "FarmCore"),
        .target(
            name: "DesktopHostCore",
            dependencies: ["GameCore", "FarmCore"]
        ),
        .executableTarget(name: "GameCLI", dependencies: ["GameCore"]),
        .executableTarget(name: "FarmCLI", dependencies: ["FarmCore"]),
        .executableTarget(
            name: "TrailApp",
            dependencies: ["GameCore", "FarmCore", "DesktopHostCore"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SpriteKit"),
            ]
        ),
        .testTarget(name: "GameCoreTests", dependencies: ["GameCore"]),
        .testTarget(name: "FarmCoreTests", dependencies: ["FarmCore"]),
        .testTarget(name: "DesktopHostCoreTests", dependencies: ["DesktopHostCore"]),
    ]
)
