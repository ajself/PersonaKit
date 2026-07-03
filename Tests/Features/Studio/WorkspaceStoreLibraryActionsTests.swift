import ContextCore
import ContextWorkspaceCore
import Foundation
import StudioFoundation
import Testing

@testable import StudioFeatures

@MainActor
struct WorkspaceStoreLibraryActionsTests {
  @Test
  func createPersonaSavesDeterministicJSONAndReloadsWorkspace() async {
    let workspaceURL = URL(fileURLWithPath: "/Workspace")
    let state = MutableBooleanState(value: false)

    let store = WorkspaceStore(
      snapshotBuilder: WorkspaceStoreStubSnapshotBuilder { _ in
        if state.value {
          return WorkspaceSnapshot(
            sessions: [],
            personas: [
              WorkspaceListItem(
                id: "persona-new",
                displayName: "Persona New",
                fileURL: URL(fileURLWithPath: "/personas/persona-new.persona.json"),
                sourceScope: .project
              )
            ],
            directives: [],
            kits: [
              WorkspaceListItem(
                id: "kit-a",
                displayName: "Kit A",
                fileURL: URL(fileURLWithPath: "/kits/kit-a.kit.json"),
                sourceScope: .project
              )
            ],
            skills: [
              WorkspaceListItem(
                id: "skill-a",
                displayName: "Skill A",
                fileURL: URL(fileURLWithPath: "/skills/skill-a.skill.json"),
                sourceScope: .project
              )
            ],
            essentials: []
          )
        }

        return WorkspaceSnapshot(
          sessions: [],
          personas: [],
          directives: [],
          kits: [
            WorkspaceListItem(
              id: "kit-a",
              displayName: "Kit A",
              fileURL: URL(fileURLWithPath: "/kits/kit-a.kit.json"),
              sourceScope: .project
            )
          ],
          skills: [
            WorkspaceListItem(
              id: "skill-a",
              displayName: "Skill A",
              fileURL: URL(fileURLWithPath: "/skills/skill-a.skill.json"),
              sourceScope: .project
            )
          ],
          essentials: []
        )
      },
      workspaceValidator: WorkspaceStoreStubWorkspaceValidator { _ in
        WorkspaceValidationSnapshot(summary: "ok", issues: [])
      },
      libraryEntityManager: WorkspaceStoreStubLibraryEntityManager(
        loadRawJSONHandler: { _ in
          "{}"
        },
        validateRawJSONHandler: { _, _, _ in },
        saveRawJSONHandler: { workspaceURL, itemID, rawJSON, entityType in
          #expect(workspaceURL.path() == "/Workspace")
          #expect(itemID == "persona-new")
          #expect(entityType == .persona)
          #expect(rawJSON.contains("\"id\" : \"persona-new\""))
          #expect(rawJSON.contains("\"version\" : \"1.0\""))
          #expect(rawJSON.contains("\"defaultKitIds\" : [\n    \"kit-a\"\n  ]"))
          #expect(rawJSON.contains("\"allowedSkillIds\" : [\n    \"skill-a\"\n  ]"))
          state.value = true
        },
        copyGlobalItemToProjectHandler: { _, _, _ in }
      )
    )

    store.workspaceURL = workspaceURL
    store.loadWorkspace()

    await waitFor {
      store.snapshot.kits.count == 1
    }

    let saveError = await store.createPersona(
      draft: WorkspacePersonaDraft(
        id: "persona-new",
        name: "Persona New",
        summary: "Summary",
        responsibilities: ["Build features"],
        values: ["clarity"],
        nonGoals: ["scope creep"],
        defaultKitIds: ["kit-a"],
        allowedSkillIds: ["skill-a"],
        forbiddenSkillIds: []
      )
    )

    #expect(saveError == nil)

    await waitFor {
      store.snapshot.personas.contains(where: { item in
        item.id == "persona-new"
      })
    }

    #expect(store.libraryActionMessage == "Created persona-new.")
    #expect(!store.libraryActionIsError)
  }

