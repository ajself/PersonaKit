// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PersonaKit",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "personakit",
            targets: ["PersonaKit"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/mattt/JSONSchema.git", from: "1.3.0")
    ],
    targets: [
        .executableTarget(
            name: "PersonaKit",
            dependencies: ["JSONSchema"],
            path: "Sources/PersonaKit",
            resources: [
                .process("Schemas")
            ]
        ),
        .testTarget(
            name: "PersonaKitTests",
            dependencies: ["PersonaKit"],
            path: "Tests/PersonaKitTests",
            swiftSettings: [
                .enableExperimentalFeature("Testing")
            ]
        )
    ]
)
