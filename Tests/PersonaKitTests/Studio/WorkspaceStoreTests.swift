import Foundation
import PersonaKitCore
import Testing

@testable import PersonaKitStudio

@MainActor
struct WorkspaceStoreTests {
  @Test
  func loadPublishesSnapshotBeforeValidationCompletes() async {
    let workspaceURL = URL(fileURLWithPath: "/Workspace")
    let expectedSnapshot = makeSnapshot(id: "project-persona")
    let expectedValidation = makeValidation(entityID: "project-persona")

    let store = WorkspaceStore(
      snapshotBuilder: StubSnapshotBuilder { _ in
        expectedSnapshot
      },
      workspaceValidator: StubWorkspaceValidator { _ in
        Thread.sleep(forTimeInterval: 0.3)

        return expectedValidation
      }
    )

    store.workspaceURL = workspaceURL
    store.loadWorkspace()

    await waitFor {
      store.snapshot.personas.first?.id == "project-persona"
    }

    #expect(store.validation.summary == "Validating workspace...")
    #expect(store.validation.issues.isEmpty)

    await waitFor {
      store.validation.issues.first?.entityId == "project-persona"
    }
  }

  @Test
  func newerLoadResultWinsWhenLoadsOverlap() async {
    let firstWorkspaceURL = URL(fileURLWithPath: "/WorkspaceA")
    let secondWorkspaceURL = URL(fileURLWithPath: "/WorkspaceB")

    let store = WorkspaceStore(
      snapshotBuilder: StubSnapshotBuilder { workspaceURL in
        if workspaceURL.standardizedFileURL == firstWorkspaceURL.standardizedFileURL {
          Thread.sleep(forTimeInterval: 0.3)
          return makeSnapshot(id: "persona-a")
        }

        return makeSnapshot(id: "persona-b")
      },
      workspaceValidator: StubWorkspaceValidator { _ in
        WorkspaceValidationSnapshot(
          summary: "Validation summary: personas=0 kits=0 directives=0 intents=0 skills=0 essentials=0 errors=0",
          issues: []
        )
      }
    )

    store.workspaceURL = firstWorkspaceURL
    store.loadWorkspace()

    try? await Task.sleep(for: .milliseconds(20))

    store.workspaceURL = secondWorkspaceURL
    store.loadWorkspace()

    await waitFor {
      store.snapshot.personas.first?.id == "persona-b"
    }

    try? await Task.sleep(for: .milliseconds(350))

    #expect(store.snapshot.personas.first?.id == "persona-b")
  }

