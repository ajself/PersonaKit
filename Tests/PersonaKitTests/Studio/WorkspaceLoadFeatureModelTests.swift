import Foundation
import PersonaKitCore
import StudioFoundation
import Testing

@testable import StudioFeatures

@MainActor
struct WorkspaceLoadFeatureModelTests {
  @Test
  func loadWorkspacePublishesSnapshotForCurrentWorkspace() async {
    let workspaceURL = URL(fileURLWithPath: "/Workspace")
    let expectedSnapshot = WorkspaceSnapshot(
      sessions: [],
      personas: [
        WorkspaceListItem(
          id: "persona-a",
          displayName: "Persona A",
          fileURL: URL(fileURLWithPath: "/persona-a.persona.json"),
          sourceScope: .project
        )
      ],
      directives: [],
      kits: [],
      skills: [],
      intents: [],
      essentials: []
    )
    let model = WorkspaceLoadFeatureModel(
      operationRunner: makeOperationRunner(
        snapshotBuilder: StubSnapshotBuilder { _ in
          expectedSnapshot
        }
      )
    )
    var loadedSnapshot: WorkspaceSnapshot?
    var failureMessage: String?
    var missingPersonaKitErrorMessage: String?

    model.loadWorkspace(
      workspaceURL: workspaceURL,
      currentWorkspaceURL: { workspaceURL },
      onLoaded: { snapshot in
        loadedSnapshot = snapshot
      },
      onMissingPersonaKitDirectory: { error in
        missingPersonaKitErrorMessage = error.localizedDescription
      },
      onLoadFailure: { message in
        failureMessage = message
      }
    )

    await waitFor {
      loadedSnapshot?.personas.first?.id == "persona-a"
    }

    #expect(failureMessage == nil)
    #expect(missingPersonaKitErrorMessage == nil)
  }

  @Test
  func loadWorkspaceIgnoresStaleResultAfterWorkspaceChange() async {
    let firstWorkspaceURL = URL(fileURLWithPath: "/WorkspaceA")
    let secondWorkspaceURL = URL(fileURLWithPath: "/WorkspaceB")
    let model = WorkspaceLoadFeatureModel(
      operationRunner: makeOperationRunner(
        snapshotBuilder: StubSnapshotBuilder { workspaceURL in
          if workspaceURL.standardizedFileURL == firstWorkspaceURL.standardizedFileURL {
            Thread.sleep(forTimeInterval: 0.3)
          }

          return WorkspaceSnapshot.empty
        }
      )
    )
    var activeWorkspaceURL: URL? = firstWorkspaceURL
    var didLoadSnapshot = false
    var didReportFailure = false
    var didReportMissingPersonaKit = false

    model.loadWorkspace(
      workspaceURL: firstWorkspaceURL,
      currentWorkspaceURL: { activeWorkspaceURL },
      onLoaded: { _ in
        didLoadSnapshot = true
      },
      onMissingPersonaKitDirectory: { _ in
        didReportMissingPersonaKit = true
      },
      onLoadFailure: { _ in
        didReportFailure = true
      }
    )

    try? await Task.sleep(for: .milliseconds(20))
    activeWorkspaceURL = secondWorkspaceURL
    try? await Task.sleep(for: .milliseconds(350))

    #expect(!didLoadSnapshot)
    #expect(!didReportFailure)
    #expect(!didReportMissingPersonaKit)
  }

  @Test
  func loadWorkspaceMapsMissingPersonaKitDirectoryError() async {
    let workspaceURL = URL(fileURLWithPath: "/Workspace")
    let model = WorkspaceLoadFeatureModel(
      operationRunner: makeOperationRunner(
        snapshotBuilder: StubSnapshotBuilder { _ in
          throw MissingPersonaKitDirectoryError(
            projectScopeURL: URL(fileURLWithPath: "/Workspace/.personakit")
          )
        }
      )
    )
    var loadedSnapshot: WorkspaceSnapshot?
    var failureMessage: String?
    var missingPersonaKitErrorMessage: String?

    model.loadWorkspace(
      workspaceURL: workspaceURL,
      currentWorkspaceURL: { workspaceURL },
      onLoaded: { snapshot in
        loadedSnapshot = snapshot
      },
      onMissingPersonaKitDirectory: { error in
        missingPersonaKitErrorMessage = error.localizedDescription
      },
      onLoadFailure: { message in
        failureMessage = message
      }
    )

    await waitFor {
      missingPersonaKitErrorMessage?.hasPrefix("Missing PersonaKit directory at ") == true
    }

    #expect(loadedSnapshot == nil)
    #expect(failureMessage == nil)
  }

