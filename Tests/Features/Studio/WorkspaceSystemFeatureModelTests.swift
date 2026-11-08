import ContextCore
import ContextWorkspaceCore
import Foundation
import StudioFoundation
import Testing

@testable import StudioFeatures

@MainActor
struct WorkspaceSystemFeatureModelTests {
  @Test
  func pickWorkspaceURLReturnsStandardizedSelection() {
    let rawURL = URL(fileURLWithPath: "/tmp/../tmp/PersonaKitWorkspace")
    let model = WorkspaceSystemFeatureModel(
      workspacePicker: StubWorkspacePicker(selectedURL: rawURL),
      workspaceInitializer: WorkspaceInitializer(
        dependencies: WorkspaceInitializerDependencies(
          createDirectory: { _ in }
        )
      ),
      fileRevealer: SpyFileRevealer()
    )

    let pickedURL = model.pickWorkspaceURL()

    #expect(pickedURL == rawURL.standardizedFileURL)
  }

  @Test
  func initializeWorkspaceStructureReturnsFalseWhenWorkspaceIsNil() throws {
    let state = WorkspaceInitializationState()
    let model = WorkspaceSystemFeatureModel(
      workspacePicker: StubWorkspacePicker(selectedURL: nil),
      workspaceInitializer: WorkspaceInitializer(
        dependencies: WorkspaceInitializerDependencies(
          createDirectory: { directoryURL in
            state.createdDirectories.append(directoryURL.standardizedFileURL)
          }
        )
      ),
      fileRevealer: SpyFileRevealer()
    )

    let didInitialize = try model.initializeWorkspaceStructure(at: nil)

    #expect(!didInitialize)
    #expect(state.createdDirectories.isEmpty)
  }