  @Test
  func newerValidationResultWinsWhenValidationsOverlap() async {
    let firstWorkspaceURL = URL(fileURLWithPath: "/WorkspaceA")
    let secondWorkspaceURL = URL(fileURLWithPath: "/WorkspaceB")

    let store = WorkspaceStore(
      snapshotBuilder: StubSnapshotBuilder { _ in
        WorkspaceSnapshot.empty
      },
      workspaceValidator: StubWorkspaceValidator { workspaceURL in
        if workspaceURL.standardizedFileURL == firstWorkspaceURL.standardizedFileURL {
          Thread.sleep(forTimeInterval: 0.3)
          return makeValidation(entityID: "persona-a")
        }

        return makeValidation(entityID: "persona-b")
      }
    )

    store.workspaceURL = firstWorkspaceURL
    store.validateWorkspace()

    try? await Task.sleep(for: .milliseconds(20))

    store.workspaceURL = secondWorkspaceURL
    store.validateWorkspace()

    await waitFor {
      store.validation.issues.first?.entityId == "persona-b"
    }

    try? await Task.sleep(for: .milliseconds(350))

    #expect(store.validation.issues.first?.entityId == "persona-b")
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

  @Test
  func defaultSessionDraftUsesFirstPersonaAndDirective() async {
    let workspaceURL = URL(fileURLWithPath: "/Workspace")

    let store = WorkspaceStore(
      snapshotBuilder: StubSnapshotBuilder { _ in
        WorkspaceSnapshot(
          sessions: [],
          personas: [
            WorkspaceListItem(
              id: "persona-a",
              displayName: "Persona A",
              fileURL: URL(fileURLWithPath: "/persona-a.persona.json"),
              sourceScope: .project
            ),
            WorkspaceListItem(
              id: "persona-b",
              displayName: "Persona B",
              fileURL: URL(fileURLWithPath: "/persona-b.persona.json"),
              sourceScope: .project
            ),
          ],
          directives: [
            WorkspaceListItem(
              id: "directive-a",
              displayName: "Directive A",
              fileURL: URL(fileURLWithPath: "/directive-a.directive.json"),
              sourceScope: .project
            ),
            WorkspaceListItem(
              id: "directive-b",
              displayName: "Directive B",
              fileURL: URL(fileURLWithPath: "/directive-b.directive.json"),
              sourceScope: .project
            ),
          ],
          kits: [],
          skills: [],
          intents: [],
          essentials: []
        )
      },
      workspaceValidator: StubWorkspaceValidator { _ in
        WorkspaceValidationSnapshot(summary: "ok", issues: [])
      }
    )

    store.workspaceURL = workspaceURL
    store.loadWorkspace()

    await waitFor {
      store.snapshot.personas.count == 2
    }

    let draft = store.defaultSessionDraft()

    #expect(draft.id.isEmpty)
    #expect(draft.personaId == "persona-a")
    #expect(draft.directiveId == "directive-a")
    #expect(draft.kitOverrides.isEmpty)
  }

  @Test
  func saveSessionForwardsValidatedIDsToSessionManager() async throws {
    let workspaceURL = URL(fileURLWithPath: "/Workspace")
    let expectedDraft = WorkspaceSessionDraft(
      id: "session-a",
      personaId: "persona-a",
      directiveId: "directive-a",
      kitOverrides: ["kit-b", "kit-a"]
    )

    let store = WorkspaceStore(
      snapshotBuilder: StubSnapshotBuilder { _ in
        WorkspaceSnapshot(
          sessions: [],
          personas: [
            WorkspaceListItem(
              id: "persona-a",
              displayName: "Persona A",
              fileURL: URL(fileURLWithPath: "/persona-a.persona.json"),
              sourceScope: .project
            )
          ],
          directives: [
            WorkspaceListItem(
              id: "directive-a",
              displayName: "Directive A",
              fileURL: URL(fileURLWithPath: "/directive-a.directive.json"),
              sourceScope: .project
            )
          ],
          kits: [],
          skills: [],
          intents: [],
          essentials: []
        )
      },
      workspaceValidator: StubWorkspaceValidator { _ in
        WorkspaceValidationSnapshot(summary: "ok", issues: [])
      },
      sessionManager: StubSessionManager(
        loadDraftHandler: { _ in
          WorkspaceSessionDraft(
            id: "",
            personaId: "",
            directiveId: "",
            kitOverrides: []
          )
        },
        saveSessionHandler: { workspaceURL, draft, originalSessionID, validPersonaIDs, validDirectiveIDs in
          #expect(workspaceURL.path() == "/Workspace")
          #expect(draft == expectedDraft)
          #expect(originalSessionID == "session-old")
          #expect(validPersonaIDs == Set(["persona-a"]))
          #expect(validDirectiveIDs == Set(["directive-a"]))

          return "session-a"
        },
        deleteSessionHandler: { _, _ in }
      )
    )

    store.workspaceURL = workspaceURL
    store.loadWorkspace()

    await waitFor {
      store.snapshot.personas.count == 1
    }

    let savedSessionID = try await store.saveSession(
      draft: expectedDraft,
      originalSessionID: "session-old"
    )

    #expect(savedSessionID == "session-a")
  }

  @Test
  func deleteSessionForwardsToSessionManager() async throws {
    let workspaceURL = URL(fileURLWithPath: "/Workspace")

    let store = WorkspaceStore(
      snapshotBuilder: StubSnapshotBuilder { _ in
        WorkspaceSnapshot.empty
      },
      workspaceValidator: StubWorkspaceValidator { _ in
        WorkspaceValidationSnapshot(summary: "ok", issues: [])
      },
      sessionManager: StubSessionManager(
        loadDraftHandler: { _ in
          WorkspaceSessionDraft(
            id: "",
            personaId: "",
            directiveId: "",
            kitOverrides: []
          )
        },
        saveSessionHandler: { _, _, _, _, _ in
          "unused"
        },
        deleteSessionHandler: { workspaceURL, sessionID in
          #expect(workspaceURL.path() == "/Workspace")
          #expect(sessionID == "session-delete")
        }
      )
    )

    store.workspaceURL = workspaceURL

    try await store.deleteSession(sessionID: "session-delete")
  }

  @Test
  func refreshSessionPreviewLoadsPreviewForSelectedSession() async {
    let workspaceURL = URL(fileURLWithPath: "/Workspace")
    let snapshot = makeSessionSnapshot(
      sessionID: "session-a",
      fileName: "session-a.session.json"
    )

    let store = WorkspaceStore(
      snapshotBuilder: StubSnapshotBuilder { _ in
        snapshot
      },
      workspaceValidator: StubWorkspaceValidator { _ in
        WorkspaceValidationSnapshot(summary: "ok", issues: [])
      },
      sessionPreviewManager: StubSessionPreviewManager(
        loadPreviewHandler: { _, session in
          "preview-\(session.id)"
        },
        exportPreviewHandler: { _, _ in }
      )
    )

    store.workspaceURL = workspaceURL
    store.loadWorkspace()

    await waitFor {
      store.snapshot.sessions.first?.id == "session-a"
    }

    store.refreshSessionPreview(for: store.snapshot.sessions.first)

    await waitFor {
      store.sessionPreview == "preview-session-a"
        && !store.isLoadingSessionPreview
    }

    #expect(store.sessionPreviewErrorMessage == nil)
  }

  @Test
  func refreshSessionPreviewPublishesPreviewErrorMessageOnFailure() async {
    let workspaceURL = URL(fileURLWithPath: "/Workspace")
    let snapshot = makeSessionSnapshot(
      sessionID: "session-a",
      fileName: "session-a.session.json"
    )

    let store = WorkspaceStore(
      snapshotBuilder: StubSnapshotBuilder { _ in
        snapshot
      },
      workspaceValidator: StubWorkspaceValidator { _ in
        WorkspaceValidationSnapshot(summary: "ok", issues: [])
      },
      sessionPreviewManager: StubSessionPreviewManager(
        loadPreviewHandler: { _, _ in
          throw WorkspaceSnapshotBuildError(message: "preview failed")
        },
        exportPreviewHandler: { _, _ in }
      )
    )

    store.workspaceURL = workspaceURL
    store.loadWorkspace()

    await waitFor {
      store.snapshot.sessions.first?.id == "session-a"
    }

    store.refreshSessionPreview(for: store.snapshot.sessions.first)

    await waitFor {
      store.sessionPreviewErrorMessage == "preview failed"
        && !store.isLoadingSessionPreview
    }

    #expect(store.sessionPreview.isEmpty)
  }

  @Test
  func newerPreviewResultWinsWhenPreviewLoadsOverlap() async {
    let workspaceURL = URL(fileURLWithPath: "/Workspace")
    let snapshot = WorkspaceSnapshot(
      sessions: [
        WorkspaceSessionListItem(
          id: "session-a",
          personaId: "persona-a",
          directiveId: "directive-a",
          fileURL: URL(fileURLWithPath: "/session-a.session.json"),
          sourceScope: .project
        ),
        WorkspaceSessionListItem(
          id: "session-b",
          personaId: "persona-b",
          directiveId: "directive-b",
          fileURL: URL(fileURLWithPath: "/session-b.session.json"),
          sourceScope: .project
        ),
      ],
      personas: [],
      directives: [],
      kits: [],
      skills: [],
      intents: [],
      essentials: []
    )

    let store = WorkspaceStore(
      snapshotBuilder: StubSnapshotBuilder { _ in
        snapshot
      },
      workspaceValidator: StubWorkspaceValidator { _ in
        WorkspaceValidationSnapshot(summary: "ok", issues: [])
      },
      sessionPreviewManager: StubSessionPreviewManager(
        loadPreviewHandler: { _, session in
          if session.id == "session-a" {
            Thread.sleep(forTimeInterval: 0.3)
            return "preview-a"
          }

          return "preview-b"
        },
        exportPreviewHandler: { _, _ in }
      )
    )

    store.workspaceURL = workspaceURL
    store.loadWorkspace()

    await waitFor {
      store.snapshot.sessions.count == 2
    }

    store.refreshSessionPreview(for: store.snapshot.sessions.first { $0.id == "session-a" })
    try? await Task.sleep(for: .milliseconds(20))
    store.refreshSessionPreview(for: store.snapshot.sessions.first { $0.id == "session-b" })

    await waitFor {
      store.sessionPreview == "preview-b"
        && !store.isLoadingSessionPreview
    }

    try? await Task.sleep(for: .milliseconds(350))
    #expect(store.sessionPreview == "preview-b")
  }

  @Test
  func loadWorkspaceRestoresPreviewForSameSessionID() async {
    let firstWorkspaceURL = URL(fileURLWithPath: "/WorkspaceA")
    let secondWorkspaceURL = URL(fileURLWithPath: "/WorkspaceB")

    let firstSnapshot = makeSessionSnapshot(
      sessionID: "session-a",
      fileName: "session-a-first.session.json"
    )
    let secondSnapshot = makeSessionSnapshot(
      sessionID: "session-a",
      fileName: "session-a-second.session.json"
    )

    let store = WorkspaceStore(
      snapshotBuilder: StubSnapshotBuilder { workspaceURL in
        if workspaceURL.standardizedFileURL == firstWorkspaceURL.standardizedFileURL {
          return firstSnapshot
        }

        return secondSnapshot
      },
      workspaceValidator: StubWorkspaceValidator { _ in
        WorkspaceValidationSnapshot(summary: "ok", issues: [])
      },
      sessionPreviewManager: StubSessionPreviewManager(
        loadPreviewHandler: { _, session in
          session.fileURL.lastPathComponent
        },
        exportPreviewHandler: { _, _ in }
      )
    )

    store.workspaceURL = firstWorkspaceURL
    store.loadWorkspace()

    await waitFor {
      store.snapshot.sessions.first?.fileURL.lastPathComponent == "session-a-first.session.json"
    }

    store.refreshSessionPreview(for: store.snapshot.sessions.first)

    await waitFor {
      store.sessionPreview == "session-a-first.session.json"
    }

    store.workspaceURL = secondWorkspaceURL
    store.loadWorkspace()

    await waitFor {
      store.snapshot.sessions.first?.fileURL.lastPathComponent == "session-a-second.session.json"
    }

    await waitFor {
      store.sessionPreview == "session-a-second.session.json"
        && !store.isLoadingSessionPreview
    }
  }

  @Test
  func openWorkspacePickerLoadsSelectedWorkspaceFromInjectedPicker() async {
    let selectedWorkspaceURL = URL(fileURLWithPath: "/PickedWorkspace")

    let store = WorkspaceStore(
      snapshotBuilder: StubSnapshotBuilder { workspaceURL in
        #expect(workspaceURL.standardizedFileURL == selectedWorkspaceURL.standardizedFileURL)
        return WorkspaceSnapshot.empty
      },
      workspaceValidator: StubWorkspaceValidator { _ in
        WorkspaceValidationSnapshot(summary: "ok", issues: [])
      },
      workspacePicker: StubWorkspacePicker(
        selectedURL: selectedWorkspaceURL
      )
    )

    store.openWorkspacePicker()

    await waitFor {
      store.workspaceURL?.standardizedFileURL == selectedWorkspaceURL.standardizedFileURL
    }
  }

  @Test
  func copySessionPreviewUsesInjectedPasteboardWriter() throws {
    let expectedPreview = "preview-to-copy"
    let store = WorkspaceStore(
      pasteboardWriter: StubPasteboardWriter(
        expectedValue: expectedPreview,
        shouldSucceed: true
      )
    )

    store.sessionPreview = expectedPreview
    try store.copySessionPreviewToPasteboard()
  }

  @Test
  func exportSessionPreviewUsesInjectedDestinationPicker() async throws {
    let destinationURL = URL(fileURLWithPath: "/Exports/preview.md")
    let expectedPreview = "preview-to-export"

    let store = WorkspaceStore(
      sessionPreviewManager: StubSessionPreviewManager(
        loadPreviewHandler: { _, _ in
          "unused"
        },
        exportPreviewHandler: { preview, destination in
          #expect(preview == expectedPreview)
          #expect(destination == destinationURL)
        }
      ),
      previewExportDestinationPicker: StubPreviewExportDestinationPicker(
        destinationURL: destinationURL
      )
    )

    store.sessionPreview = expectedPreview
    let didExport = try await store.exportSessionPreviewWithSavePanel()

    #expect(didExport)
  }

  @Test
  func exportSessionPreviewReturnsFalseWhenDestinationPickerCancels() async throws {
    let store = WorkspaceStore(
      previewExportDestinationPicker: StubPreviewExportDestinationPicker(
        destinationURL: nil
      )
    )

    store.sessionPreview = "preview-to-export"
    let didExport = try await store.exportSessionPreviewWithSavePanel()

    #expect(!didExport)
  }
}

private struct StubSnapshotBuilder: WorkspaceSnapshotBuilding, Sendable {
  let buildHandler: @Sendable (URL) throws -> WorkspaceSnapshot

