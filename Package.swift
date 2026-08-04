// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Cornerworld",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "GameCore", targets: ["GameCore"]),
        .library(name: "FarmCore", targets: ["FarmCore"]),
        .library(name: "CanopyCore", targets: ["CanopyCore"]),
        .executable(name: "cornerworld-cli", targets: ["GameCLI"]),
        .executable(name: "cornerworld-farm-cli", targets: ["FarmCLI"]),
        .executable(name: "cornerworld", targets: ["TrailApp"]),
    ],
    targets: [
        .target(name: "GameCore"),
        .target(name: "FarmCore"),
        .target(name: "CanopyCore"),
        .target(
            name: "DesktopHostCore",
            dependencies: ["GameCore", "FarmCore", "CanopyCore"]
        ),
        .executableTarget(name: "GameCLI", dependencies: ["GameCore"]),
        .executableTarget(name: "FarmCLI", dependencies: ["FarmCore"]),
        .executableTarget(
            name: "TrailApp",
            dependencies: ["GameCore", "FarmCore", "CanopyCore", "DesktopHostCore"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SpriteKit"),
            ]
        ),
        .testTarget(name: "GameCoreTests", dependencies: ["GameCore"]),
        .testTarget(name: "FarmCoreTests", dependencies: ["FarmCore"]),
        .testTarget(name: "CanopyCoreTests", dependencies: ["CanopyCore"]),
        .testTarget(name: "DesktopHostCoreTests", dependencies: ["DesktopHostCore"]),
    ]
)
