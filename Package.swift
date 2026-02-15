// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "PersonaKit",
  platforms: [
    .macOS(.v26)
  ],
  products: [
    .executable(
      name: "personakit",
      targets: ["PersonaKit"]
    ),
    .executable(
      name: "PersonaKitStudio",
      targets: ["PersonaKitStudio"]
    ),
    .library(
      name: "PersonaKitCore",
      targets: ["PersonaKitCore"]
    ),
  ],
  dependencies: [
    .package(url: "https://github.com/mattt/JSONSchema.git", from: "1.3.0"),
    .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.10.0"),
    .package(
      url: "https://github.com/apple/swift-argument-parser",
      .upToNextMinor(from: "1.7.0")
    ),
  ],
  targets: [
    .target(
      name: "ContextCore",
      dependencies: [],
      path: "Sources/Shared/ContextCore",
      resources: [
        .process("Schemas")
      ]
    ),
    .target(
      name: "ContextCLI",
      dependencies: [
        "ContextCore",
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
      ],
      path: "Sources/Features/CLI"
    ),
    .target(
      name: "ContextMCP",
      dependencies: [
        "ContextCore",
        .product(name: "MCP", package: "swift-sdk"),
      ],
      path: "Sources/Features/MCP"
    ),
    .target(
      name: "StudioFoundation",
      dependencies: [
        "ContextCore"
      ],
      path: "Sources/Features/Studio/Foundation"
    ),
    .target(
      name: "StudioFeatures",
      dependencies: [
        "StudioFoundation"
      ],
      path: "Sources/Features/Studio/UI"
    ),
    .target(
      name: "PersonaKitCore",
      dependencies: [
        "ContextCore",
        "JSONSchema",
        .product(name: "MCP", package: "swift-sdk"),
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
      ],
      path: "Sources/PersonaKit"
    ),
    .executableTarget(
      name: "PersonaKit",
      dependencies: [
        "PersonaKitCore"
      ],
      path: "Sources/PersonaKitApp"
    ),
    .executableTarget(
      name: "PersonaKitStudio",
      dependencies: [
        "PersonaKitCore"
      ],
      path: "Apps/PersonaKitStudio"
    ),
    .testTarget(
      name: "PersonaKitTests",
      dependencies: [
        "PersonaKitCore",
        "PersonaKitStudio",
        .product(name: "MCP", package: "swift-sdk"),
      ],
      path: "Tests/PersonaKitTests",
      swiftSettings: [
        .enableExperimentalFeature("Testing")
      ]
    ),
  ]
)