  func build(workspaceURL: URL) throws -> WorkspaceSnapshot {
    try buildHandler(workspaceURL)
  }
}

private struct StubWorkspaceValidator: WorkspaceValidating, Sendable {
  let validateHandler: @Sendable (URL) throws -> WorkspaceValidationSnapshot

  func validate(workspaceURL: URL) throws -> WorkspaceValidationSnapshot {
    try validateHandler(workspaceURL)
  }
}

private struct StubSessionManager: WorkspaceSessionManaging, Sendable {
  let loadDraftHandler: @Sendable (URL) throws -> WorkspaceSessionDraft
  let saveSessionHandler: @Sendable (URL, WorkspaceSessionDraft, String?, Set<String>, Set<String>) throws -> String
  let deleteSessionHandler: @Sendable (URL, String) throws -> Void

  func loadDraft(fileURL: URL) throws -> WorkspaceSessionDraft {
    try loadDraftHandler(fileURL)
  }

  func saveSession(
    workspaceURL: URL,
    draft: WorkspaceSessionDraft,
    originalSessionID: String?,
    validPersonaIDs: Set<String>,
    validDirectiveIDs: Set<String>
  ) throws -> String {
    try saveSessionHandler(
      workspaceURL,
      draft,
      originalSessionID,
      validPersonaIDs,
      validDirectiveIDs
    )
  }

