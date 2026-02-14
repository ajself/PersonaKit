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
      name: "PersonaKitCore",
      dependencies: [
        "JSONSchema",
        .product(name: "MCP", package: "swift-sdk"),
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
      ],
      path: "Sources/PersonaKit",
      resources: [
        .process("Schemas")
      ]
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
        .product(name: "MCP", package: "swift-sdk"),
      ],
      path: "Tests/PersonaKitTests",
      swiftSettings: [
        .enableExperimentalFeature("Testing")
      ]
    ),
  ]
)