  @Test
  func initializeWorkspaceStructureCreatesExpectedDirectoryLayout() throws {
    let workspaceURL = URL(fileURLWithPath: "/Workspace")
    let state = WorkspaceInitializationState()
    let model = WorkspaceSystemFeatureModel(
      workspacePicker: StubWorkspacePicker(selectedURL: workspaceURL),
      workspaceInitializer: WorkspaceInitializer(
        dependencies: WorkspaceInitializerDependencies(
          createDirectory: { directoryURL in
            state.createdDirectories.append(directoryURL.standardizedFileURL)
          }
        )
      ),
      fileRevealer: SpyFileRevealer()
    )

    let didInitialize = try model.initializeWorkspaceStructure(at: workspaceURL)

    #expect(didInitialize)
    #expect(
      state.createdDirectories == [
        workspaceURL.appendingPathComponent(".personakit").standardizedFileURL,
        workspaceURL.appendingPathComponent(".personakit/Packs").standardizedFileURL,
        workspaceURL.appendingPathComponent(".personakit/Packs/personas").standardizedFileURL,
        workspaceURL.appendingPathComponent(".personakit/Packs/directives").standardizedFileURL,
        workspaceURL.appendingPathComponent(".personakit/Packs/kits").standardizedFileURL,
        workspaceURL.appendingPathComponent(".personakit/Packs/skills").standardizedFileURL,
        workspaceURL.appendingPathComponent(".personakit/Sessions").standardizedFileURL,
      ]
    )
  }

  @Test
  func initializeWorkspaceStructureStandardizesWorkspaceURL() throws {
    let workspaceURL = URL(fileURLWithPath: "/Workspace/../Workspace")
    let state = WorkspaceInitializationState()
    let model = WorkspaceSystemFeatureModel(
      workspacePicker: StubWorkspacePicker(selectedURL: workspaceURL),
      workspaceInitializer: WorkspaceInitializer(
        dependencies: WorkspaceInitializerDependencies(
          createDirectory: { directoryURL in
            state.createdDirectories.append(directoryURL.standardizedFileURL)
          }
        )
      ),
      fileRevealer: SpyFileRevealer()
    )

    let didInitialize = try model.initializeWorkspaceStructure(at: workspaceURL)

    #expect(didInitialize)
    #expect(state.createdDirectories.first?.path() == "/Workspace/.personakit")
  }

  @Test
  func revealInFinderForwardsStandardizedURLToRevealer() {
    let revealer = SpyFileRevealer()
    let model = WorkspaceSystemFeatureModel(
      workspacePicker: StubWorkspacePicker(selectedURL: nil),
      workspaceInitializer: WorkspaceInitializer(
        dependencies: WorkspaceInitializerDependencies(
          createDirectory: { _ in }
        )
      ),
      fileRevealer: revealer
    )
    let rawURL = URL(fileURLWithPath: "/tmp/personakit-tests/../file.json")
    let expectedURL = URL(fileURLWithPath: "/tmp/file.json").standardizedFileURL

    model.revealInFinder(fileURL: rawURL)

    #expect(revealer.revealedURLs == [expectedURL])
  }

  @Test
  func revealValidationIssueInFinderUsesSnapshotPathResolution() {
    let revealer = SpyFileRevealer()
    let workspaceURL = URL(fileURLWithPath: "/Workspace")
    let fileURL = URL(fileURLWithPath: "/Workspace/.personakit/Packs/personas/persona-a.persona.json")
    let snapshot = WorkspaceSnapshot(
      sessions: [],
      personas: [
        WorkspaceListItem(
          id: "persona-a",
          displayName: "Persona A",
          fileURL: fileURL,
          sourceScope: .project
        )
      ],
      directives: [],
      kits: [],
      skills: []
    )
    let model = WorkspaceSystemFeatureModel(
      workspacePicker: StubWorkspacePicker(selectedURL: workspaceURL),
      workspaceInitializer: WorkspaceInitializer(
        dependencies: WorkspaceInitializerDependencies(
          createDirectory: { _ in }
        )
      ),
      fileRevealer: revealer
    )

    model.revealValidationIssueInFinder(
      filePath: "Packs/personas/persona-a.persona.json",
      workspaceURL: workspaceURL,
      snapshot: snapshot
    )

    #expect(revealer.revealedURLs == [fileURL.standardizedFileURL])
  }

  @Test
  func revealValidationIssueInFinderMatchesAFileNameWithASpace() {
    let revealer = SpyFileRevealer()
    let workspaceURL = URL(fileURLWithPath: "/My Workspace")
    let fileURL = URL(
      fileURLWithPath: "/My Workspace/.personakit/Packs/personas/persona a.persona.json"
    )
    let snapshot = WorkspaceSnapshot(
      sessions: [],
      personas: [
        WorkspaceListItem(
          id: "persona-a",
          displayName: "Persona A",
          fileURL: fileURL,
          sourceScope: .project
        )
      ],
      directives: [],
      kits: [],
      skills: []
    )
    let model = WorkspaceSystemFeatureModel(
      workspacePicker: StubWorkspacePicker(selectedURL: workspaceURL),
      workspaceInitializer: WorkspaceInitializer(
        dependencies: WorkspaceInitializerDependencies(
          createDirectory: { _ in }
        )
      ),
      fileRevealer: revealer
    )

    model.revealValidationIssueInFinder(
      filePath: "Packs/personas/persona a.persona.json",
      workspaceURL: workspaceURL,
      snapshot: snapshot
    )

    #expect(revealer.revealedURLs == [fileURL.standardizedFileURL])
  }

  @Test
  func revealValidationIssueInFinderFindsAFileOnDiskUnderAPathWithASpace() throws {
    let workspaceURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("PersonaKit Reveal \(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: workspaceURL) }
    let fileURL = workspaceURL.appendingPathComponent(".personakit/Packs/personas/persona a.persona.json")
    try FileManager.default.createDirectory(
      at: fileURL.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try Data("{}".utf8).write(to: fileURL)
    let revealer = SpyFileRevealer()
    let model = WorkspaceSystemFeatureModel(
      workspacePicker: StubWorkspacePicker(selectedURL: workspaceURL),
      workspaceInitializer: WorkspaceInitializer(
        dependencies: WorkspaceInitializerDependencies(
          createDirectory: { _ in }
        )
      ),
      fileRevealer: revealer
    )

    model.revealValidationIssueInFinder(
      filePath: "Packs/personas/persona a.persona.json",
      workspaceURL: workspaceURL,
      snapshot: .empty
    )

    #expect(revealer.revealedURLs == [fileURL.standardizedFileURL])
  }
}

private final class WorkspaceInitializationState {
  var createdDirectories: [URL] = []
}

private struct StubWorkspacePicker: WorkspacePicking {
  let selectedURL: URL?

  @MainActor
  func pickWorkspaceURL() -> URL? {
    selectedURL
  }
}

private final class SpyFileRevealer: FileRevealing {
  private(set) var revealedURLs: [URL] = []

  @MainActor
  func reveal(_ url: URL) {
    revealedURLs.append(url.standardizedFileURL)
  }
}
