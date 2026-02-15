import Foundation
import Testing

@testable import PersonaKitStudio

struct WorkspaceInitializerTests {
  @Test
  func initializeCreatesPersonaKitDirectoryStructure() throws {
    let workspaceURL = URL(fileURLWithPath: "/Workspace")
    let createDirectorySpy = DirectoryCreationSpy()
    let initializer = WorkspaceInitializer(
      dependencies: WorkspaceInitializerDependencies(
        createDirectory: { directoryURL in
          createDirectorySpy.createdDirectories.append(directoryURL.standardizedFileURL)
        }
      )
    )

    try initializer.initialize(
      at: workspaceURL
    )

    let expectedDirectories: [URL] = [
      workspaceURL.appendingPathComponent(".personakit"),
      workspaceURL.appendingPathComponent(".personakit/Packs"),
      workspaceURL.appendingPathComponent(".personakit/Packs/personas"),
      workspaceURL.appendingPathComponent(".personakit/Packs/directives"),
      workspaceURL.appendingPathComponent(".personakit/Packs/kits"),
      workspaceURL.appendingPathComponent(".personakit/Packs/intents"),
      workspaceURL.appendingPathComponent(".personakit/Packs/skills"),
      workspaceURL.appendingPathComponent(".personakit/Packs/essentials"),
      workspaceURL.appendingPathComponent(".personakit/Sessions"),
    ]
    .map(\.standardizedFileURL)

    #expect(createDirectorySpy.createdDirectories == expectedDirectories)
  }
}

private final class DirectoryCreationSpy {
  var createdDirectories: [URL] = []
}
