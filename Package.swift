// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PersonaKit",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "personakit",
            targets: ["PersonaKit"]
        )
    ],
    targets: [
        .executableTarget(
            name: "PersonaKit",
            path: "Sources/PersonaKit"
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