  @Test
  func saveNewLibraryEditorRawJSONUsesEnteredIDAndReloadsWorkspace() async {
    let workspaceURL = URL(fileURLWithPath: "/Workspace")
    let state = MutableBooleanState(value: false)

    let store = WorkspaceStore(
      snapshotBuilder: WorkspaceStoreStubSnapshotBuilder { _ in
        WorkspaceSnapshot(
          sessions: [],
          personas: [],
          directives: [],
          kits: state.value
            ? [
              WorkspaceListItem(
                id: "kit-new",
                displayName: "Kit New",
                fileURL: URL(fileURLWithPath: "/kits/kit-new.kit.json"),
                sourceScope: .project
              )
            ]
            : [],
          skills: [],
          essentials: []
        )
      },
      workspaceValidator: WorkspaceStoreStubWorkspaceValidator { _ in
        WorkspaceValidationSnapshot(summary: "ok", issues: [])
      },
      libraryEntityManager: WorkspaceStoreStubLibraryEntityManager(
        loadRawJSONHandler: { _ in "{}" },
        validateRawJSONHandler: { _, _, _ in },
        saveRawJSONHandler: { workspaceURL, itemID, rawJSON, entityType in
          #expect(workspaceURL.path() == "/Workspace")
          #expect(itemID == "kit-new")
          #expect(entityType == .kit)
          #expect(rawJSON.contains("\"id\" : \"kit-new\""))
          state.value = true
        },
        copyGlobalItemToProjectHandler: { _, _, _ in }
      )
    )

    store.workspaceURL = workspaceURL
    store.loadWorkspace()

    await waitFor {
      store.snapshot.kits.isEmpty
    }

    let presentation = store.newLibraryEditorPresentation(entityType: .kit)
    #expect(presentation?.isCreatingNewItem == true)

    let saveError = await store.saveLibraryEditorRawJSON(
      """
      {
        "essentialIds" : [],
        "id" : "kit-new",
        "name" : "Kit New",
        "summary" : "Summary",
        "version" : "1.0"
      }
      """,
      presentation: presentation!
    )

    #expect(saveError == nil)

    await waitFor {
      store.snapshot.kits.contains { item in
        item.id == "kit-new"
      }
    }

    #expect(store.libraryActionMessage == "Created kit-new.")
    #expect(!store.libraryActionIsError)
  }

  @Test
  func saveNewLibraryEditorRawJSONRejectsMissingSummaryBeforeSave() async {
    let store = WorkspaceStore(
      snapshotBuilder: WorkspaceStoreStubSnapshotBuilder { _ in
        WorkspaceSnapshot.empty
      },
      workspaceValidator: WorkspaceStoreStubWorkspaceValidator { _ in
        WorkspaceValidationSnapshot(summary: "ok", issues: [])
      },
      libraryEntityManager: WorkspaceStoreStubLibraryEntityManager(
        loadRawJSONHandler: { _ in "{}" },
        validateRawJSONHandler: { _, _, _ in },
        saveRawJSONHandler: { _, _, _, _ in
          Issue.record("saveRawJSON should not run when required create fields are empty.")
        },
        copyGlobalItemToProjectHandler: { _, _, _ in }
      )
    )

    store.workspaceURL = URL(fileURLWithPath: "/Workspace")
    let presentation = store.newLibraryEditorPresentation(entityType: .kit)

    let saveError = await store.saveLibraryEditorRawJSON(
      """
      {
        "essentialIds" : [],
        "id" : "kit-new",
        "name" : "Kit New",
        "summary" : "",
        "version" : "1.0"
      }
      """,
      presentation: presentation!
    )

    #expect(saveError == "Kit summary is required before saving.")
    #expect(store.libraryActionIsError)
  }

