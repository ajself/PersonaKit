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
        .package(url: "https://github.com/mattt/JSONSchema.git", from: "1.3.0"),
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.10.0")
    ],
    targets: [
        .executableTarget(
            name: "PersonaKit",
            dependencies: [
                "JSONSchema",
                .product(name: "MCP", package: "swift-sdk")
            ],
            path: "Sources/PersonaKit",
            resources: [
                .process("Schemas")
            ]
        ),
        .testTarget(
            name: "PersonaKitTests",
            dependencies: [
                "PersonaKit",
                .product(name: "MCP", package: "swift-sdk")
            ],
            path: "Tests/PersonaKitTests",
            swiftSettings: [
                .enableExperimentalFeature("Testing")
            ]
        )
    ]
)
