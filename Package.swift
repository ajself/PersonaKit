// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "PersonaKit",
  platforms: [
    .macOS(.v26)
  ],
  products: [
    .library(name: "PersonaKitCore", targets: ["PersonaKitCore"]),
    .executable(name: "PersonaKitApp", targets: ["PersonaKitApp"]),
    .executable(name: "personakit", targets: ["PersonaKitCLI"]),
    .executable(name: "personakit-validate", targets: ["PersonaKitSchemaValidate"])
  ],
  dependencies: [
    .package(url: "https://github.com/pointfreeco/swift-dependencies.git", from: "1.10.1")
  ],
  targets: [
    .target(
      name: "PersonaKitResources",
      path: "Sources/PersonaKitResources",
      resources: [
        .process("Resources")
      ]
    ),
    .target(
      name: "PersonaKitCore",
      dependencies: [
        .product(name: "Dependencies", package: "swift-dependencies")
      ],
      path: "Sources/PersonaKitCore"
    ),
    .executableTarget(
      name: "PersonaKitApp",
      dependencies: [
        "PersonaKitCore",
        "PersonaKitResources",
        .product(name: "Dependencies", package: "swift-dependencies")
      ],
      path: "Sources/PersonaKitApp",
      exclude: [
        "App/ArchitectureDefaults.md"
      ]
    ),
    .executableTarget(
      name: "PersonaKitCLI",
      dependencies: [
        "PersonaKitCore",
        "PersonaKitResources",
        .product(name: "Dependencies", package: "swift-dependencies")
      ],
      path: "Sources/PersonaKitCLI"
    ),
    .executableTarget(
      name: "PersonaKitSchemaValidate",
      dependencies: [
        "PersonaKitCore",
        .product(name: "Dependencies", package: "swift-dependencies")
      ],
      path: "Sources/PersonaKitSchemaValidate"
    ),
    .testTarget(
      name: "PersonaKitCoreTests",
      dependencies: ["PersonaKitCore"],
      path: "Tests/PersonaKitCoreTests"
    ),
    .testTarget(
      name: "PersonaKitAppTests",
      dependencies: ["PersonaKitApp"],
      path: "Tests/PersonaKitAppTests"
    )
  ]
)