  @Test
  func saveNewLibraryEditorRawJSONRejectsMissingSecondaryFieldsBeforeSave() async {
    let validationCases: [(entityType: WorkspaceLibraryEntityType, rawJSON: String, expectedError: String)] = [
      (
        .directive,
        """
        {
          "acceptanceCriteria" : [],
          "goal" : "",
          "id" : "directive-new",
          "requiresSkillIds" : [],
          "steps" : [],
          "title" : "Directive New",
          "verification" : [],
          "version" : "1.0"
        }
        """,
        "Directive goal is required before saving."
      ),
      (
        .skill,
        """
        {
          "description" : "",
          "id" : "skill-new",
          "name" : "Skill New",
          "notes" : [],
          "providedBy" : [],
          "risk" : {
            "level" : "medium",
            "notes" : [],
            "requiresHumanReview" : false
          },
          "version" : "1.0"
        }
        """,
        "Skill description is required before saving."
      ),
    ]

    for validationCase in validationCases {
      let store = createValidationStore()
      store.workspaceURL = URL(fileURLWithPath: "/Workspace")
      let presentation = store.newLibraryEditorPresentation(entityType: validationCase.entityType)

      let saveError = await store.saveLibraryEditorRawJSON(
        validationCase.rawJSON,
        presentation: presentation!
      )

      #expect(saveError == validationCase.expectedError)
      #expect(store.libraryActionIsError)
    }
  }

  @Test
  func saveNewEssentialMarkdownUsesHeadingIDAndReloadsWorkspace() async {
    let workspaceURL = URL(fileURLWithPath: "/Workspace")
    let state = MutableBooleanState(value: false)

    let store = WorkspaceStore(
      snapshotBuilder: WorkspaceStoreStubSnapshotBuilder { _ in
        WorkspaceSnapshot(
          sessions: [],
          personas: [],
          directives: [],
          kits: [],
          skills: [],
          essentials: state.value
            ? [
              WorkspaceListItem(
                id: "team-standards",
                displayName: "team-standards",
                fileURL: URL(fileURLWithPath: "/essentials/team-standards.md"),
                sourceScope: .project
              )
            ]
            : []
        )
      },
      workspaceValidator: WorkspaceStoreStubWorkspaceValidator { _ in
        WorkspaceValidationSnapshot(summary: "ok", issues: [])
      },
      essentialManager: WorkspaceStoreStubEssentialManager(
        loadMarkdownHandler: { _ in "" },
        saveMarkdownHandler: { workspaceURL, itemID, markdown in
          #expect(workspaceURL.path() == "/Workspace")
          #expect(itemID == "team-standards")
          #expect(markdown.contains("# Team Standards"))
          state.value = true
        },
        copyGlobalEssentialToProjectHandler: { _, _ in }
      )
    )

    store.workspaceURL = workspaceURL
    store.loadWorkspace()

    await waitFor {
      store.snapshot.essentials.isEmpty
    }

    let presentation = store.newEssentialEditorPresentation()
    #expect(presentation?.isCreatingNewItem == true)

    let saveError = await store.saveEssentialEditorMarkdown(
      "# Team Standards\n\nKeep changes reviewable.\n",
      presentation: presentation!
    )

    #expect(saveError == nil)

    await waitFor {
      store.snapshot.essentials.contains { item in
        item.id == "team-standards"
      }
    }

    #expect(store.libraryActionMessage == "Created team-standards.")
    #expect(!store.libraryActionIsError)
  }

  @Test
  func createPersonaRejectsDuplicateIDBeforeSave() async {
    let workspaceURL = URL(fileURLWithPath: "/Workspace")

    let store = WorkspaceStore(
      snapshotBuilder: WorkspaceStoreStubSnapshotBuilder { _ in
        WorkspaceSnapshot(
          sessions: [],
          personas: [
            WorkspaceListItem(
              id: "persona-a",
              displayName: "Persona A",
              fileURL: URL(fileURLWithPath: "/personas/persona-a.persona.json"),
              sourceScope: .project
            )
          ],
          directives: [],
          kits: [],
          skills: [],
          essentials: []
        )
      },
      workspaceValidator: WorkspaceStoreStubWorkspaceValidator { _ in
        WorkspaceValidationSnapshot(summary: "ok", issues: [])
      },
      libraryEntityManager: WorkspaceStoreStubLibraryEntityManager(
        loadRawJSONHandler: { _ in
          "{}"
        },
        validateRawJSONHandler: { _, _, _ in },
        saveRawJSONHandler: { _, _, _, _ in
          Issue.record("saveRawJSON should not run for duplicate persona ids.")
        },
        copyGlobalItemToProjectHandler: { _, _, _ in }
      )
    )

    store.workspaceURL = workspaceURL
    store.loadWorkspace()

    await waitFor {
      store.snapshot.personas.count == 1
    }

    let saveError = await store.createPersona(
      draft: WorkspacePersonaDraft(
        id: "persona-a",
        name: "Persona A",
        summary: "Summary",
        responsibilities: [],
        values: [],
        nonGoals: [],
        defaultKitIds: [],
        allowedSkillIds: [],
        forbiddenSkillIds: []
      )
    )

    #expect(saveError?.contains("already exists") == true)
    #expect(store.libraryActionIsError)
  }

