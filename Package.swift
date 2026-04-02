// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "PersonaKit",
  platforms: [
    .macOS(.v26)
  ],
  products: [
    .library(
      name: "ContextCLI",
      targets: ["ContextCLI"]
    ),
    .library(
      name: "StudioFeatures",
      targets: ["StudioFeatures"]
    ),
    .executable(
      name: "personakit",
      targets: ["PersonaKit"]
    ),
    .executable(
      name: "PersonaKitStudio",
      targets: ["PersonaKitStudio"]
    ),
  ],
  dependencies: [
    .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.12.0"),
    .package(
      url: "https://github.com/apple/swift-argument-parser",
      .upToNextMinor(from: "1.7.0")
    ),
    .package(
      url: "https://github.com/pointfreeco/swift-snapshot-testing.git",
      .upToNextMinor(from: "1.17.0")
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
      name: "ContextWorkspaceCore",
      dependencies: [
        "ContextCore"
      ],
      path: "Sources/Shared/ContextWorkspaceCore"
    ),
    .target(
      name: "ContextCLI",
      dependencies: [
        "ContextCore",
        "ContextWorkspaceCore",
        "ContextMCP",
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
        "ContextCore",
        "ContextWorkspaceCore",
      ],
      path: "Sources/Features/Studio/Foundation"
    ),
    .target(
      name: "StudioFeatures",
      dependencies: [
        "ContextCore",
        "ContextWorkspaceCore",
        "StudioFoundation",
      ],
      path: "Sources/Features/Studio",
      exclude: [
        "Foundation"
      ]
    ),
    .executableTarget(
      name: "PersonaKit",
      dependencies: [
        "ContextCLI"
      ],
      path: "Sources/App/CLI"
    ),
    .executableTarget(
      name: "PersonaKitStudio",
      dependencies: [
        "StudioFeatures"
      ],
      path: "Sources/App/Studio",
      exclude: [
        "README.md"
      ]
    ),
    .testTarget(
      name: "PersonaKitTests",
      dependencies: [
        "ContextCLI",
        "ContextMCP",
        "ContextCore",
        "ContextWorkspaceCore",
        "StudioFeatures",
        "PersonaKitStudio",
        .product(name: "MCP", package: "swift-sdk"),
        .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
      ],
      path: "Tests",
      exclude: [
        "Fixtures",
        "Features/Studio/__Snapshots__",
      ],
      swiftSettings: [
        .enableExperimentalFeature("Testing")
      ]
    ),
  ]
)
