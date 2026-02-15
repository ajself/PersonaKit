import Foundation

/// Creates the minimal project PersonaKit directory structure for Studio.
struct WorkspaceInitializer {
  private let dependencies: WorkspaceInitializerDependencies

  init(
    dependencies: WorkspaceInitializerDependencies = .live()
  ) {
    self.dependencies = dependencies
  }

  func initialize(
    at workspaceURL: URL
  ) throws {
    let workspace = workspaceURL.standardizedFileURL
    let projectScopeURL: URL

    if workspace.lastPathComponent == ".personakit" {
      projectScopeURL = workspace
    } else {
      projectScopeURL = workspace.appendingPathComponent(".personakit")
    }

    let directoryURLs: [URL] = [
      projectScopeURL,
      projectScopeURL.appendingPathComponent("Packs"),
      projectScopeURL.appendingPathComponent("Packs/personas"),
      projectScopeURL.appendingPathComponent("Packs/directives"),
      projectScopeURL.appendingPathComponent("Packs/kits"),
      projectScopeURL.appendingPathComponent("Packs/intents"),
      projectScopeURL.appendingPathComponent("Packs/skills"),
      projectScopeURL.appendingPathComponent("Packs/essentials"),
      projectScopeURL.appendingPathComponent("Sessions"),
    ]

    for directoryURL in directoryURLs {
      try dependencies.createDirectory(directoryURL)
    }
  }
}

/// Injectable filesystem dependencies for workspace initialization.
struct WorkspaceInitializerDependencies {
  let createDirectory: (URL) throws -> Void

  static func live() -> WorkspaceInitializerDependencies {
    WorkspaceInitializerDependencies(
      createDirectory: { directoryURL in
        try FileManager.default.createDirectory(
          at: directoryURL,
          withIntermediateDirectories: true
        )
      }
    )
  }
}