  @Test
  func createPersonaRejectsInvalidIDBeforeSave() async {
    let workspaceURL = URL(fileURLWithPath: "/Workspace")

    let store = WorkspaceStore(
      snapshotBuilder: WorkspaceStoreStubSnapshotBuilder { _ in
        WorkspaceSnapshot.empty
      },
      workspaceValidator: WorkspaceStoreStubWorkspaceValidator { _ in
        WorkspaceValidationSnapshot(summary: "ok", issues: [])
      },
      libraryEntityManager: WorkspaceStoreStubLibraryEntityManager(
        loadRawJSONHandler: { _ in
          "{}"
        },
        validateRawJSONHandler: { _, _, _ in },
        saveRawJSONHandler: { _, _, _, _ in
          Issue.record("saveRawJSON should not run for invalid persona ids.")
        },
        copyGlobalItemToProjectHandler: { _, _, _ in }
      )
    )

    store.workspaceURL = workspaceURL
    store.loadWorkspace()

    let saveError = await store.createPersona(
      draft: WorkspacePersonaDraft(
        id: "../persona-a",
        name: "Persona A",
        summary: "Summary",
        responsibilities: [],
        values: [],
        nonGoals: [],
        defaultKitIds: [],
        allowedSkillIds: [],
        forbiddenSkillIds: []
      )
    )

    #expect(saveError?.contains("not valid") == true)
    #expect(store.libraryActionIsError)
  }

  @Test
  func staleCreatePersonaResultIsIgnoredAfterWorkspaceReload() async {
    let firstWorkspaceURL = URL(fileURLWithPath: "/WorkspaceA")
    let secondWorkspaceURL = URL(fileURLWithPath: "/WorkspaceB")
    let saveGate = BlockingCallGate()

    let store = WorkspaceStore(
      snapshotBuilder: WorkspaceStoreStubSnapshotBuilder { _ in
        WorkspaceSnapshot.empty
      },
      workspaceValidator: WorkspaceStoreStubWorkspaceValidator { _ in
        WorkspaceValidationSnapshot(summary: "ok", issues: [])
      },
      libraryEntityManager: WorkspaceStoreStubLibraryEntityManager(
        loadRawJSONHandler: { _ in
          "{}"
        },
        validateRawJSONHandler: { _, _, _ in },
        saveRawJSONHandler: { workspaceURL, _, _, _ in
          if workspaceURL.standardizedFileURL == firstWorkspaceURL.standardizedFileURL {
            _ = saveGate.markStarted()
            saveGate.waitUntilReleased()
            saveGate.markFinished()
          }
        },
        copyGlobalItemToProjectHandler: { _, _, _ in }
      )
    )

    store.workspaceURL = firstWorkspaceURL
    store.loadWorkspace()

    let saveTask = Task {
      await store.createPersona(
        draft: WorkspacePersonaDraft(
          id: "persona-new",
          name: "Persona New",
          summary: "Summary",
          responsibilities: [],
          values: [],
          nonGoals: [],
          defaultKitIds: [],
          allowedSkillIds: [],
          forbiddenSkillIds: []
        )
      )
    }

    await waitFor {
      saveGate.hasStarted
    }

    store.workspaceURL = secondWorkspaceURL
    store.loadWorkspace()

    saveGate.release()

    let saveResult = await saveTask.value

    #expect(saveResult == nil)
    #expect(store.libraryActionMessage == nil)
    #expect(!store.isLoadingLibraryEditor)
    #expect(store.workspaceURL?.standardizedFileURL == secondWorkspaceURL.standardizedFileURL)
  }