  func deleteSession(
    workspaceURL: URL,
    sessionID: String
  ) throws {
    try deleteSessionHandler(workspaceURL, sessionID)
  }
}

private func makeSnapshot(id: String) -> WorkspaceSnapshot {
  WorkspaceSnapshot(
    sessions: [],
    personas: [
      WorkspaceListItem(
        id: id,
        displayName: id,
        fileURL: URL(fileURLWithPath: "/\(id).persona.json"),
        sourceScope: .project
      )
    ],
    directives: [],
    kits: [],
    skills: [],
    intents: [],
    essentials: []
  )
}

private func makeSessionSnapshot(
  sessionID: String,
  fileName: String
) -> WorkspaceSnapshot {
  WorkspaceSnapshot(
    sessions: [
      WorkspaceSessionListItem(
        id: sessionID,
        personaId: "persona-\(sessionID)",
        directiveId: "directive-\(sessionID)",
        fileURL: URL(fileURLWithPath: "/\(fileName)"),
        sourceScope: .project
      )
    ],
    personas: [],
    directives: [],
    kits: [],
    skills: [],
    intents: [],
    essentials: []
  )
}

private func makeValidation(entityID: String) -> WorkspaceValidationSnapshot {
  WorkspaceValidationSnapshot(
    summary: "Validation summary: personas=1 kits=0 directives=0 intents=0 skills=0 essentials=0 errors=1",
    issues: [
      WorkspaceValidationIssue(
        entityType: .persona,
        entityId: entityID,
        field: "schema",
        filePath: "Packs/personas/\(entityID).persona.json",
        message: "Synthetic test issue.",
        severity: .error
      )
    ]
  )
}

private struct StubSessionPreviewManager: WorkspaceSessionPreviewManaging, Sendable {
  let loadPreviewHandler: @Sendable (URL, WorkspaceSessionListItem) throws -> String
  let exportPreviewHandler: @Sendable (String, URL) throws -> Void

  func loadPreview(
    workspaceURL: URL,
    session: WorkspaceSessionListItem
  ) throws -> String {
    try loadPreviewHandler(workspaceURL, session)
  }

  func exportPreview(
    _ preview: String,
    to destinationURL: URL
  ) throws {
    try exportPreviewHandler(preview, destinationURL)
  }
}

private struct StubWorkspacePicker: WorkspacePicking {
  let selectedURL: URL?

  @MainActor
  func pickWorkspaceURL() -> URL? {
    selectedURL
  }
}

private struct StubPreviewExportDestinationPicker: PreviewExportDestinationPicking {
  let destinationURL: URL?

  @MainActor
  func pickPreviewDestination(suggestedFilename: String) -> URL? {
    destinationURL
  }
}

private struct StubPasteboardWriter: PasteboardWriting {
  let expectedValue: String
  let shouldSucceed: Bool

  @MainActor
  func writeString(_ value: String) -> Bool {
    guard value == expectedValue else {
      return false
    }

    return shouldSucceed
  }
}
