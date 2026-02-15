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

  @Test
  func validateWorkspaceAppendsSessionDiagnosticsIssues() async throws {
    let workspaceURL = try makeTempDirectory()
    let sessionFileURL = workspaceURL.appendingPathComponent(".personakit/Sessions/session-a.session.json")

    try FileManager.default.createDirectory(
      at: sessionFileURL.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try Data(
      """
      {
        "directiveId" : "directive-a",
        "id" : "session-a",
        "kitOverrides" : [
          "missing-kit"
        ],
        "personaId" : "persona-a"
      }
      """.utf8
    )
    .write(to: sessionFileURL, options: [.atomic])

    let snapshot = WorkspaceSnapshot(
      sessions: [
        WorkspaceSessionListItem(
          id: "session-a",
          personaId: "persona-a",
          directiveId: "directive-a",
          fileURL: sessionFileURL,
          sourceScope: .project
        )
      ],
      personas: [
        WorkspaceListItem(
          id: "persona-a",
          displayName: "Persona A",
          fileURL: URL(fileURLWithPath: "/unused/persona-a.persona.json"),
          sourceScope: .project
        )
      ],
      directives: [
        WorkspaceListItem(
          id: "directive-a",
          displayName: "Directive A",
          fileURL: URL(fileURLWithPath: "/unused/directive-a.directive.json"),
          sourceScope: .project
        )
      ],
      kits: [],
      skills: [],
      intents: [],
      essentials: []
    )
    let coreValidation = WorkspaceValidationSnapshot(
      summary: "core-summary",
      issues: [
        WorkspaceValidationIssue(
          entityType: .persona,
          entityId: "persona-a",
          field: "schema",
          filePath: nil,
          message: "Core issue",
          severity: .error
        )
      ]
    )
    let store = WorkspaceStore(
      snapshotBuilder: StubSnapshotBuilder { _ in
        snapshot
      },
      workspaceValidator: StubWorkspaceValidator { _ in
        coreValidation
      }
    )

    store.workspaceURL = workspaceURL
    store.loadWorkspace()

    await waitFor {
      store.validation.issues.count == 2
    }

    #expect(store.validation.summary == "core-summary")
    #expect(store.validation.issues[0].entityType == .persona)
    let hasSessionKitIssue = store.validation.issues.contains(where: { issue in
      issue.entityType == .session
        && issue.entityId == "session-a"
        && issue.field == "kitOverrides"
    })
    #expect(hasSessionKitIssue)
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
  func newerLibraryEditorLoadResultWinsWhenRequestsOverlap() async {
    let workspaceURL = URL(fileURLWithPath: "/Workspace")
    let firstItem = WorkspaceListItem(
      id: "persona-a",
      displayName: "Persona A",
      fileURL: URL(fileURLWithPath: "/personas/persona-a.persona.json"),
      sourceScope: .project
    )
    let secondItem = WorkspaceListItem(
      id: "persona-b",
      displayName: "Persona B",
      fileURL: URL(fileURLWithPath: "/personas/persona-b.persona.json"),
      sourceScope: .project
    )

    let store = WorkspaceStore(
      snapshotBuilder: StubSnapshotBuilder { _ in
        WorkspaceSnapshot(
          sessions: [],
          personas: [
            firstItem,
            secondItem,
          ],
          directives: [],
          kits: [],
          skills: [],
          intents: [],
          essentials: []
        )
      },
      workspaceValidator: StubWorkspaceValidator { _ in
        WorkspaceValidationSnapshot(summary: "ok", issues: [])
      },
      libraryEntityManager: StubLibraryEntityManager(
        loadRawJSONHandler: { fileURL in
          if fileURL.lastPathComponent == "persona-a.persona.json" {
            Thread.sleep(forTimeInterval: 0.3)
            return #"{"id":"persona-a"}"#
          }

          return #"{"id":"persona-b"}"#
        },
        validateRawJSONHandler: { _, _, _ in },
        saveRawJSONHandler: { _, _, _, _ in },
        copyGlobalItemToProjectHandler: { _, _, _ in }
      )
    )

    store.workspaceURL = workspaceURL
    store.loadWorkspace()

    await waitFor {
      store.snapshot.personas.count == 2
    }

    let firstTask = Task {
      await store.openLibraryEditor(
        selectedItem: firstItem,
        entityType: .persona
      )
    }
    try? await Task.sleep(for: .milliseconds(20))

    let secondTask = Task {
      await store.openLibraryEditor(
        selectedItem: secondItem,
        entityType: .persona
      )
    }

    let secondResult = await secondTask.value
    #expect(secondResult?.itemID == "persona-b")
    #expect(secondResult?.rawJSON == #"{"id":"persona-b"}"#)

    let firstResult = await firstTask.value
    #expect(firstResult == nil)
    #expect(!store.isLoadingLibraryEditor)
  }

  @Test
  func staleLibrarySaveResultIsIgnoredAfterWorkspaceReload() async {
    let firstWorkspaceURL = URL(fileURLWithPath: "/WorkspaceA")
    let secondWorkspaceURL = URL(fileURLWithPath: "/WorkspaceB")
    let projectItem = WorkspaceListItem(
      id: "persona-a",
      displayName: "Persona A",
      fileURL: URL(fileURLWithPath: "/personas/persona-a.persona.json"),
      sourceScope: .project
    )
    let presentation = WorkspaceLibraryEditorPresentation(
      itemID: "persona-a",
      entityType: .persona,
      fileURL: projectItem.fileURL,
      rawJSON: #"{"id":"persona-a"}"#,
      workspaceURL: firstWorkspaceURL
    )

    let store = WorkspaceStore(
      snapshotBuilder: StubSnapshotBuilder { _ in
        WorkspaceSnapshot(
          sessions: [],
          personas: [projectItem],
          directives: [],
          kits: [],
          skills: [],
          intents: [],
          essentials: []
        )
      },
      workspaceValidator: StubWorkspaceValidator { _ in
        WorkspaceValidationSnapshot(summary: "ok", issues: [])
      },
      libraryEntityManager: StubLibraryEntityManager(
        loadRawJSONHandler: { _ in
          #"{"id":"persona-a"}"#
        },
        validateRawJSONHandler: { _, _, _ in },
        saveRawJSONHandler: { workspaceURL, _, _, _ in
          if workspaceURL.standardizedFileURL == firstWorkspaceURL.standardizedFileURL {
            Thread.sleep(forTimeInterval: 0.3)
          }
        },
        copyGlobalItemToProjectHandler: { _, _, _ in }
      )
    )

    store.workspaceURL = firstWorkspaceURL
    store.loadWorkspace()

    await waitFor {
      store.snapshot.personas.count == 1
    }

    let saveTask = Task {
      await store.saveLibraryEditorRawJSON(
        presentation.rawJSON,
        presentation: presentation
      )
    }

    try? await Task.sleep(for: .milliseconds(20))

    store.workspaceURL = secondWorkspaceURL
    store.loadWorkspace()

    let saveResult = await saveTask.value

    #expect(saveResult == nil)
    #expect(store.libraryActionMessage == nil)
    #expect(!store.isLoadingLibraryEditor)
    #expect(store.workspaceURL?.standardizedFileURL == secondWorkspaceURL.standardizedFileURL)
  }

  @Test
  func openLibraryEditorRejectsItemOutsideCurrentSnapshot() async {
    let workspaceURL = URL(fileURLWithPath: "/Workspace")
    let selectedItem = WorkspaceListItem(
      id: "persona-a",
      displayName: "Persona A",
      fileURL: URL(fileURLWithPath: "/OtherRoot/Packs/personas/persona-a.persona.json"),
      sourceScope: .project
    )
    let snapshotItem = WorkspaceListItem(
      id: "persona-a",
      displayName: "Persona A",
      fileURL: URL(fileURLWithPath: "/Workspace/.personakit/Packs/personas/persona-a.persona.json"),
      sourceScope: .project
    )

    let store = WorkspaceStore(
      snapshotBuilder: StubSnapshotBuilder { _ in
        WorkspaceSnapshot(
          sessions: [],
          personas: [snapshotItem],
          directives: [],
          kits: [],
          skills: [],
          intents: [],
          essentials: []
        )
      },
      workspaceValidator: StubWorkspaceValidator { _ in
        WorkspaceValidationSnapshot(summary: "ok", issues: [])
      },
      libraryEntityManager: StubLibraryEntityManager(
        loadRawJSONHandler: { _ in
          #"{"id":"persona-a"}"#
        },
        validateRawJSONHandler: { _, _, _ in },
        saveRawJSONHandler: { _, _, _, _ in },
        copyGlobalItemToProjectHandler: { _, _, _ in }
      )
    )

    store.workspaceURL = workspaceURL
    store.loadWorkspace()

    await waitFor {
      store.snapshot.personas.count == 1
    }

    let presentation = await store.openLibraryEditor(
      selectedItem: selectedItem,
      entityType: .persona
    )

    #expect(presentation == nil)
    #expect(store.libraryActionIsError)
    #expect(store.libraryActionMessage?.contains("not a project library entity") == true)
  }

  @Test
  func copySelectedGlobalLibraryItemRejectsItemOutsideCurrentSnapshot() async {
    let workspaceURL = URL(fileURLWithPath: "/Workspace")
    let selectedItem = WorkspaceListItem(
      id: "persona-a",
      displayName: "Persona A",
      fileURL: URL(fileURLWithPath: "/OtherRoot/Packs/personas/persona-a.persona.json"),
      sourceScope: .global
    )
    let snapshotItem = WorkspaceListItem(
      id: "persona-a",
      displayName: "Persona A",
      fileURL: URL(fileURLWithPath: "/GlobalRoot/Packs/personas/persona-a.persona.json"),
      sourceScope: .global
    )

    let store = WorkspaceStore(
      snapshotBuilder: StubSnapshotBuilder { _ in
        WorkspaceSnapshot(
          sessions: [],
          personas: [snapshotItem],
          directives: [],
          kits: [],
          skills: [],
          intents: [],
          essentials: []
        )
      },
      workspaceValidator: StubWorkspaceValidator { _ in
        WorkspaceValidationSnapshot(summary: "ok", issues: [])
      },
      libraryEntityManager: StubLibraryEntityManager(
        loadRawJSONHandler: { _ in
          #"{"id":"persona-a"}"#
        },
        validateRawJSONHandler: { _, _, _ in },
        saveRawJSONHandler: { _, _, _, _ in },
        copyGlobalItemToProjectHandler: { _, _, _ in
          Issue.record("copyGlobalItemToProject should not run when selected item is stale.")
        }
      )
    )

    store.workspaceURL = workspaceURL
    store.loadWorkspace()

    await waitFor {
      store.snapshot.personas.count == 1
    }

    let didCopy = await store.copySelectedGlobalLibraryItem(
      selectedItem: selectedItem,
      entityType: .persona
    )

    #expect(!didCopy)
    #expect(store.libraryActionIsError)
    #expect(store.libraryActionMessage?.contains("not a global library entity") == true)
  }

  @Test
  func saveLibraryEditorRawJSONRejectsWorkspaceMismatch() async {
    let firstWorkspaceURL = URL(fileURLWithPath: "/WorkspaceA")
    let secondWorkspaceURL = URL(fileURLWithPath: "/WorkspaceB")
    let projectItem = WorkspaceListItem(
      id: "persona-a",
      displayName: "Persona A",
      fileURL: URL(fileURLWithPath: "/personas/persona-a.persona.json"),
      sourceScope: .project
    )
    let presentation = WorkspaceLibraryEditorPresentation(
      itemID: "persona-a",
      entityType: .persona,
      fileURL: projectItem.fileURL,
      rawJSON: #"{"id":"persona-a"}"#,
      workspaceURL: firstWorkspaceURL
    )

    let store = WorkspaceStore(
      snapshotBuilder: StubSnapshotBuilder { _ in
        WorkspaceSnapshot(
          sessions: [],
          personas: [projectItem],
          directives: [],
          kits: [],
          skills: [],
          intents: [],
          essentials: []
        )
      },
      workspaceValidator: StubWorkspaceValidator { _ in
        WorkspaceValidationSnapshot(summary: "ok", issues: [])
      },
      libraryEntityManager: StubLibraryEntityManager(
        loadRawJSONHandler: { _ in
          #"{"id":"persona-a"}"#
        },
        validateRawJSONHandler: { _, _, _ in },
        saveRawJSONHandler: { _, _, _, _ in
          Issue.record("saveRawJSON should not run for stale workspace presentation.")
        },
        copyGlobalItemToProjectHandler: { _, _, _ in }
      )
    )

    store.workspaceURL = secondWorkspaceURL
    store.loadWorkspace()

    await waitFor {
      store.snapshot.personas.count == 1
    }

    let saveError = await store.saveLibraryEditorRawJSON(
      presentation.rawJSON,
      presentation: presentation
    )

    #expect(saveError?.contains("Workspace changed while this editor was open") == true)
    #expect(store.libraryActionIsError)
  }

  @Test
  func openEssentialEditorLoadsMarkdownForProjectItem() async {
    let workspaceURL = URL(fileURLWithPath: "/Workspace")
    let projectEssential = WorkspaceListItem(
      id: "essential-a",
      displayName: "Essential A",
      fileURL: URL(fileURLWithPath: "/essentials/essential-a.md"),
      sourceScope: .project
    )

    let store = WorkspaceStore(
      snapshotBuilder: StubSnapshotBuilder { _ in
        WorkspaceSnapshot(
          sessions: [],
          personas: [],
          directives: [],
          kits: [],
          skills: [],
          intents: [],
          essentials: [projectEssential]
        )
      },
      workspaceValidator: StubWorkspaceValidator { _ in
        WorkspaceValidationSnapshot(summary: "ok", issues: [])
      },
      essentialManager: StubEssentialManager(
        loadMarkdownHandler: { _ in
          "# Essential A\n"
        },
        saveMarkdownHandler: { _, _, _ in },
        copyGlobalEssentialToProjectHandler: { _, _ in }
      )
    )

    store.workspaceURL = workspaceURL
    store.loadWorkspace()

    await waitFor {
      store.snapshot.essentials.count == 1
    }

    let presentation = await store.openEssentialEditor(
      selectedItem: projectEssential
    )

    #expect(presentation?.itemID == "essential-a")
    #expect(presentation?.markdown == "# Essential A\n")
  }

  @Test
  func staleEssentialSaveResultIsIgnoredAfterWorkspaceReload() async {
    let firstWorkspaceURL = URL(fileURLWithPath: "/WorkspaceA")
    let secondWorkspaceURL = URL(fileURLWithPath: "/WorkspaceB")
    let projectEssential = WorkspaceListItem(
      id: "essential-a",
      displayName: "Essential A",
      fileURL: URL(fileURLWithPath: "/essentials/essential-a.md"),
      sourceScope: .project
    )
    let presentation = WorkspaceEssentialEditorPresentation(
      fileURL: projectEssential.fileURL,
      itemID: "essential-a",
      markdown: "# Essential A\n",
      workspaceURL: firstWorkspaceURL
    )

    let store = WorkspaceStore(
      snapshotBuilder: StubSnapshotBuilder { _ in
        WorkspaceSnapshot(
          sessions: [],
          personas: [],
          directives: [],
          kits: [],
          skills: [],
          intents: [],
          essentials: [projectEssential]
        )
      },
      workspaceValidator: StubWorkspaceValidator { _ in
        WorkspaceValidationSnapshot(summary: "ok", issues: [])
      },
      essentialManager: StubEssentialManager(
        loadMarkdownHandler: { _ in
          "# Essential A\n"
        },
        saveMarkdownHandler: { workspaceURL, _, _ in
          if workspaceURL.standardizedFileURL == firstWorkspaceURL.standardizedFileURL {
            Thread.sleep(forTimeInterval: 0.3)
          }
        },
        copyGlobalEssentialToProjectHandler: { _, _ in }
      )
    )

    store.workspaceURL = firstWorkspaceURL
    store.loadWorkspace()

    await waitFor {
      store.snapshot.essentials.count == 1
    }

    let saveTask = Task {
      await store.saveEssentialEditorMarkdown(
        "# Updated\n",
        presentation: presentation
      )
    }

    try? await Task.sleep(for: .milliseconds(20))

    store.workspaceURL = secondWorkspaceURL
    store.loadWorkspace()

    let saveResult = await saveTask.value

    #expect(saveResult == nil)
    #expect(store.libraryActionMessage == nil)
    #expect(!store.isLoadingLibraryEditor)
    #expect(store.workspaceURL?.standardizedFileURL == secondWorkspaceURL.standardizedFileURL)
  }

  @Test
  func saveEssentialEditorMarkdownRejectsWorkspaceMismatch() async {
    let firstWorkspaceURL = URL(fileURLWithPath: "/WorkspaceA")
    let secondWorkspaceURL = URL(fileURLWithPath: "/WorkspaceB")
    let projectEssential = WorkspaceListItem(
      id: "essential-a",
      displayName: "Essential A",
      fileURL: URL(fileURLWithPath: "/essentials/essential-a.md"),
      sourceScope: .project
    )
    let presentation = WorkspaceEssentialEditorPresentation(
      fileURL: projectEssential.fileURL,
      itemID: "essential-a",
      markdown: "# Essential A\n",
      workspaceURL: firstWorkspaceURL
    )

    let store = WorkspaceStore(
      snapshotBuilder: StubSnapshotBuilder { _ in
        WorkspaceSnapshot(
          sessions: [],
          personas: [],
          directives: [],
          kits: [],
          skills: [],
          intents: [],
          essentials: [projectEssential]
        )
      },
      workspaceValidator: StubWorkspaceValidator { _ in
        WorkspaceValidationSnapshot(summary: "ok", issues: [])
      },
      essentialManager: StubEssentialManager(
        loadMarkdownHandler: { _ in
          "# Essential A\n"
        },
        saveMarkdownHandler: { _, _, _ in
          Issue.record("saveMarkdown should not run for stale workspace presentation.")
        },
        copyGlobalEssentialToProjectHandler: { _, _ in }
      )
    )

    store.workspaceURL = secondWorkspaceURL
    store.loadWorkspace()

    await waitFor {
      store.snapshot.essentials.count == 1
    }

    let saveError = await store.saveEssentialEditorMarkdown(
      "# Updated\n",
      presentation: presentation
    )

    #expect(saveError?.contains("Workspace changed while this editor was open") == true)
    #expect(store.libraryActionIsError)
  }

  @Test
  func openEssentialEditorRejectsItemOutsideCurrentSnapshot() async {
    let workspaceURL = URL(fileURLWithPath: "/Workspace")
    let selectedItem = WorkspaceListItem(
      id: "essential-a",
      displayName: "Essential A",
      fileURL: URL(fileURLWithPath: "/OtherRoot/Packs/essentials/essential-a.md"),
      sourceScope: .project
    )
    let snapshotItem = WorkspaceListItem(
      id: "essential-a",
      displayName: "Essential A",
      fileURL: URL(fileURLWithPath: "/Workspace/.personakit/Packs/essentials/essential-a.md"),
      sourceScope: .project
    )

    let store = WorkspaceStore(
      snapshotBuilder: StubSnapshotBuilder { _ in
        WorkspaceSnapshot(
          sessions: [],
          personas: [],
          directives: [],
          kits: [],
          skills: [],
          intents: [],
          essentials: [snapshotItem]
        )
      },
      workspaceValidator: StubWorkspaceValidator { _ in
        WorkspaceValidationSnapshot(summary: "ok", issues: [])
      },
      essentialManager: StubEssentialManager(
        loadMarkdownHandler: { _ in
          "# Essential A\n"
        },
        saveMarkdownHandler: { _, _, _ in },
        copyGlobalEssentialToProjectHandler: { _, _ in }
      )
    )

    store.workspaceURL = workspaceURL
    store.loadWorkspace()

    await waitFor {
      store.snapshot.essentials.count == 1
    }

    let presentation = await store.openEssentialEditor(selectedItem: selectedItem)

    #expect(presentation == nil)
    #expect(store.libraryActionIsError)
    #expect(store.libraryActionMessage?.contains("not a project essential") == true)
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
  func initializeWorkspaceStructureCreatesFoldersAndReloadsWorkspace() async throws {
    let workspaceURL = URL(fileURLWithPath: "/Workspace")
    let state = WorkspaceInitializationState()

    let store = WorkspaceStore(
      snapshotBuilder: StubSnapshotBuilder { _ in
        if state.isInitialized {
          return WorkspaceSnapshot.empty
        }

        throw MissingPersonaKitDirectoryError(
          projectScopeURL: URL(fileURLWithPath: "/Workspace/.personakit")
        )
      },
      workspaceValidator: StubWorkspaceValidator { _ in
        WorkspaceValidationSnapshot(summary: "ok", issues: [])
      },
      workspaceInitializer: WorkspaceInitializer(
        dependencies: WorkspaceInitializerDependencies(
          createDirectory: { directoryURL in
            state.createdDirectories.append(directoryURL.standardizedFileURL)
            state.isInitialized = true
          }
        )
      )
    )

    store.workspaceURL = workspaceURL
    store.loadWorkspace()

    await waitFor {
      store.loadErrorMessage?.hasPrefix("Missing PersonaKit directory at ") == true
    }
    #expect(store.canInitializeWorkspaceStructure)

    store.initializeWorkspaceStructure()

    await waitFor {
      store.loadErrorMessage == nil
    }
    #expect(!store.canInitializeWorkspaceStructure)

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

    #expect(state.createdDirectories == expectedDirectories)
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

private final class WorkspaceInitializationState: @unchecked Sendable {
  var createdDirectories: [URL] = []
  var isInitialized = false
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
  let saveSessionHandler: @Sendable (
    URL,
    WorkspaceSessionDraft,
    String?,
    Set<String>,
    Set<String>,
    Set<String>
  ) throws -> String
  let deleteSessionHandler: @Sendable (URL, String) throws -> Void

  func loadDraft(fileURL: URL) throws -> WorkspaceSessionDraft {
    try loadDraftHandler(fileURL)
  }

  func saveSession(
    workspaceURL: URL,
    draft: WorkspaceSessionDraft,
    originalSessionID: String?,
    validPersonaIDs: Set<String>,
    validDirectiveIDs: Set<String>,
    validKitIDs: Set<String>
  ) throws -> String {
    try saveSessionHandler(
      workspaceURL,
      draft,
      originalSessionID,
      validPersonaIDs,
      validDirectiveIDs,
      validKitIDs
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

private struct StubLibraryEntityManager: WorkspaceLibraryEntityManaging, Sendable {
  let loadRawJSONHandler: @Sendable (URL) throws -> String
  let validateRawJSONHandler: @Sendable (String, WorkspaceLibraryEntityType, String) throws -> Void
  let saveRawJSONHandler: @Sendable (URL, String, String, WorkspaceLibraryEntityType) throws -> Void
  let copyGlobalItemToProjectHandler: @Sendable (URL, WorkspaceListItem, WorkspaceLibraryEntityType) throws -> Void

  func loadRawJSON(fileURL: URL) throws -> String {
    try loadRawJSONHandler(fileURL)
  }

  func validateRawJSON(
    _ rawJSON: String,
    entityType: WorkspaceLibraryEntityType,
    expectedID: String
  ) throws {
    try validateRawJSONHandler(rawJSON, entityType, expectedID)
  }

  func saveRawJSON(
    workspaceURL: URL,
    itemID: String,
    rawJSON: String,
    entityType: WorkspaceLibraryEntityType
  ) throws {
    try saveRawJSONHandler(workspaceURL, itemID, rawJSON, entityType)
  }

  func copyGlobalItemToProject(
    workspaceURL: URL,
    item: WorkspaceListItem,
    entityType: WorkspaceLibraryEntityType
  ) throws {
    try copyGlobalItemToProjectHandler(workspaceURL, item, entityType)
  }
}

private struct StubEssentialManager: WorkspaceEssentialManaging, Sendable {
  let loadMarkdownHandler: @Sendable (URL) throws -> String
  let saveMarkdownHandler: @Sendable (URL, String, String) throws -> Void
  let copyGlobalEssentialToProjectHandler: @Sendable (URL, WorkspaceListItem) throws -> Void

  func loadMarkdown(fileURL: URL) throws -> String {
    try loadMarkdownHandler(fileURL)
  }

  func saveMarkdown(
    workspaceURL: URL,
    itemID: String,
    markdown: String
  ) throws {
    try saveMarkdownHandler(workspaceURL, itemID, markdown)
  }

  func copyGlobalEssentialToProject(
    workspaceURL: URL,
    item: WorkspaceListItem
  ) throws {
    try copyGlobalEssentialToProjectHandler(workspaceURL, item)
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