  @Test
  func newerLibraryEditorLoadResultWinsWhenRequestsOverlap() async {
    let workspaceURL = URL(fileURLWithPath: "/Workspace")
    let loadGate = BlockingCallGate()
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
      snapshotBuilder: WorkspaceStoreStubSnapshotBuilder { _ in
        WorkspaceSnapshot(
          sessions: [],
          personas: [
            firstItem,
            secondItem,
          ],
          directives: [],
          kits: [],
          skills: [],
          essentials: []
        )
      },
      workspaceValidator: WorkspaceStoreStubWorkspaceValidator { _ in
        WorkspaceValidationSnapshot(summary: "ok", issues: [])
      },
      libraryEntityManager: WorkspaceStoreStubLibraryEntityManager(
        loadRawJSONHandler: { fileURL in
          if fileURL.lastPathComponent == "persona-a.persona.json" {
            _ = loadGate.markStarted()
            loadGate.waitUntilReleased()
            loadGate.markFinished()

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

    await waitFor {
      loadGate.hasStarted
    }

    let secondTask = Task {
      await store.openLibraryEditor(
        selectedItem: secondItem,
        entityType: .persona
      )
    }

    await waitFor {
      store.libraryFeatureModel.state.requestID == 2
    }

    loadGate.release()

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
    let saveGate = BlockingCallGate()
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
      snapshotBuilder: WorkspaceStoreStubSnapshotBuilder { _ in
        WorkspaceSnapshot(
          sessions: [],
          personas: [projectItem],
          directives: [],
          kits: [],
          skills: [],
          essentials: []
        )
      },
      workspaceValidator: WorkspaceStoreStubWorkspaceValidator { _ in
        WorkspaceValidationSnapshot(summary: "ok", issues: [])
      },
      libraryEntityManager: WorkspaceStoreStubLibraryEntityManager(
        loadRawJSONHandler: { _ in
          #"{"id":"persona-a"}"#
        },
        validateRawJSONHandler: { _, _, _ in },
        saveRawJSONHandler: { workspaceURL, _, _, _ in
          if workspaceURL.standardizedFileURL == firstWorkspaceURL.standardizedFileURL {
            _ = saveGate.markStarted()
            saveGate.waitUntilReleased()
            saveGate.markFinished()
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

    await waitFor {
      saveGate.hasStarted
    }

    store.workspaceURL = secondWorkspaceURL
    store.loadWorkspace()

    saveGate.release()

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
      snapshotBuilder: WorkspaceStoreStubSnapshotBuilder { _ in
        WorkspaceSnapshot(
          sessions: [],
          personas: [snapshotItem],
          directives: [],
          kits: [],
          skills: [],
          essentials: []
        )
      },
      workspaceValidator: WorkspaceStoreStubWorkspaceValidator { _ in
        WorkspaceValidationSnapshot(summary: "ok", issues: [])
      },
      libraryEntityManager: WorkspaceStoreStubLibraryEntityManager(
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
      snapshotBuilder: WorkspaceStoreStubSnapshotBuilder { _ in
        WorkspaceSnapshot(
          sessions: [],
          personas: [snapshotItem],
          directives: [],
          kits: [],
          skills: [],
          essentials: []
        )
      },
      workspaceValidator: WorkspaceStoreStubWorkspaceValidator { _ in
        WorkspaceValidationSnapshot(summary: "ok", issues: [])
      },
      libraryEntityManager: WorkspaceStoreStubLibraryEntityManager(
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
  func copySelectedGlobalLibraryItemForwardsStandardizedWorkspaceURL() async {
    let workspaceURL = URL(fileURLWithPath: "/Workspace/../Workspace")
    let globalItem = WorkspaceListItem(
      id: "persona-a",
      displayName: "Persona A",
      fileURL: URL(fileURLWithPath: "/GlobalRoot/Packs/personas/persona-a.persona.json"),
      sourceScope: .global
    )

    let store = WorkspaceStore(
      snapshotBuilder: WorkspaceStoreStubSnapshotBuilder { _ in
        WorkspaceSnapshot(
          sessions: [],
          personas: [globalItem],
          directives: [],
          kits: [],
          skills: [],
          essentials: []
        )
      },
      workspaceValidator: WorkspaceStoreStubWorkspaceValidator { _ in
        WorkspaceValidationSnapshot(summary: "ok", issues: [])
      },
      libraryEntityManager: WorkspaceStoreStubLibraryEntityManager(
        loadRawJSONHandler: { _ in
          #"{"id":"persona-a"}"#
        },
        validateRawJSONHandler: { _, _, _ in },
        saveRawJSONHandler: { _, _, _, _ in },
        copyGlobalItemToProjectHandler: { workspaceURL, item, entityType in
          #expect(workspaceURL.path() == "/Workspace")
          #expect(item.id == "persona-a")
          #expect(entityType == .persona)
        }
      )
    )

    store.workspaceURL = workspaceURL
    store.loadWorkspace()

    await waitFor {
      store.snapshot.personas.count == 1
    }

    let didCopy = await store.copySelectedGlobalLibraryItem(
      selectedItem: globalItem,
      entityType: .persona
    )

    #expect(didCopy)
    #expect(!store.libraryActionIsError)
    #expect(store.libraryActionMessage?.contains("Copied persona-a to project scope.") == true)
  }

  @Test
  func workspaceSwitchClearsPriorLibraryActionMessage() async {
    let firstWorkspaceURL = URL(fileURLWithPath: "/WorkspaceA")
    let secondWorkspaceURL = URL(fileURLWithPath: "/WorkspaceB")
    let globalItem = WorkspaceListItem(
      id: "persona-a",
      displayName: "Persona A",
      fileURL: URL(fileURLWithPath: "/GlobalRoot/Packs/personas/persona-a.persona.json"),
      sourceScope: .global
    )

    let store = WorkspaceStore(
      snapshotBuilder: WorkspaceStoreStubSnapshotBuilder { workspaceURL in
        if workspaceURL.standardizedFileURL == firstWorkspaceURL.standardizedFileURL {
          return WorkspaceSnapshot(
            sessions: [],
            personas: [globalItem],
            directives: [],
            kits: [],
            skills: [],
            essentials: []
          )
        }

        return WorkspaceSnapshot.empty
      },
      workspaceValidator: WorkspaceStoreStubWorkspaceValidator { _ in
        WorkspaceValidationSnapshot(summary: "ok", issues: [])
      },
      libraryEntityManager: WorkspaceStoreStubLibraryEntityManager(
        loadRawJSONHandler: { _ in
          #"{"id":"persona-a"}"#
        },
        validateRawJSONHandler: { _, _, _ in },
        saveRawJSONHandler: { _, _, _, _ in },
        copyGlobalItemToProjectHandler: { _, _, _ in }
      )
    )

    store.workspaceURL = firstWorkspaceURL
    store.loadWorkspace()

    await waitFor {
      store.snapshot.personas.count == 1
    }

    let didCopy = await store.copySelectedGlobalLibraryItem(
      selectedItem: globalItem,
      entityType: .persona
    )

    #expect(didCopy)
    #expect(store.libraryActionMessage?.contains("Copied persona-a to project scope.") == true)

    store.workspaceURL = secondWorkspaceURL
    store.loadWorkspace()

    await waitFor {
      store.snapshot == .empty
    }

    #expect(store.libraryActionMessage == nil)
    #expect(!store.libraryActionIsError)
  }

  @Test
  func clearingWorkspaceClearsPriorLibraryActionMessage() async {
    let workspaceURL = URL(fileURLWithPath: "/Workspace")
    let globalItem = WorkspaceListItem(
      id: "persona-a",
      displayName: "Persona A",
      fileURL: URL(fileURLWithPath: "/GlobalRoot/Packs/personas/persona-a.persona.json"),
      sourceScope: .global
    )

    let store = WorkspaceStore(
      snapshotBuilder: WorkspaceStoreStubSnapshotBuilder { _ in
        WorkspaceSnapshot(
          sessions: [],
          personas: [globalItem],
          directives: [],
          kits: [],
          skills: [],
          essentials: []
        )
      },
      workspaceValidator: WorkspaceStoreStubWorkspaceValidator { _ in
        WorkspaceValidationSnapshot(summary: "ok", issues: [])
      },
      libraryEntityManager: WorkspaceStoreStubLibraryEntityManager(
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

    let didCopy = await store.copySelectedGlobalLibraryItem(
      selectedItem: globalItem,
      entityType: .persona
    )

    #expect(didCopy)
    #expect(store.libraryActionMessage?.contains("Copied persona-a to project scope.") == true)

    store.workspaceURL = nil

    #expect(store.libraryActionMessage == nil)
    #expect(!store.libraryActionIsError)
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
      snapshotBuilder: WorkspaceStoreStubSnapshotBuilder { _ in
        WorkspaceSnapshot(
          sessions: [],
          personas: [projectItem],
          directives: [],
          kits: [],
          skills: [],
          essentials: []
        )
      },
      workspaceValidator: WorkspaceStoreStubWorkspaceValidator { _ in
        WorkspaceValidationSnapshot(summary: "ok", issues: [])
      },
      libraryEntityManager: WorkspaceStoreStubLibraryEntityManager(
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
  func copySelectedGlobalEssentialToProjectForwardsStandardizedWorkspaceURL() async {
    let workspaceURL = URL(fileURLWithPath: "/Workspace/../Workspace")
    let globalEssential = WorkspaceListItem(
      id: "essential-a",
      displayName: "Essential A",
      fileURL: URL(fileURLWithPath: "/GlobalRoot/Packs/essentials/essential-a.md"),
      sourceScope: .global
    )

    let store = WorkspaceStore(
      snapshotBuilder: WorkspaceStoreStubSnapshotBuilder { _ in
        WorkspaceSnapshot(
          sessions: [],
          personas: [],
          directives: [],
          kits: [],
          skills: [],
          essentials: [globalEssential]
        )
      },
      workspaceValidator: WorkspaceStoreStubWorkspaceValidator { _ in
        WorkspaceValidationSnapshot(summary: "ok", issues: [])
      },
      essentialManager: WorkspaceStoreStubEssentialManager(
        loadMarkdownHandler: { _ in
          "# Essential A\n"
        },
        saveMarkdownHandler: { _, _, _ in },
        copyGlobalEssentialToProjectHandler: { workspaceURL, item in
          #expect(workspaceURL.path() == "/Workspace")
          #expect(item.id == "essential-a")
        }
      )
    )

    store.workspaceURL = workspaceURL
    store.loadWorkspace()

    await waitFor {
      store.snapshot.essentials.count == 1
    }

    let didCopy = await store.copySelectedGlobalEssentialToProject(
      selectedItem: globalEssential
    )

    #expect(didCopy)
    #expect(!store.libraryActionIsError)
    #expect(store.libraryActionMessage?.contains("Copied essential-a to project scope.") == true)
  }

  @Test
  func copySelectedGlobalEssentialToProjectRejectsItemOutsideCurrentSnapshot() async {
    let workspaceURL = URL(fileURLWithPath: "/Workspace")
    let selectedItem = WorkspaceListItem(
      id: "essential-a",
      displayName: "Essential A",
      fileURL: URL(fileURLWithPath: "/OtherRoot/Packs/essentials/essential-a.md"),
      sourceScope: .global
    )
    let snapshotItem = WorkspaceListItem(
      id: "essential-a",
      displayName: "Essential A",
      fileURL: URL(fileURLWithPath: "/GlobalRoot/Packs/essentials/essential-a.md"),
      sourceScope: .global
    )

    let store = WorkspaceStore(
      snapshotBuilder: WorkspaceStoreStubSnapshotBuilder { _ in
        WorkspaceSnapshot(
          sessions: [],
          personas: [],
          directives: [],
          kits: [],
          skills: [],
          essentials: [snapshotItem]
        )
      },
      workspaceValidator: WorkspaceStoreStubWorkspaceValidator { _ in
        WorkspaceValidationSnapshot(summary: "ok", issues: [])
      },
      essentialManager: WorkspaceStoreStubEssentialManager(
        loadMarkdownHandler: { _ in
          "# Essential A\n"
        },
        saveMarkdownHandler: { _, _, _ in },
        copyGlobalEssentialToProjectHandler: { _, _ in
          Issue.record("copyGlobalEssentialToProject should not run when selected item is stale.")
        }
      )
    )

    store.workspaceURL = workspaceURL
    store.loadWorkspace()

    await waitFor {
      store.snapshot.essentials.count == 1
    }

    let didCopy = await store.copySelectedGlobalEssentialToProject(
      selectedItem: selectedItem
    )

    #expect(!didCopy)
    #expect(store.libraryActionIsError)
    #expect(store.libraryActionMessage?.contains("not a global essential") == true)
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
      snapshotBuilder: WorkspaceStoreStubSnapshotBuilder { _ in
        WorkspaceSnapshot(
          sessions: [],
          personas: [],
          directives: [],
          kits: [],
          skills: [],
          essentials: [projectEssential]
        )
      },
      workspaceValidator: WorkspaceStoreStubWorkspaceValidator { _ in
        WorkspaceValidationSnapshot(summary: "ok", issues: [])
      },
      essentialManager: WorkspaceStoreStubEssentialManager(
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
    let saveGate = BlockingCallGate()
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
      snapshotBuilder: WorkspaceStoreStubSnapshotBuilder { _ in
        WorkspaceSnapshot(
          sessions: [],
          personas: [],
          directives: [],
          kits: [],
          skills: [],
          essentials: [projectEssential]
        )
      },
      workspaceValidator: WorkspaceStoreStubWorkspaceValidator { _ in
        WorkspaceValidationSnapshot(summary: "ok", issues: [])
      },
      essentialManager: WorkspaceStoreStubEssentialManager(
        loadMarkdownHandler: { _ in
          "# Essential A\n"
        },
        saveMarkdownHandler: { workspaceURL, _, _ in
          if workspaceURL.standardizedFileURL == firstWorkspaceURL.standardizedFileURL {
            _ = saveGate.markStarted()
            saveGate.waitUntilReleased()
            saveGate.markFinished()
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

    await waitFor {
      saveGate.hasStarted
    }

    store.workspaceURL = secondWorkspaceURL
    store.loadWorkspace()

    saveGate.release()

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
      snapshotBuilder: WorkspaceStoreStubSnapshotBuilder { _ in
        WorkspaceSnapshot(
          sessions: [],
          personas: [],
          directives: [],
          kits: [],
          skills: [],
          essentials: [projectEssential]
        )
      },
      workspaceValidator: WorkspaceStoreStubWorkspaceValidator { _ in
        WorkspaceValidationSnapshot(summary: "ok", issues: [])
      },
      essentialManager: WorkspaceStoreStubEssentialManager(
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
      snapshotBuilder: WorkspaceStoreStubSnapshotBuilder { _ in
        WorkspaceSnapshot(
          sessions: [],
          personas: [],
          directives: [],
          kits: [],
          skills: [],
          essentials: [snapshotItem]
        )
      },
      workspaceValidator: WorkspaceStoreStubWorkspaceValidator { _ in
        WorkspaceValidationSnapshot(summary: "ok", issues: [])
      },
      essentialManager: WorkspaceStoreStubEssentialManager(
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

  private func createValidationStore() -> WorkspaceStore {
    WorkspaceStore(
      snapshotBuilder: WorkspaceStoreStubSnapshotBuilder { _ in
        WorkspaceSnapshot.empty
      },
      workspaceValidator: WorkspaceStoreStubWorkspaceValidator { _ in
        WorkspaceValidationSnapshot(summary: "ok", issues: [])
      },
      libraryEntityManager: WorkspaceStoreStubLibraryEntityManager(
        loadRawJSONHandler: { _ in "{}" },
        validateRawJSONHandler: { _, _, _ in },
        saveRawJSONHandler: { _, _, _, _ in
          Issue.record("saveRawJSON should not run when required create fields are empty.")
        },
        copyGlobalItemToProjectHandler: { _, _, _ in }
      )
    )
  }
}
