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
  func loadWorkspacePublishesSnapshotForEquivalentStandardizedWorkspaceURL() async {
    let requestedWorkspaceURL = URL(fileURLWithPath: "/Workspace/../Workspace")
    let currentWorkspaceURL = URL(fileURLWithPath: "/Workspace")
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

    model.loadWorkspace(
      workspaceURL: requestedWorkspaceURL,
      currentWorkspaceURL: { currentWorkspaceURL },
      onLoaded: { snapshot in
        loadedSnapshot = snapshot
      },
      onMissingPersonaKitDirectory: { _ in },
      onLoadFailure: { _ in }
    )

    await waitFor {
      loadedSnapshot?.personas.first?.id == "persona-a"
    }
  }

  @Test
  func loadWorkspaceForwardsStandardizedWorkspaceURL() async {
    let requestedWorkspaceURL = URL(fileURLWithPath: "/Workspace/../Workspace")
    let currentWorkspaceURL = URL(fileURLWithPath: "/Workspace")

    let model = WorkspaceLoadFeatureModel(
      operationRunner: makeOperationRunner(
        snapshotBuilder: StubSnapshotBuilder { workspaceURL in
          #expect(workspaceURL.path() == "/Workspace")
          return WorkspaceSnapshot.empty
        }
      )
    )
    var didLoadSnapshot = false

    model.loadWorkspace(
      workspaceURL: requestedWorkspaceURL,
      currentWorkspaceURL: { currentWorkspaceURL },
      onLoaded: { _ in
        didLoadSnapshot = true
      },
      onMissingPersonaKitDirectory: { _ in },
      onLoadFailure: { _ in }
    )

    await waitFor {
      didLoadSnapshot
    }
  }

  @Test
  func loadWorkspaceIgnoresStaleResultAfterWorkspaceChange() async {
    let firstWorkspaceURL = URL(fileURLWithPath: "/WorkspaceA")
    let secondWorkspaceURL = URL(fileURLWithPath: "/WorkspaceB")
    let gate = StaleLoadGate()
    let model = WorkspaceLoadFeatureModel(
      operationRunner: makeOperationRunner(
        snapshotBuilder: StubSnapshotBuilder { workspaceURL in
          if workspaceURL.standardizedFileURL == firstWorkspaceURL.standardizedFileURL {
            gate.markLoadStarted()
            let timeout = Date().addingTimeInterval(1)

            while !gate.isLoadAllowedToFinish, Date() < timeout {
              Thread.sleep(forTimeInterval: 0.001)
            }

            gate.markLoadFinished()
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
        gate.markCallbackInvoked()
      },
      onMissingPersonaKitDirectory: { _ in
        didReportMissingPersonaKit = true
        gate.markCallbackInvoked()
      },
      onLoadFailure: { _ in
        didReportFailure = true
        gate.markCallbackInvoked()
      }
    )

    await waitFor {
      gate.isLoadStarted
    }

    activeWorkspaceURL = secondWorkspaceURL
    gate.allowLoadToFinish()

    await waitFor {
      gate.isLoadFinished
    }

    try? await Task.sleep(for: .milliseconds(250))

    #expect(!gate.isCallbackInvoked)
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

private final class StaleLoadGate: @unchecked Sendable {
  private let lock = NSLock()
  private var loadStarted = false
  private var loadAllowedToFinish = false
  private var loadFinished = false
  private var callbackInvoked = false

  var isLoadStarted: Bool {
    lock.lock()
    defer { lock.unlock() }
    return loadStarted
  }

  var isLoadAllowedToFinish: Bool {
    lock.lock()
    defer { lock.unlock() }
    return loadAllowedToFinish
  }

  var isLoadFinished: Bool {
    lock.lock()
    defer { lock.unlock() }
    return loadFinished
  }

  var isCallbackInvoked: Bool {
    lock.lock()
    defer { lock.unlock() }
    return callbackInvoked
  }

  func markLoadStarted() {
    lock.lock()
    defer { lock.unlock() }
    loadStarted = true
  }

  func allowLoadToFinish() {
    lock.lock()
    defer { lock.unlock() }
    loadAllowedToFinish = true
  }

  func markLoadFinished() {
    lock.lock()
    defer { lock.unlock() }
    loadFinished = true
  }

  func markCallbackInvoked() {
    lock.lock()
    defer { lock.unlock() }
    callbackInvoked = true
  }
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
