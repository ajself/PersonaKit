import Foundation

/// Creates the minimal project PersonaKit directory structure for Studio.
public struct WorkspaceInitializer {
  private let dependencies: WorkspaceInitializerDependencies

  public init(
    dependencies: WorkspaceInitializerDependencies = .live()
  ) {
    self.dependencies = dependencies
  }

  public func initialize(
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
      projectScopeURL.appendingPathComponent("Packs/skills"),
      projectScopeURL.appendingPathComponent("Sessions"),
    ]

    for directoryURL in directoryURLs {
      try dependencies.createDirectory(directoryURL)
    }
  }
}

/// Injectable filesystem dependencies for workspace initialization.
public struct WorkspaceInitializerDependencies {
  let createDirectory: (URL) throws -> Void

  public init(
    createDirectory: @escaping (URL) throws -> Void
  ) {
    self.createDirectory = createDirectory
  }

  public static func live() -> WorkspaceInitializerDependencies {
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