  @Test
  func loadWorkspaceMapsSnapshotBuildErrorMessage() async {
    let workspaceURL = URL(fileURLWithPath: "/Workspace")
    let model = WorkspaceLoadFeatureModel(
      operationRunner: makeOperationRunner(
        snapshotBuilder: StubSnapshotBuilder { _ in
          throw WorkspaceSnapshotBuildError(message: "snapshot failed")
        }
      )
    )
    var loadedSnapshot: WorkspaceSnapshot?
    var failureMessage: String?
    var missingPersonaKitErrorMessage: String?

    model.loadWorkspace(
      workspaceURL: workspaceURL,
      currentWorkspaceURL: { workspaceURL },
      onLoaded: { snapshot in
        loadedSnapshot = snapshot
      },
      onMissingPersonaKitDirectory: { error in
        missingPersonaKitErrorMessage = error.localizedDescription
      },
      onLoadFailure: { message in
        failureMessage = message
      }
    )

    await waitFor {
      failureMessage == "snapshot failed"
    }

    #expect(loadedSnapshot == nil)
    #expect(missingPersonaKitErrorMessage == nil)
  }

  private func waitFor(
    timeout: Duration = .seconds(2),
    condition: @escaping () -> Bool
  ) async {
    let clock = ContinuousClock()
    let deadline = clock.now + timeout

    while clock.now < deadline {
      if condition() {
        return
      }

      try? await Task.sleep(for: .milliseconds(10))
    }

    #expect(condition())
  }
}

private struct StubSnapshotBuilder: WorkspaceSnapshotBuilding, Sendable {
  let buildHandler: @Sendable (URL) throws -> WorkspaceSnapshot

  func build(workspaceURL: URL) throws -> WorkspaceSnapshot {
    try buildHandler(workspaceURL)
  }
}

private struct NoOpWorkspaceValidator: WorkspaceValidating, Sendable {
  func validate(workspaceURL: URL) throws -> WorkspaceValidationSnapshot {
    WorkspaceValidationSnapshot(summary: "ok", issues: [])
  }
}

private struct NoOpSessionManager: WorkspaceSessionManaging, Sendable {
  func loadDraft(fileURL: URL) throws -> WorkspaceSessionDraft {
    WorkspaceSessionDraft(
      id: "",
      personaId: "",
      directiveId: "",
      kitOverrides: []
    )
  }

  func saveSession(
    workspaceURL: URL,
    draft: WorkspaceSessionDraft,
    originalSessionID: String?,
    validPersonaIDs: Set<String>,
    validDirectiveIDs: Set<String>,
    validKitIDs: Set<String>
  ) throws -> String {
    "session"
  }

  func deleteSession(
    workspaceURL: URL,
    sessionID: String
  ) throws {}
}

private struct NoOpEssentialManager: WorkspaceEssentialManaging, Sendable {
  func loadMarkdown(fileURL: URL) throws -> String {
    ""
  }

  func saveMarkdown(
    workspaceURL: URL,
    itemID: String,
    markdown: String
  ) throws {}

  func copyGlobalEssentialToProject(
    workspaceURL: URL,
    item: WorkspaceListItem
  ) throws {}
}

private struct NoOpLibraryEntityManager: WorkspaceLibraryEntityManaging, Sendable {
  func loadRawJSON(fileURL: URL) throws -> String {
    "{}"
  }

  func validateRawJSON(
    _ rawJSON: String,
    entityType: WorkspaceLibraryEntityType,
    expectedID: String
  ) throws {}

  func saveRawJSON(
    workspaceURL: URL,
    itemID: String,
    rawJSON: String,
    entityType: WorkspaceLibraryEntityType
  ) throws {}

  func copyGlobalItemToProject(
    workspaceURL: URL,
    item: WorkspaceListItem,
    entityType: WorkspaceLibraryEntityType
  ) throws {}
}

private struct NoOpSessionPreviewManager: WorkspaceSessionPreviewManaging, Sendable {
  func loadPreview(
    workspaceURL: URL,
    session: WorkspaceSessionListItem
  ) throws -> String {
    ""
  }

  func exportPreview(
    _ preview: String,
    to destinationURL: URL
  ) throws {}
}

private func makeOperationRunner(
  snapshotBuilder: StubSnapshotBuilder
) -> WorkspaceOperationRunner {
  WorkspaceOperationRunner(
    snapshotBuilder: snapshotBuilder,
    workspaceValidator: NoOpWorkspaceValidator(),
    sessionManager: NoOpSessionManager(),
    essentialManager: NoOpEssentialManager(),
    libraryEntityManager: NoOpLibraryEntityManager(),
    sessionPreviewManager: NoOpSessionPreviewManager()
  )
}
