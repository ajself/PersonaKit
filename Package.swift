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
    .executable(name: "personakit-validate", targets: ["PersonaKitSchemaValidate"]),
    .executable(name: "BuildCompareCLI", targets: ["BuildCompareCLI"])
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
    .target(
      name: "BuildCompareCore",
      path: "Sources/BuildCompareCore"
    ),
    .executableTarget(
      name: "PersonaKitApp",
      dependencies: [
        "PersonaKitCore",
        "PersonaKitResources",
        .product(name: "Dependencies", package: "swift-dependencies")
      ],
      path: "Sources/PersonaKitApp"
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
    .executableTarget(
      name: "BuildCompareCLI",
      dependencies: ["BuildCompareCore"],
      path: "Sources/BuildCompareCLI"
    ),
    .testTarget(
      name: "PersonaKitCoreTests",
      dependencies: ["PersonaKitCore"],
      path: "Tests/PersonaKitCoreTests"
    ),
    .testTarget(
      name: "BuildCompareCoreTests",
      dependencies: ["BuildCompareCore"],
      path: "Tests/BuildCompareCoreTests"
    ),
    .testTarget(
      name: "PersonaKitAppTests",
      dependencies: ["PersonaKitApp"],
      path: "Tests/PersonaKitAppTests"
    )
  ]
)
