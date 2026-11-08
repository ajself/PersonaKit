import ContextCore
import ContextWorkspaceCore
import Foundation
import StudioFoundation
import Synchronization
import Testing

@testable import StudioFeatures

@Suite(.serialized)
@MainActor
struct WorkspaceStoreSessionActionsTests {
  @Test
  func newSessionEditorDraftUsesFirstPersonaAndDirective() async {
    let workspaceURL = URL(fileURLWithPath: "/Workspace")

    let store = WorkspaceStore(
      snapshotBuilder: WorkspaceStoreStubSnapshotBuilder { _ in
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
          skills: []
        )
      },
      workspaceValidator: WorkspaceStoreStubWorkspaceValidator { _ in
        WorkspaceValidationSnapshot(summary: "ok", issues: [])
      }
    )

    store.workspaceURL = workspaceURL
    store.loadWorkspace()

    await waitFor {
      store.snapshot.personas.count == 2
    }

    store.presentNewSessionEditor()
    let draft = store.sessionEditorPresentation?.draft

    #expect(draft?.id.isEmpty == true)
    #expect(draft?.personaId == "persona-a")
    #expect(draft?.directiveId == "directive-a")
    #expect(draft?.kitOverrides.isEmpty == true)
  }

  @Test
  func saveSessionForwardsValidatedIDsToSessionManager() async throws {
    let workspaceURL = URL(fileURLWithPath: "/Workspace/../Workspace")
    let expectedDraft = WorkspaceSessionDraft(
      id: "session-a",
      personaId: "persona-a",
      directiveId: "directive-a",
      kitOverrides: ["kit-b", "kit-a"]
    )

    let store = WorkspaceStore(
      snapshotBuilder: WorkspaceStoreStubSnapshotBuilder { _ in
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
          kits: [
            WorkspaceListItem(
              id: "kit-a",
              displayName: "Kit A",
              fileURL: URL(fileURLWithPath: "/kit-a.kit.json"),
              sourceScope: .project
            ),
            WorkspaceListItem(
              id: "kit-b",
              displayName: "Kit B",
              fileURL: URL(fileURLWithPath: "/kit-b.kit.json"),
              sourceScope: .project
            ),
          ],
          skills: []
        )
      },
      workspaceValidator: WorkspaceStoreStubWorkspaceValidator { _ in
        WorkspaceValidationSnapshot(summary: "ok", issues: [])
      },
      sessionManager: WorkspaceStoreStubSessionManager(
        loadDraftHandler: { _ in
          WorkspaceSessionDraft(
            id: "",
            personaId: "",
            directiveId: "",
            kitOverrides: []
          )
        },
        saveSessionHandler: { workspaceURL, draft, originalSessionID, validPersonaIDs, validDirectiveIDs, validKitIDs in
          #expect(workspaceURL.path() == "/Workspace")
          #expect(draft == expectedDraft)
          #expect(originalSessionID == "session-old")
          #expect(validPersonaIDs == Set(["persona-a"]))
          #expect(validDirectiveIDs == Set(["directive-a"]))
          #expect(validKitIDs == Set(["kit-a", "kit-b"]))

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
      originalSessionID: "session-old",
      expectedWorkspaceURL: workspaceURL
    )

    #expect(savedSessionID == "session-a")
  }

  @Test
  func confirmSessionDeletionForwardsToSessionManager() async throws {
    let workspaceURL = URL(fileURLWithPath: "/Workspace/../Workspace")

    let store = WorkspaceStore(
      snapshotBuilder: WorkspaceStoreStubSnapshotBuilder { _ in
        WorkspaceSnapshot(
          sessions: [
            WorkspaceSessionListItem(
              id: "session-delete",
              personaId: "persona-a",
              directiveId: "directive-a",
              fileURL: URL(fileURLWithPath: "/Workspace/.personakit/Sessions/session-delete.session.json"),
              sourceScope: .project
            )
          ],
          personas: [],
          directives: [],
          kits: [],
          skills: []
        )
      },
      workspaceValidator: WorkspaceStoreStubWorkspaceValidator { _ in
        WorkspaceValidationSnapshot(summary: "ok", issues: [])
      },
      sessionManager: WorkspaceStoreStubSessionManager(
        loadDraftHandler: { _ in
          WorkspaceSessionDraft(
            id: "",
            personaId: "",
            directiveId: "",
            kitOverrides: []
          )
        },
        saveSessionHandler: { _, _, _, _, _, _ in
          "unused"
        },
        deleteSessionHandler: { workspaceURL, sessionID in
          #expect(workspaceURL.path() == "/Workspace")
          #expect(sessionID == "session-delete")
        }
      )
    )

    store.workspaceURL = workspaceURL
    store.loadWorkspace()

    await waitFor {
      store.snapshot.sessions.first?.id == "session-delete"
    }

    var deletedSessionIDs: [String] = []
    store.requestSessionDeletion(store.snapshot.sessions[0])
    let presentation = try #require(store.pendingSessionDeletion)
    store.confirmSessionDeletion(presentation) { deletedSessionIDs.append($0) }

    await waitFor { deletedSessionIDs == ["session-delete"] }
    #expect(store.sessionActionErrorMessage == nil)
  }

  @Test
  func saveSessionRejectsExpectedWorkspaceMismatchBeforeMutating() async throws {
    let recorder = SessionMutationRecorder()
    let currentWorkspaceURL = URL(fileURLWithPath: "/WorkspaceB")
    let staleWorkspaceURL = URL(fileURLWithPath: "/WorkspaceA")
    let expectedDraft = WorkspaceSessionDraft(
      id: "session-a",
      personaId: "persona-a",
      directiveId: "directive-a",
      kitOverrides: []
    )
    let store = WorkspaceStore(
      snapshotBuilder: WorkspaceStoreStubSnapshotBuilder { _ in
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
          skills: []
        )
      },
      workspaceValidator: WorkspaceStoreStubWorkspaceValidator { _ in
        WorkspaceValidationSnapshot(summary: "ok", issues: [])
      },
      sessionManager: WorkspaceStoreStubSessionManager(
        loadDraftHandler: { _ in
          expectedDraft
        },
        saveSessionHandler: { _, _, _, _, _, _ in
          recorder.recordSave()
          return "session-a"
        },
        deleteSessionHandler: { _, _ in }
      )
    )

    store.workspaceURL = currentWorkspaceURL
    store.loadWorkspace()

    await waitFor {
      store.snapshot.personas.first?.id == "persona-a"
    }

    await #expect(throws: WorkspaceSnapshotBuildError.self) {
      try await store.saveSession(
        draft: expectedDraft,
        originalSessionID: nil,
        expectedWorkspaceURL: staleWorkspaceURL
      )
    }
    #expect(recorder.saveCount == 0)
  }

  @Test
  func confirmSessionDeletionRejectsStaleSessionFileBeforeMutating() async throws {
    let recorder = SessionMutationRecorder()
    let workspaceURL = URL(fileURLWithPath: "/Workspace")
    let currentSessionFileURL = URL(
      fileURLWithPath: "/Workspace/.personakit/Sessions/session-delete.session.json"
    )
    let staleSessionFileURL = URL(
      fileURLWithPath: "/Workspace/.personakit/Sessions/session-delete-old.session.json"
    )
    let snapshot = WorkspaceSnapshot(
      sessions: [
        WorkspaceSessionListItem(
          id: "session-delete",
          personaId: "persona-a",
          directiveId: "directive-a",
          fileURL: currentSessionFileURL,
          sourceScope: .project
        )
      ],
      personas: [],
      directives: [],
      kits: [],
      skills: []
    )
    let store = WorkspaceStore(
      snapshotBuilder: WorkspaceStoreStubSnapshotBuilder { _ in
        snapshot
      },
      workspaceValidator: WorkspaceStoreStubWorkspaceValidator { _ in
        WorkspaceValidationSnapshot(summary: "ok", issues: [])
      },
      sessionManager: WorkspaceStoreStubSessionManager(
        loadDraftHandler: { _ in
          WorkspaceSessionDraft(
            id: "",
            personaId: "",
            directiveId: "",
            kitOverrides: []
          )
        },
        saveSessionHandler: { _, _, _, _, _, _ in
          "unused"
        },
        deleteSessionHandler: { _, _ in
          recorder.recordDelete()
        }
      )
    )

    store.workspaceURL = workspaceURL
    store.loadWorkspace()

    await waitFor {
      store.snapshot.sessions.first?.id == "session-delete"
    }

    let staleSession = WorkspaceSessionListItem(
      id: "session-delete",
      personaId: "persona-a",
      directiveId: "directive-a",
      fileURL: staleSessionFileURL,
      sourceScope: .project
    )
    store.requestSessionDeletion(staleSession)
    let presentation = try #require(store.pendingSessionDeletion)
    store.confirmSessionDeletion(presentation) { _ in
      Issue.record("A stale session file must not report a deletion.")
    }

    await waitFor {
      store.sessionActionErrorMessage != nil
    }
    #expect(store.sessionActionErrorMessage?.contains("no longer available") == true)
    #expect(recorder.deleteCount == 0)
  }

  @Test
  func refreshSessionPreviewLoadsPreviewForSelectedSession() async {
    let workspaceURL = URL(fileURLWithPath: "/Workspace")
    let snapshot = makeSessionSnapshot(
      sessionID: "session-a",
      fileName: "session-a.session.json"
    )

    let store = WorkspaceStore(
      snapshotBuilder: WorkspaceStoreStubSnapshotBuilder { _ in
        snapshot
      },
      workspaceValidator: WorkspaceStoreStubWorkspaceValidator { _ in
        WorkspaceValidationSnapshot(summary: "ok", issues: [])
      },
      sessionPreviewManager: WorkspaceStoreStubSessionPreviewManager(
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
  func refreshSessionPreviewForwardsStandardizedWorkspaceURL() async {
    let workspaceURL = URL(fileURLWithPath: "/Workspace/../Workspace")
    let snapshot = makeSessionSnapshot(
      sessionID: "session-a",
      fileName: "session-a.session.json"
    )

    let store = WorkspaceStore(
      snapshotBuilder: WorkspaceStoreStubSnapshotBuilder { _ in
        snapshot
      },
      workspaceValidator: WorkspaceStoreStubWorkspaceValidator { _ in
        WorkspaceValidationSnapshot(summary: "ok", issues: [])
      },
      sessionPreviewManager: WorkspaceStoreStubSessionPreviewManager(
        loadPreviewHandler: { workspaceURL, session in
          #expect(workspaceURL.path() == "/Workspace")
          return "preview-\(session.id)"
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
  }

  @Test
  func refreshSessionPreviewPublishesPreviewErrorMessageOnFailure() async {
    let workspaceURL = URL(fileURLWithPath: "/Workspace")
    let snapshot = makeSessionSnapshot(
      sessionID: "session-a",
      fileName: "session-a.session.json"
    )

    let store = WorkspaceStore(
      snapshotBuilder: WorkspaceStoreStubSnapshotBuilder { _ in
        snapshot
      },
      workspaceValidator: WorkspaceStoreStubWorkspaceValidator { _ in
        WorkspaceValidationSnapshot(summary: "ok", issues: [])
      },
      sessionPreviewManager: WorkspaceStoreStubSessionPreviewManager(
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
  func refreshSessionPreviewIgnoresStaleResultAfterWorkspaceIsCleared() async {
    let workspaceURL = URL(fileURLWithPath: "/Workspace")
    let previewGate = BlockingCallGate()
    let snapshot = makeSessionSnapshot(
      sessionID: "session-a",
      fileName: "session-a.session.json"
    )

    let store = WorkspaceStore(
      snapshotBuilder: WorkspaceStoreStubSnapshotBuilder { _ in
        snapshot
      },
      workspaceValidator: WorkspaceStoreStubWorkspaceValidator { _ in
        WorkspaceValidationSnapshot(summary: "ok", issues: [])
      },
      sessionPreviewManager: WorkspaceStoreStubSessionPreviewManager(
        loadPreviewHandler: { _, session in
          _ = previewGate.markStarted()
          previewGate.waitUntilReleased()
          previewGate.markFinished()
          return "preview-\(session.id)"
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
      previewGate.hasStarted
    }

    store.workspaceURL = nil
    store.refreshSessionPreview(for: store.snapshot.sessions.first)

    #expect(store.sessionPreview.isEmpty)
    #expect(store.sessionPreviewErrorMessage == nil)
    #expect(!store.isLoadingSessionPreview)

    previewGate.release()

    await waitFor {
      previewGate.hasFinished
    }
    await yieldTasks()

    #expect(store.sessionPreview.isEmpty)
    #expect(store.sessionPreviewErrorMessage == nil)
    #expect(!store.isLoadingSessionPreview)
  }

  @Test
  func newerPreviewResultWinsWhenPreviewLoadsOverlap() async {
    let workspaceURL = URL(fileURLWithPath: "/Workspace")
    let previewGate = BlockingCallGate()
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
      skills: []
    )

    let store = WorkspaceStore(
      snapshotBuilder: WorkspaceStoreStubSnapshotBuilder { _ in
        snapshot
      },
      workspaceValidator: WorkspaceStoreStubWorkspaceValidator { _ in
        WorkspaceValidationSnapshot(summary: "ok", issues: [])
      },
      sessionPreviewManager: WorkspaceStoreStubSessionPreviewManager(
        loadPreviewHandler: { _, session in
          if session.id == "session-a" {
            _ = previewGate.markStarted()
            previewGate.waitUntilReleased()
            previewGate.markFinished()
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
    await waitFor {
      previewGate.hasStarted
    }
    store.refreshSessionPreview(for: store.snapshot.sessions.first { $0.id == "session-b" })
    previewGate.release()

    await waitFor {
      store.sessionPreview == "preview-b"
        && !store.isLoadingSessionPreview
    }

    await waitFor {
      previewGate.hasFinished
    }
    await yieldTasks()
    #expect(store.sessionPreview == "preview-b")
  }

  @Test
  func refreshSessionMapLoadsMapForSelectedSession() async {
    let workspaceURL = URL(fileURLWithPath: "/Workspace")
    let sessionFileURL = URL(fileURLWithPath: "/Workspace/.personakit/Sessions/session-a.session.json")
    let snapshot = WorkspaceSnapshot(
      sessions: [
        WorkspaceSessionListItem(
          id: "session-a",
          personaId: "unused",
          directiveId: "unused",
          fileURL: sessionFileURL,
          sourceScope: .project
        )
      ],
      personas: [],
      directives: [],
      kits: [],
      skills: []
    )

    let store = WorkspaceStore(
      snapshotBuilder: WorkspaceStoreStubSnapshotBuilder { _ in
        snapshot
      },
      workspaceValidator: WorkspaceStoreStubWorkspaceValidator { _ in
        WorkspaceValidationSnapshot(summary: "ok", issues: [])
      },
      sessionManager: WorkspaceStoreStubSessionManager(
        loadDraftHandler: { fileURL in
          #expect(fileURL == sessionFileURL)

          return WorkspaceSessionDraft(
            id: "session-a",
            personaId: "persona-a",
            directiveId: "directive-a",
            kitOverrides: ["kit-a"]
          )
        },
        saveSessionHandler: { _, _, _, _, _, _ in
          "session-a"
        },
        deleteSessionHandler: { _, _ in }
      ),
      sessionMapBuilder: WorkspaceStoreStubSessionMapBuilder(
        buildHandler: { workspaceURL, personaId, directiveId, kitOverrides in
          #expect(workspaceURL.path() == "/Workspace")
          #expect(personaId == "persona-a")
          #expect(directiveId == "directive-a")
          #expect(kitOverrides == ["kit-a"])

          return WorkspaceSessionMap(
            nodes: [
              WorkspaceSessionMapNode(
                key: "persona:\(personaId)",
                id: personaId,
                displayName: personaId,
                kind: .persona,
                isMissing: false,
                badges: []
              )
            ],
            edges: [],
            resolutionErrors: [],
            isFullyResolved: true
          )
        }
      )
    )

    store.workspaceURL = workspaceURL
    store.loadWorkspace()

    await waitFor {
      store.snapshot.sessions.first?.id == "session-a"
    }

    store.refreshSessionMap(for: store.snapshot.sessions.first)

    await waitFor {
      store.sessionMap?.nodes.contains(where: { $0.key == "persona:persona-a" }) == true
        && !store.isLoadingSessionMap
    }

    #expect(store.sessionMapErrorMessage == nil)
  }

  @Test
  func refreshSessionMapIgnoresStaleResultAfterWorkspaceIsCleared() async {
    let workspaceURL = URL(fileURLWithPath: "/Workspace")
    let sessionFileURL = URL(fileURLWithPath: "/Workspace/.personakit/Sessions/session-a.session.json")
    let mapGate = BlockingCallGate()
    let snapshot = WorkspaceSnapshot(
      sessions: [
        WorkspaceSessionListItem(
          id: "session-a",
          personaId: "unused",
          directiveId: "unused",
          fileURL: sessionFileURL,
          sourceScope: .project
        )
      ],
      personas: [],
      directives: [],
      kits: [],
      skills: []
    )

    let store = WorkspaceStore(
      snapshotBuilder: WorkspaceStoreStubSnapshotBuilder { _ in
        snapshot
      },
      workspaceValidator: WorkspaceStoreStubWorkspaceValidator { _ in
        WorkspaceValidationSnapshot(summary: "ok", issues: [])
      },
      sessionManager: WorkspaceStoreStubSessionManager(
        loadDraftHandler: { _ in
          WorkspaceSessionDraft(
            id: "session-a",
            personaId: "persona-a",
            directiveId: "directive-a",
            kitOverrides: []
          )
        },
        saveSessionHandler: { _, _, _, _, _, _ in
          "session-a"
        },
        deleteSessionHandler: { _, _ in }
      ),
      sessionMapBuilder: WorkspaceStoreStubSessionMapBuilder(
        buildHandler: { _, _, _, _ in
          _ = mapGate.markStarted()
          mapGate.waitUntilReleased()
          mapGate.markFinished()

          return WorkspaceSessionMap(
            nodes: [
              WorkspaceSessionMapNode(
                key: "persona:persona-a",
                id: "persona-a",
                displayName: "Persona A",
                kind: .persona,
                isMissing: false,
                badges: []
              )
            ],
            edges: [],
            resolutionErrors: [],
            isFullyResolved: true
          )
        }
      )
    )

    store.workspaceURL = workspaceURL
    store.loadWorkspace()

    await waitFor {
      store.snapshot.sessions.first?.id == "session-a"
    }

    store.refreshSessionMap(for: store.snapshot.sessions.first)
    await waitFor {
      mapGate.hasStarted
    }

    store.workspaceURL = nil
    store.refreshSessionMap(for: nil)

    #expect(store.sessionMap == nil)
    #expect(store.sessionMapErrorMessage == nil)
    #expect(!store.isLoadingSessionMap)

    mapGate.release()

    await waitFor {
      mapGate.hasFinished
    }
    await yieldTasks()

    #expect(store.sessionMap == nil)
    #expect(store.sessionMapErrorMessage == nil)
    #expect(!store.isLoadingSessionMap)
  }

  @Test
  func clearSessionMapDropsLoadingMapAndSkipsRebuildOnReload() async {
    let workspaceURL = URL(fileURLWithPath: "/Workspace")
    let sessionFileURL = URL(fileURLWithPath: "/Workspace/.personakit/Sessions/session-a.session.json")
    let personaFileURL = URL(fileURLWithPath: "/Workspace/.personakit/Personas/persona-a.json")
    let mapGate = BlockingCallGate()
    let validationCount = Mutex(0)
    let mapBuildCount = Mutex(0)
    let snapshot = WorkspaceSnapshot(
      sessions: [
        WorkspaceSessionListItem(
          id: "session-a",
          personaId: "unused",
          directiveId: "unused",
          fileURL: sessionFileURL,
          sourceScope: .project
        )
      ],
      personas: [],
      directives: [],
      kits: [],
      skills: []
    )

    let store = WorkspaceStore(
      snapshotBuilder: WorkspaceStoreStubSnapshotBuilder { _ in
        snapshot
      },
      workspaceValidator: WorkspaceStoreStubWorkspaceValidator { _ in
        validationCount.withLock { $0 += 1 }

        return WorkspaceValidationSnapshot(summary: "ok", issues: [])
      },
      sessionManager: WorkspaceStoreStubSessionManager(
        loadDraftHandler: { _ in
          WorkspaceSessionDraft(
            id: "session-a",
            personaId: "persona-a",
            directiveId: "directive-a",
            kitOverrides: []
          )
        },
        saveSessionHandler: { _, _, _, _, _, _ in
          "session-a"
        },
        deleteSessionHandler: { _, _ in }
      ),
      sessionMapBuilder: WorkspaceStoreStubSessionMapBuilder(
        buildHandler: { _, _, _, _ in
          mapBuildCount.withLock { $0 += 1 }
          _ = mapGate.markStarted()
          mapGate.waitUntilReleased()
          mapGate.markFinished()

          return WorkspaceSessionMap(
            nodes: [],
            edges: [],
            resolutionErrors: [],
            isFullyResolved: true
          )
        }
      )
    )

    store.workspaceURL = workspaceURL
    store.loadWorkspace()

    await waitFor {
      store.snapshot.sessions.first?.id == "session-a"
    }

    store.refreshSessionMap(for: store.snapshot.sessions.first)
    await waitFor {
      mapGate.hasStarted
    }

    // Leaving Map mode mid-load.
    store.clearSessionMap()

    #expect(store.sessionMap == nil)
    #expect(!store.isLoadingSessionMap)

    mapGate.release()
    await waitFor {
      mapGate.hasFinished
    }

    // Validation starts after the map revalidation, so a second validation means the reload
    // has already decided whether to rebuild the map.
    store.reloadWorkspaceAfterExternalChange(changedFileURLs: [personaFileURL])
    await waitFor {
      validationCount.withLock { $0 } == 2
    }
    await yieldTasks()

    #expect(mapBuildCount.withLock { $0 } == 1)
    #expect(store.sessionMap == nil)
    #expect(!store.isLoadingSessionMap)
  }

  @Test(arguments: [true, false])
  func reloadRebuildsTheSessionMapOnlyWhileAMapIsOnScreen(mapIsOnScreen: Bool) async {
    let sessionFileURL = URL(fileURLWithPath: "/Workspace/.personakit/Sessions/session-a.session.json")
    let validationCount = Mutex(0)
    let mapBuildCount = Mutex(0)
    let snapshot = WorkspaceSnapshot(
      sessions: [
        WorkspaceSessionListItem(
          id: "session-a",
          personaId: "unused",
          directiveId: "unused",
          fileURL: sessionFileURL,
          sourceScope: .project
        )
      ],
      personas: [],
      directives: [],
      kits: [],
      skills: []
    )
    let store = WorkspaceStore(
      snapshotBuilder: WorkspaceStoreStubSnapshotBuilder { _ in
        snapshot
      },
      workspaceValidator: WorkspaceStoreStubWorkspaceValidator { _ in
        validationCount.withLock { $0 += 1 }
        return WorkspaceValidationSnapshot(summary: "ok", issues: [])
      },
      sessionManager: WorkspaceStoreStubSessionManager(
        loadDraftHandler: { _ in
          WorkspaceSessionDraft(id: "session-a", personaId: "persona-a", directiveId: "directive-a", kitOverrides: [])
        },
        saveSessionHandler: { _, _, _, _, _, _ in
          "session-a"
        },
        deleteSessionHandler: { _, _ in }
      ),
      sessionMapBuilder: WorkspaceStoreStubSessionMapBuilder(
        buildHandler: { _, _, _, _ in
          let count = mapBuildCount.withLock { count in
            count += 1
            return count
          }
          return WorkspaceSessionMap(
            nodes: [
              WorkspaceSessionMapNode(
                key: "persona:persona-\(count)",
                id: "persona-\(count)",
                displayName: "Persona",
                kind: .persona,
                isMissing: false,
                badges: []
              )
            ],
            edges: [],
            resolutionErrors: [],
            isFullyResolved: true
          )
        }
      )
    )

    store.workspaceURL = URL(fileURLWithPath: "/Workspace")
    store.loadWorkspace()
    await waitFor {
      store.snapshot.sessions.first?.id == "session-a"
    }

    let firstWindowMap = UUID()
    let secondWindowMap = UUID()
    store.sessionMapDidAppear(id: firstWindowMap)
    store.sessionMapDidAppear(id: firstWindowMap)
    store.sessionMapDidAppear(id: secondWindowMap)
    store.refreshSessionMap(for: store.snapshot.sessions.first)
    await waitFor {
      store.sessionMap != nil
    }

    // One window leaves Sessions; a repeated appear in the other must not count twice.
    store.sessionMapDidDisappear(id: secondWindowMap)
    if !mapIsOnScreen {
      store.sessionMapDidDisappear(id: firstWindowMap)
    }

    // Validation starts after the map revalidation, so a second validation means the reload
    // has already decided whether to rebuild the map.
    store.reloadWorkspaceAfterExternalChange(changedFileURLs: [sessionFileURL])
    await waitFor {
      validationCount.withLock { $0 } == 2
    }
    if mapIsOnScreen {
      await waitFor {
        mapBuildCount.withLock { $0 } == 2
      }
    }
    await yieldTasks()

    #expect(mapBuildCount.withLock { $0 } == (mapIsOnScreen ? 2 : 1))
    #expect((store.sessionMap != nil) == mapIsOnScreen)

    guard !mapIsOnScreen else {
      return
    }

    // Coming back to Sessions loads a fresh map.
    store.sessionMapDidAppear(id: firstWindowMap)
    store.refreshSessionMap(for: store.snapshot.sessions.first)
    await waitFor {
      store.sessionMap != nil
    }

    #expect(mapBuildCount.withLock { $0 } == 2)
  }

  private func yieldTasks(_ iterations: Int = 50) async {
    for _ in 0..<iterations {
      await Task.yield()
    }
  }

  @Test
  func clearingWorkspaceClearsDraftSessionMapState() async {
    let workspaceURL = URL(fileURLWithPath: "/Workspace")

    let store = WorkspaceStore(
      snapshotBuilder: WorkspaceStoreStubSnapshotBuilder { _ in
        WorkspaceSnapshot.empty
      },
      workspaceValidator: WorkspaceStoreStubWorkspaceValidator { _ in
        WorkspaceValidationSnapshot(summary: "ok", issues: [])
      },
      sessionMapBuilder: WorkspaceStoreStubSessionMapBuilder(
        buildHandler: { _, personaId, _, _ in
          WorkspaceSessionMap(
            nodes: [
              WorkspaceSessionMapNode(
                key: "persona:\(personaId)",
                id: personaId,
                displayName: personaId,
                kind: .persona,
                isMissing: false,
                badges: []
              )
            ],
            edges: [],
            resolutionErrors: [],
            isFullyResolved: true
          )
        }
      )
    )

    store.workspaceURL = workspaceURL
    store.loadWorkspace()
    store.refreshDraftSessionMap(
      for: WorkspaceSessionDraft(
        id: "draft",
        personaId: "persona-a",
        directiveId: "directive-a",
        kitOverrides: []
      )
    )

    await waitFor {
      store.draftSessionMap?.nodes.contains(where: { $0.key == "persona:persona-a" }) == true
    }

    store.workspaceURL = nil

    #expect(store.draftSessionMap == nil)
    #expect(store.draftSessionMapErrorMessage == nil)
    #expect(!store.isLoadingDraftSessionMap)
  }

  @Test
  func copySessionPreviewUsesInjectedPasteboardWriter() {
    let expectedPreview = "preview-to-copy"
    let store = WorkspaceStore(
      pasteboardWriter: WorkspaceStoreStubPasteboardWriter(
        expectedValue: expectedPreview,
        shouldSucceed: true
      )
    )

    store.sessionPreview = expectedPreview
    store.copySessionPreviewReportingResult()

    #expect(store.sessionPreviewActionMessage == "Copied handoff context to clipboard.")
    #expect(!store.sessionPreviewActionIsError)
  }

  @Test
  func copySessionPreviewReportsAPasteboardFailure() {
    let store = WorkspaceStore(
      pasteboardWriter: WorkspaceStoreStubPasteboardWriter(
        expectedValue: "preview-to-copy",
        shouldSucceed: false
      )
    )

    store.sessionPreview = "preview-to-copy"
    store.copySessionPreviewReportingResult()

    #expect(store.sessionPreviewActionMessage == "Failed to copy handoff context to the clipboard.")
    #expect(store.sessionPreviewActionIsError)

    store.sessionSelectionDidChange()

    #expect(store.sessionPreviewActionMessage == nil)
    #expect(!store.sessionPreviewActionIsError)
  }

  @Test
  func exportSessionPreviewUsesInjectedDestinationPicker() async {
    let destinationURL = URL(fileURLWithPath: "/Exports/preview.md")
    let expectedPreview = "preview-to-export"

    let store = WorkspaceStore(
      sessionPreviewManager: WorkspaceStoreStubSessionPreviewManager(
        loadPreviewHandler: { _, _ in
          "unused"
        },
        exportPreviewHandler: { preview, destination in
          #expect(preview == expectedPreview)
          #expect(destination == destinationURL)
        }
      ),
      previewExportDestinationPicker: WorkspaceStoreStubPreviewExportDestinationPicker(
        destinationURL: destinationURL
      )
    )

    store.sessionPreview = expectedPreview
    store.exportSessionPreviewReportingResult()

    await waitFor {
      store.sessionPreviewActionMessage == "Exported handoff context."
    }
  }

  @Test
  func exportSessionPreviewReportsAWriteFailureAsAnError() async {
    let store = WorkspaceStore(
      sessionPreviewManager: WorkspaceStoreStubSessionPreviewManager(
        loadPreviewHandler: { _, _ in
          "unused"
        },
        exportPreviewHandler: { _, _ in
          throw WorkspaceSnapshotBuildError(message: "Disk full.")
        }
      ),
      previewExportDestinationPicker: WorkspaceStoreStubPreviewExportDestinationPicker(
        destinationURL: URL(fileURLWithPath: "/Exports/preview.md")
      )
    )

    store.sessionPreview = "preview-to-export"
    store.exportSessionPreviewReportingResult()

    await waitFor {
      store.sessionFeatureModel.previewExportTask == nil
    }
    #expect(store.sessionPreviewActionMessage?.contains("Disk full.") == true)
    #expect(store.sessionPreviewActionIsError)
  }

  @Test
  func exportSessionPreviewReportsNothingWhenDestinationPickerCancels() async {
    let store = WorkspaceStore(
      sessionPreviewManager: WorkspaceStoreStubSessionPreviewManager(
        loadPreviewHandler: { _, _ in
          "unused"
        },
        exportPreviewHandler: { _, _ in
          Issue.record("A cancelled save panel must not export.")
        }
      ),
      previewExportDestinationPicker: WorkspaceStoreStubPreviewExportDestinationPicker(
        destinationURL: nil
      )
    )

    store.sessionPreview = "preview-to-export"
    store.exportSessionPreviewReportingResult()

    await waitFor {
      store.sessionFeatureModel.previewExportTask == nil
    }
    #expect(store.sessionPreviewActionMessage == nil)
    #expect(!store.sessionPreviewActionIsError)
  }
}

private final class SessionMutationRecorder: Sendable {
  private struct State: Sendable {
    var deleteCount = 0
    var saveCount = 0
  }

  private let state = Mutex(State())

  var deleteCount: Int {
    state.withLock { $0.deleteCount }
  }

  var saveCount: Int {
    state.withLock { $0.saveCount }
  }

  func recordDelete() {
    state.withLock { state in
      state.deleteCount += 1
    }
  }

  func recordSave() {
    state.withLock { state in
      state.saveCount += 1
    }
  }
}
