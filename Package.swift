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
    .executable(name: "AppOpsCLI", targets: ["AppOpsCLI"])
  ],
  dependencies: [
    .package(url: "https://github.com/pointfreeco/swift-dependencies.git", from: "1.10.1"),
    .package(url: "https://github.com/apple/swift-log.git", from: "1.5.0")
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
      name: "AppOpsCore",
      path: "Sources/AppOpsCore",
      exclude: ["README.md"]
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
      name: "AppOpsCLI",
      dependencies: [
        "AppOpsCore",
        "PersonaKitCore",
        "PersonaKitResources",
        .product(name: "Logging", package: "swift-log")
      ],
      path: "Sources/AppOpsCLI",
      exclude: ["README.md"]
    ),
    .testTarget(
      name: "PersonaKitCoreTests",
      dependencies: ["PersonaKitCore"],
      path: "Tests/PersonaKitCoreTests"
    ),
    .testTarget(
      name: "AppOpsCoreTests",
      dependencies: ["AppOpsCore"],
      path: "Tests/AppOpsCoreTests"
    ),
    .testTarget(
      name: "AppOpsCLITests",
      dependencies: [
        "AppOpsCLI",
        "AppOpsCore",
        "PersonaKitCore"
      ],
      path: "Tests/AppOpsCLITests"
    ),
    .testTarget(
      name: "PersonaKitAppTests",
      dependencies: ["PersonaKitApp"],
      path: "Tests/PersonaKitAppTests"
    )
  ]
)
