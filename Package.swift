// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "PersonaPad",
  platforms: [
    .macOS(.v13)
  ],
  products: [
    .library(name: "PersonaPadCore", targets: ["PersonaPadCore"]),
    .executable(name: "PersonaPadApp", targets: ["PersonaPadApp"]),
    .executable(name: "personapad", targets: ["PersonaPadCLI"]),
    .executable(name: "personapad-validate", targets: ["PersonaPadSchemaValidate"])
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
      path: "Sources/PersonaPadCore"
    ),
    .executableTarget(
      name: "PersonaPadApp",
      dependencies: ["PersonaPadCore", "PersonaPadResources"],
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
    )
  ]
)
