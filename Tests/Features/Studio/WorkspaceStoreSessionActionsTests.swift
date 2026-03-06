import ContextCore
import ContextWorkspaceCore
import Foundation
import StudioFoundation
import Testing

@testable import StudioFeatures

@MainActor
struct WorkspaceStoreSessionActionsTests {
  @Test
  func defaultSessionDraftUsesFirstPersonaAndDirective() async {
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
          skills: [],
          intents: [],
          essentials: []
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

    let draft = store.defaultSessionDraft()

    #expect(draft.id.isEmpty)
    #expect(draft.personaId == "persona-a")
    #expect(draft.directiveId == "directive-a")
    #expect(draft.kitOverrides.isEmpty)
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
          skills: [],
          intents: [],
          essentials: []
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
      originalSessionID: "session-old"
    )

    #expect(savedSessionID == "session-a")
  }

  @Test
  func deleteSessionForwardsToSessionManager() async throws {
    let workspaceURL = URL(fileURLWithPath: "/Workspace/../Workspace")

    let store = WorkspaceStore(
      snapshotBuilder: WorkspaceStoreStubSnapshotBuilder { _ in
        WorkspaceSnapshot.empty
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
      skills: [],
      intents: [],
      essentials: []
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
      skills: [],
      intents: [],
      essentials: []
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
      skills: [],
      intents: [],
      essentials: []
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
  func refreshWorkspaceRelationshipMapLoadsMap() async {
    let workspaceURL = URL(fileURLWithPath: "/Workspace")

    let store = WorkspaceStore(
      snapshotBuilder: WorkspaceStoreStubSnapshotBuilder { _ in
        WorkspaceSnapshot.empty
      },
      workspaceValidator: WorkspaceStoreStubWorkspaceValidator { _ in
        WorkspaceValidationSnapshot(summary: "ok", issues: [])
      },
      workspaceRelationshipMapBuilder: WorkspaceStoreStubWorkspaceRelationshipMapBuilder(
        buildHandler: { workspaceURL in
          #expect(workspaceURL.path() == "/Workspace")
          return makeWorkspaceRelationshipMap(personaID: "persona-a")
        }
      )
    )

    store.workspaceURL = workspaceURL
    store.loadWorkspace()
    store.refreshWorkspaceRelationshipMap()

    await waitFor {
      store.workspaceRelationshipMap?.nodes.contains(where: { $0.key == "persona:persona-a" }) == true
        && !store.isLoadingWorkspaceRelationshipMap
    }

    #expect(store.workspaceRelationshipMapErrorMessage == nil)
  }

  @Test
  func refreshWorkspaceRelationshipMapIgnoresStaleResultAfterWorkspaceIsCleared() async {
    let workspaceURL = URL(fileURLWithPath: "/Workspace")
    let relationshipGate = BlockingCallGate()

    let store = WorkspaceStore(
      snapshotBuilder: WorkspaceStoreStubSnapshotBuilder { _ in
        WorkspaceSnapshot.empty
      },
      workspaceValidator: WorkspaceStoreStubWorkspaceValidator { _ in
        WorkspaceValidationSnapshot(summary: "ok", issues: [])
      },
      workspaceRelationshipMapBuilder: WorkspaceStoreStubWorkspaceRelationshipMapBuilder(
        buildHandler: { _ in
          _ = relationshipGate.markStarted()
          relationshipGate.waitUntilReleased()
          relationshipGate.markFinished()
          return makeWorkspaceRelationshipMap(personaID: "persona-a")
        }
      )
    )

    store.workspaceURL = workspaceURL
    store.loadWorkspace()

    store.refreshWorkspaceRelationshipMap()
    await waitFor {
      relationshipGate.hasStarted
    }

    store.workspaceURL = nil
    store.refreshWorkspaceRelationshipMap()

    #expect(store.workspaceRelationshipMap == nil)
    #expect(store.workspaceRelationshipMapErrorMessage == nil)
    #expect(!store.isLoadingWorkspaceRelationshipMap)

    relationshipGate.release()

    await waitFor {
      relationshipGate.hasFinished
    }
    await yieldTasks()

    #expect(store.workspaceRelationshipMap == nil)
    #expect(store.workspaceRelationshipMapErrorMessage == nil)
    #expect(!store.isLoadingWorkspaceRelationshipMap)
  }

  @Test
  func clearingWorkspaceClearsWorkspaceRelationshipMapState() async {
    let workspaceURL = URL(fileURLWithPath: "/Workspace")

    let store = WorkspaceStore(
      snapshotBuilder: WorkspaceStoreStubSnapshotBuilder { _ in
        WorkspaceSnapshot.empty
      },
      workspaceValidator: WorkspaceStoreStubWorkspaceValidator { _ in
        WorkspaceValidationSnapshot(summary: "ok", issues: [])
      },
      workspaceRelationshipMapBuilder: WorkspaceStoreStubWorkspaceRelationshipMapBuilder(
        buildHandler: { _ in
          makeWorkspaceRelationshipMap(personaID: "persona-a")
        }
      )
    )

    store.workspaceURL = workspaceURL
    store.loadWorkspace()
    store.refreshWorkspaceRelationshipMap()

    await waitFor {
      store.workspaceRelationshipMap?.nodes.contains(where: { $0.key == "persona:persona-a" }) == true
    }

    store.workspaceURL = nil

    #expect(store.workspaceRelationshipMap == nil)
    #expect(store.workspaceRelationshipMapErrorMessage == nil)
    #expect(!store.isLoadingWorkspaceRelationshipMap)
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
  func copySessionPreviewUsesInjectedPasteboardWriter() throws {
    let expectedPreview = "preview-to-copy"
    let store = WorkspaceStore(
      pasteboardWriter: WorkspaceStoreStubPasteboardWriter(
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
    let didExport = try await store.exportSessionPreviewWithSavePanel()

    #expect(didExport)
  }

  @Test
  func exportSessionPreviewReturnsFalseWhenDestinationPickerCancels() async throws {
    let store = WorkspaceStore(
      previewExportDestinationPicker: WorkspaceStoreStubPreviewExportDestinationPicker(
        destinationURL: nil
      )
    )

    store.sessionPreview = "preview-to-export"
    let didExport = try await store.exportSessionPreviewWithSavePanel()

    #expect(!didExport)
  }
}
