// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "PersonaPad",
  platforms: [
    .macOS(.v26)
  ],
  products: [
    .library(name: "PersonaPadCore", targets: ["PersonaPadCore"]),
    .executable(name: "PersonaPadApp", targets: ["PersonaPadApp"]),
    .executable(name: "personapad", targets: ["PersonaPadCLI"]),
    .executable(name: "personapad-validate", targets: ["PersonaPadSchemaValidate"])
  ],
  dependencies: [
    .package(url: "https://github.com/pointfreeco/swift-dependencies.git", from: "1.10.1")
  ],
  targets: [
    .target(
      name: "PersonaPadResources",
      path: "Sources/PersonaPadResources",
      resources: [
        .process("Resources")
      ]
    ),
    .target(
      name: "PersonaPadCore",
      dependencies: [
        .product(name: "Dependencies", package: "swift-dependencies")
      ],
      path: "Sources/PersonaPadCore"
    ),
    .executableTarget(
      name: "PersonaPadApp",
      dependencies: [
        "PersonaPadCore",
        "PersonaPadResources",
        .product(name: "Dependencies", package: "swift-dependencies")
      ],
      path: "Sources/PersonaPadApp"
    ),
    .executableTarget(
      name: "PersonaPadCLI",
      dependencies: ["PersonaPadCore", "PersonaPadResources"],
      path: "Sources/PersonaPadCLI"
    ),
    .executableTarget(
      name: "PersonaPadSchemaValidate",
      dependencies: ["PersonaPadCore"],
      path: "Sources/PersonaPadSchemaValidate"
    ),
    .testTarget(
      name: "PersonaPadCoreTests",
      dependencies: ["PersonaPadCore"],
      path: "Tests/PersonaPadCoreTests"
    ),
    .testTarget(
      name: "PersonaPadAppTests",
      dependencies: ["PersonaPadApp"],
      path: "Tests/PersonaPadAppTests"
    )
  ]
)
