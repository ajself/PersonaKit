import ContextCore
import ContextWorkspaceCore
import Foundation
import Observation
import StudioFoundation
import Testing

@testable import StudioFeatures

/// Owner-held loads and what a reload may and may not disturb: the library detail draft,
/// the session preview, the session editor's draft load, and observation without the
/// retired revision counters.
@Suite(.serialized)
@MainActor
struct WorkspaceStoreReloadOwnershipTests {
  private let workspaceURL = URL(fileURLWithPath: "/Workspace")
  private let soloFileURL = URL(
    fileURLWithPath: "/Workspace/.personakit/Packs/personas/solo.persona.json"
  )
  private let otherFileURL = URL(
    fileURLWithPath: "/Workspace/.personakit/Packs/personas/other.persona.json"
  )

  // MARK: Library detail

  @Test
  func externalChangeKeepsUnsavedInlineEditsAndFlagsTheDiskChange() async throws {
    let disk = MutableTextState(#"{"id":"solo","name":"Solo","summary":"Original."}"#)
    let store = makeLibraryStore(disk: disk)
    let item = try await loadSoloItem(store)

    store.selectLibraryDetailItem(item, entityType: .persona)
    await waitFor { store.libraryDetail.isDraftReady }

    store.updateLibraryDetailForm { $0.primaryText = "Mine" }
    disk.value = #"{"id":"solo","name":"Solo","summary":"Changed elsewhere."}"#
    store.reloadWorkspaceAfterExternalChange(changedFileURLs: [soloFileURL])

    await waitFor { store.libraryDetail.hasChangedOnDisk }

    #expect(store.libraryDetail.formState.primaryText == "Mine")
    #expect(store.libraryDetail.isDraftDirty)
    #expect(store.libraryDetail.sourceText.contains("Changed elsewhere."))
  }

  @Test
  func externalReloadThatSupersedesAnotherKeepsItsChangedFiles() async throws {
    let gate = BlockingCallGate()
    let disk = MutableTextState(#"{"id":"solo","name":"Solo","summary":"Original."}"#)
    let store = makeLibraryStore(disk: disk) { buildNumber in
      if buildNumber == 2 {
        _ = gate.markStarted()
        gate.waitUntilReleased()
      }
    }
    let item = try await loadSoloItem(store)

    store.selectLibraryDetailItem(item, entityType: .persona)
    await waitFor { store.libraryDetail.isDraftReady }

    store.updateLibraryDetailForm { $0.primaryText = "Mine" }
    disk.value = #"{"id":"solo","name":"Solo","summary":"Changed elsewhere."}"#
    store.reloadWorkspaceAfterExternalChange(changedFileURLs: [soloFileURL])
    await waitFor { gate.hasStarted }

    // A second batch that only touches another file replaces the stalled load.
    store.reloadWorkspaceAfterExternalChange(changedFileURLs: [otherFileURL])
    gate.release()

    await waitFor { store.libraryDetail.hasChangedOnDisk }

    #expect(store.libraryDetail.formState.primaryText == "Mine")
  }

  @Test
  func externalChangeWithACleanDraftShowsTheNewFile() async throws {
    let disk = MutableTextState(#"{"id":"solo","name":"Solo","summary":"Original."}"#)
    let store = makeLibraryStore(disk: disk)
    let item = try await loadSoloItem(store)

    store.selectLibraryDetailItem(item, entityType: .persona)
    await waitFor { store.libraryDetail.isDraftReady }

    disk.value = #"{"id":"solo","name":"Solo","summary":"Changed elsewhere."}"#
    store.reloadWorkspaceAfterExternalChange(changedFileURLs: [soloFileURL])

    await waitFor { store.libraryDetail.formState.secondaryText == "Changed elsewhere." }

    #expect(!store.libraryDetail.hasChangedOnDisk)
    #expect(!store.libraryDetail.isDraftDirty)
  }

  @Test
  func failedExternalReloadKeepsTheSnapshotAndUnsavedEdits() async throws {
    let disk = MutableTextState(#"{"id":"solo","name":"Solo","summary":"Original."}"#)
    let buildCount = CallCounter()
    let buildFails = MutableBooleanState(value: false)
    let store = makeLibraryStore(disk: disk, buildCount: buildCount, buildFails: buildFails)
    let item = try await loadSoloItem(store)

    store.selectLibraryDetailItem(item, entityType: .persona)
    await waitFor { store.libraryDetail.isDraftReady }
    store.updateLibraryDetailForm { $0.primaryText = "Mine" }

    // A file caught mid-write fails the whole snapshot.
    buildFails.value = true
    store.reloadWorkspaceAfterExternalChange(changedFileURLs: [otherFileURL])
    await waitFor { buildCount.count == 2 }
    await yieldTasks()

    #expect(store.loadErrorMessage == nil)
    #expect(store.snapshot.personas.count == 2)
    #expect(store.libraryDetail.formState.primaryText == "Mine")

    // The next change, once the file is whole again, reloads normally.
    buildFails.value = false
    disk.value = #"{"id":"solo","name":"Solo","summary":"Changed elsewhere."}"#
    store.reloadWorkspaceAfterExternalChange(changedFileURLs: [soloFileURL])

    await waitFor { store.libraryDetail.hasChangedOnDisk }
    #expect(store.libraryDetail.formState.primaryText == "Mine")
  }

  @Test
  func failedExternalReloadCarriesItsChangedFilesIntoTheNextReload() async throws {
    let disk = MutableTextState(#"{"id":"solo","name":"Solo","summary":"Original."}"#)
    let buildCount = CallCounter()
    let buildFails = MutableBooleanState(value: false)
    let store = makeLibraryStore(disk: disk, buildCount: buildCount, buildFails: buildFails)
    let item = try await loadSoloItem(store)

    store.selectLibraryDetailItem(item, entityType: .persona)
    await waitFor { store.libraryDetail.isDraftReady }
    store.updateLibraryDetailForm { $0.primaryText = "Mine" }

    // The open file changes in the same batch as a file caught mid-write.
    buildFails.value = true
    disk.value = #"{"id":"solo","name":"Solo","summary":"Changed elsewhere."}"#
    store.reloadWorkspaceAfterExternalChange(changedFileURLs: [soloFileURL, otherFileURL])
    await waitFor { buildCount.count == 2 }
    await yieldTasks()

    // Fixing the broken file reloads with only that file in the new batch.
    buildFails.value = false
    store.reloadWorkspaceAfterExternalChange(changedFileURLs: [otherFileURL])

    await waitFor { store.libraryDetail.hasChangedOnDisk }
    #expect(store.libraryDetail.formState.primaryText == "Mine")
  }

  @Test
  func changesToOtherFilesDoNotRereadTheDetailItem() async throws {
    let disk = MutableTextState(#"{"id":"solo","name":"Solo"}"#)
    let readCount = CallCounter()
    let buildCount = CallCounter()
    let store = makeLibraryStore(disk: disk, readCount: readCount, buildCount: buildCount)
    let item = try await loadSoloItem(store)

    store.selectLibraryDetailItem(item, entityType: .persona)
    await waitFor { store.libraryDetail.isDraftReady }
    #expect(readCount.count == 1)

    store.reloadWorkspaceAfterExternalChange(changedFileURLs: [otherFileURL])
    await waitFor { buildCount.count == 2 }
    await yieldTasks()

    #expect(readCount.count == 1)
  }

  @Test
  func selectingAnotherItemCancelsTheInFlightSourceLoad() async throws {
    let gate = BlockingCallGate()
    let soloFileURL = soloFileURL
    let store = makeLibraryStore(
      disk: MutableTextState(""),
      readHandler: { fileURL in
        if fileURL == soloFileURL {
          _ = gate.markStarted()
          gate.waitUntilReleased()
          return #"{"id":"solo","name":"Solo"}"#
        }

        return #"{"id":"other","name":"Other"}"#
      }
    )
    let items = try await loadItems(store)

    store.selectLibraryDetailItem(items[0], entityType: .persona)
    await waitFor { gate.hasStarted }

    store.selectLibraryDetailItem(items[1], entityType: .persona)
    gate.release()

    await waitFor { store.libraryDetail.formState.primaryText == "Other" }
    await yieldTasks()

    #expect(store.libraryDetail.item?.id == "other")
    #expect(store.libraryDetail.formState.primaryText == "Other")
  }

  @Test
  func validatingTheDraftReportsTheResultInline() async throws {
    let rejects = MutableBooleanState(value: false)
    let validated = MutableTextState("")
    let store = makeLibraryStore(
      disk: MutableTextState(#"{"id":"solo","name":"Solo","summary":"Original."}"#),
      validateHandler: { rawJSON in
        validated.value = rawJSON

        if rejects.value {
          throw WorkspaceSnapshotBuildError(message: "Persona name is too long.")
        }
      }
    )
    let item = try await loadSoloItem(store)

    store.selectLibraryDetailItem(item, entityType: .persona)
    await waitFor { store.libraryDetail.isDraftReady }

    store.updateLibraryDetailForm { $0.primaryText = "Mine" }
    store.validateLibraryDetailDraft()
    await waitFor { store.libraryFeatureModel.detailActionTask == nil }

    #expect(validated.value.contains("Mine"))
    #expect(store.libraryDetail.inlineMessage == "JSON is valid.")
    #expect(!store.libraryDetail.inlineMessageIsError)

    rejects.value = true
    store.validateLibraryDetailDraft()
    await waitFor { store.libraryFeatureModel.detailActionTask == nil }

    #expect(store.libraryDetail.inlineMessage == "Persona name is too long.")
    #expect(store.libraryDetail.inlineMessageIsError)
    #expect(!store.libraryDetail.isValidating)
  }

  @Test
  func savingTheDraftWritesItThenShowsTheNormalizedFile() async throws {
    let disk = MutableTextState(#"{"id":"solo","name":"Solo","summary":"Original."}"#)
    let saved = MutableTextState("")
    let buildFails = MutableBooleanState(value: false)
    let store = makeLibraryStore(
      disk: disk,
      buildFails: buildFails,
      saveHandler: { rawJSON in
        saved.value = rawJSON
        // The CLI normalizes what it writes; the detail pane must show the file, not the draft.
        disk.value = #"{"id":"solo","name":"Mine","summary":"Original.","version":"1.0"}"#
        // The reload the save triggers fails, so only the save's own re-read can show the file.
        buildFails.value = true
      }
    )
    let item = try await loadSoloItem(store)

    store.selectLibraryDetailItem(item, entityType: .persona)
    await waitFor { store.libraryDetail.isDraftReady }

    store.updateLibraryDetailForm { $0.primaryText = "Mine" }
    store.saveLibraryDetailDraft()

    await waitFor { store.libraryDetail.sourceText.contains("\"version\"") }

    #expect(saved.value.contains("Mine"))
    #expect(store.libraryDetail.inlineMessage == "Saved solo.")
    #expect(!store.libraryDetail.isSaving)
    #expect(!store.libraryDetail.isDraftDirty)
    #expect(!store.libraryDetail.hasChangedOnDisk)
    #expect(store.libraryDetail.formState.primaryText == "Mine")
  }

  @Test
  func savingDropsASourceReadThatStartedBeforeIt() async throws {
    let readGate = BlockingCallGate()
    let saveGate = BlockingCallGate()
    let holdsNextRead = MutableBooleanState(value: false)
    let disk = MutableTextState(#"{"id":"solo","name":"Solo","summary":"Original."}"#)
    let store = makeLibraryStore(
      disk: disk,
      readHandler: { _ in
        if holdsNextRead.value {
          holdsNextRead.value = false
          _ = readGate.markStarted()
          readGate.waitUntilReleased()
        }

        return disk.value
      },
      saveHandler: { rawJSON in
        _ = saveGate.markStarted()
        saveGate.waitUntilReleased()
        disk.value = rawJSON
      }
    )
    let item = try await loadSoloItem(store)

    store.selectLibraryDetailItem(item, entityType: .persona)
    await waitFor { store.libraryDetail.isDraftReady }
    let originalSource = store.libraryDetail.sourceText

    store.updateLibraryDetailForm { $0.primaryText = "Mine" }
    holdsNextRead.value = true
    disk.value = #"{"id":"solo","name":"Solo","summary":"Changed elsewhere."}"#
    store.reloadWorkspaceAfterExternalChange(changedFileURLs: [soloFileURL])
    await waitFor { readGate.hasStarted }

    store.saveLibraryDetailDraft()
    readGate.release()
    await waitFor { saveGate.hasStarted }
    await yieldTasks()

    // The read that began before the save must not land as a change on disk mid-save.
    #expect(store.libraryDetail.isSaving)
    #expect(store.libraryDetail.sourceText == originalSource)
    #expect(!store.libraryDetail.hasChangedOnDisk)

    saveGate.release()
    await waitFor {
      store.libraryFeatureModel.detailActionTask == nil && store.libraryFeatureModel.detailSourceTask == nil
    }

    #expect(store.libraryDetail.sourceText.contains("Mine"))
    #expect(!store.libraryDetail.hasChangedOnDisk)
    #expect(!store.libraryDetail.isDraftDirty)
  }

  @Test
  func aReloadDuringASaveLeavesTheRereadToTheSave() async throws {
    let buildGate = BlockingCallGate()
    let saveGate = BlockingCallGate()
    let disk = MutableTextState(#"{"id":"solo","name":"Solo","summary":"Original."}"#)
    let store = makeLibraryStore(
      disk: disk,
      beforeBuild: { buildNumber in
        if buildNumber == 2 {
          _ = buildGate.markStarted()
          buildGate.waitUntilReleased()
        }
      },
      saveHandler: { rawJSON in
        _ = saveGate.markStarted()
        saveGate.waitUntilReleased()
        disk.value = rawJSON
      }
    )
    let item = try await loadSoloItem(store)

    store.selectLibraryDetailItem(item, entityType: .persona)
    await waitFor { store.libraryDetail.isDraftReady }

    store.updateLibraryDetailForm { $0.primaryText = "Mine" }
    store.reloadWorkspaceAfterExternalChange(changedFileURLs: [soloFileURL])
    await waitFor { buildGate.hasStarted }

    store.saveLibraryDetailDraft()
    buildGate.release()
    await waitFor { saveGate.hasStarted }
    await yieldTasks()

    // The reload finished while the save was in flight and started no read of its own.
    #expect(store.inFlightReloadTrigger == nil)
    #expect(store.libraryDetail.isSaving)
    #expect(store.libraryFeatureModel.detailSourceTask == nil)

    saveGate.release()
    await waitFor {
      store.libraryFeatureModel.detailActionTask == nil && store.libraryFeatureModel.detailSourceTask == nil
    }

    #expect(store.libraryDetail.sourceText.contains("Mine"))
    #expect(!store.libraryDetail.isDraftDirty)
  }

  @Test
  func aFailedSaveKeepsTheDraftAndReportsInline() async throws {
    let disk = MutableTextState(#"{"id":"solo","name":"Solo","summary":"Original."}"#)
    let store = makeLibraryStore(
      disk: disk,
      saveHandler: { _ in
        throw WorkspaceSnapshotBuildError(message: "Permission denied.")
      }
    )
    let item = try await loadSoloItem(store)

    store.selectLibraryDetailItem(item, entityType: .persona)
    await waitFor { store.libraryDetail.isDraftReady }

    store.updateLibraryDetailForm { $0.primaryText = "Mine" }
    store.saveLibraryDetailDraft()
    await waitFor {
      store.libraryFeatureModel.detailActionTask == nil && store.libraryFeatureModel.detailSourceTask == nil
    }

    #expect(store.libraryDetail.inlineMessage?.contains("Permission denied.") == true)
    #expect(store.libraryDetail.inlineMessageIsError)
    #expect(!store.libraryDetail.isSaving)
    #expect(store.libraryDetail.isDraftDirty)
    #expect(store.libraryDetail.formState.primaryText == "Mine")
  }

  // MARK: Session preview

  @Test
  func otherSessionsChangesDoNotReloadThePreview() async {
    let previewCount = CallCounter()
    let buildCount = CallCounter()
    let store = makeSessionStore(previewCount: previewCount, buildCount: buildCount) { _ in
      "preview"
    }

    store.workspaceURL = workspaceURL
    store.loadWorkspace()
    await waitFor { store.snapshot.sessions.count == 2 }

    store.refreshSessionPreview(for: store.snapshot.sessions.first { $0.id == "session-a" })
    await waitFor { store.sessionPreview == "preview" }
    #expect(previewCount.count == 1)

    store.reloadWorkspaceAfterExternalChange(
      changedFileURLs: [URL(fileURLWithPath: "/Workspace/.personakit/Sessions/session-b.session.json")]
    )
    await waitFor { buildCount.count == 2 }
    await yieldTasks()

    #expect(previewCount.count == 1)
  }

  @Test
  func relevantChangeRefreshesThePreviewWithoutAVisibleReload() async {
    let gate = BlockingCallGate()
    let previewCount = CallCounter()
    let store = makeSessionStore(previewCount: previewCount) { _ in
      guard previewCount.count > 1 else {
        return "first"
      }

      _ = gate.markStarted()
      gate.waitUntilReleased()
      return "second"
    }

    store.workspaceURL = workspaceURL
    store.loadWorkspace()
    await waitFor { store.snapshot.sessions.count == 2 }

    store.refreshSessionPreview(for: store.snapshot.sessions.first { $0.id == "session-a" })
    await waitFor { store.sessionPreview == "first" }

    store.reloadWorkspaceAfterExternalChange(changedFileURLs: [soloFileURL])
    await waitFor { gate.hasStarted }

    // The old preview stays up, with no loading state, while it re-resolves.
    #expect(store.sessionPreview == "first")
    #expect(!store.isLoadingSessionPreview)

    gate.release()
    await waitFor { store.sessionPreview == "second" }
  }

  @Test
  func externalReloadThatSupersedesAnExplicitOneRestartsAnInterruptedPreview() async {
    let gate = BlockingCallGate()
    let previewCount = CallCounter()
    let store = makeSessionStore(previewCount: previewCount) { _ in
      if previewCount.count == 1 {
        _ = gate.markStarted()
        gate.waitUntilReleased()
      }

      return "preview"
    }

    store.workspaceURL = workspaceURL
    store.loadWorkspace()
    await waitFor { store.snapshot.sessions.count == 2 }

    store.refreshSessionPreview(for: store.snapshot.sessions.first { $0.id == "session-a" })
    await waitFor { gate.hasStarted }

    // The explicit reload cancels the in-flight preview; the external one replaces the
    // explicit load before it lands and only touches another session's file.
    store.loadWorkspace()
    store.reloadWorkspaceAfterExternalChange(
      changedFileURLs: [URL(fileURLWithPath: "/Workspace/.personakit/Sessions/session-b.session.json")]
    )
    gate.release()

    await waitFor { store.sessionPreview == "preview" && !store.isLoadingSessionPreview }
    #expect(previewCount.count == 2)
  }

  @Test
  func confirmingDeletionReportsTheDeletedSession() async {
    let store = makeSessionStore { _ in "preview" }
    var deletedSessionIDs: [String] = []

    store.workspaceURL = workspaceURL
    store.loadWorkspace()
    await waitFor { store.snapshot.sessions.count == 2 }

    store.requestSessionDeletion(store.snapshot.sessions[0])
    let presentation = store.pendingSessionDeletion

    #expect(presentation?.session.id == "session-a")

    if let presentation {
      store.confirmSessionDeletion(presentation) { deletedSessionIDs.append($0) }
    }

    await waitFor { deletedSessionIDs == ["session-a"] }
    #expect(store.pendingSessionDeletion == nil)
    #expect(store.sessionActionErrorMessage == nil)
  }

  // MARK: Session editor

  @Test
  func changingSelectionCancelsAPendingEditorLoad() async {
    let gate = BlockingCallGate()
    let store = makeSessionStore(
      loadDraft: { _ in
        _ = gate.markStarted()
        gate.waitUntilReleased()
        return WorkspaceSessionDraft(
          id: "session-a",
          personaId: "persona",
          directiveId: "directive",
          kitOverrides: []
        )
      },
      preview: { _ in "preview" }
    )

    store.workspaceURL = workspaceURL
    store.loadWorkspace()
    await waitFor { store.snapshot.sessions.count == 2 }

    store.presentSessionEditor(for: store.snapshot.sessions[0])
    await waitFor { gate.hasStarted }
    #expect(store.isLoadingSessionDraft)

    store.sessionSelectionDidChange()
    gate.release()
    await yieldTasks()

    #expect(!store.isLoadingSessionDraft)
    #expect(store.sessionEditorPresentation == nil)
  }

  // MARK: Observation

  @Test
  func validationResultsNotifyObserversWithoutARevisionCounter() async {
    let store = WorkspaceStore(
      snapshotBuilder: WorkspaceStoreStubSnapshotBuilder { _ in makeSnapshot(id: "solo") },
      workspaceValidator: WorkspaceStoreStubWorkspaceValidator { _ in
        makeValidation(entityID: "solo")
      }
    )
    store.workspaceURL = workspaceURL
    store.loadWorkspace()
    await waitFor { store.validation.issues.count == 1 }

    let didChange = MutableBooleanState(value: false)

    withObservationTracking {
      _ = store.validation
    } onChange: {
      didChange.value = true
    }

    store.validateWorkspace()

    #expect(didChange.value)

    // The async result lands through observation too, which the retired
    // `validationRevision` counter used to force.
    let didFinish = MutableBooleanState(value: false)

    withObservationTracking {
      _ = store.validation
    } onChange: {
      didFinish.value = true
    }

    await waitFor { didFinish.value }
    await waitFor { store.validation.issues.count == 1 }
  }

  // MARK: Helpers

  private func makeLibraryStore(
    disk: MutableTextState,
    readCount: CallCounter = CallCounter(),
    buildCount: CallCounter = CallCounter(),
    buildFails: MutableBooleanState = MutableBooleanState(value: false),
    beforeBuild: (@Sendable (Int) -> Void)? = nil,
    readHandler: (@Sendable (URL) throws -> String)? = nil,
    validateHandler: @escaping @Sendable (String) throws -> Void = { _ in },
    saveHandler: @escaping @Sendable (String) throws -> Void = { _ in }
  ) -> WorkspaceStore {
    let soloFileURL = soloFileURL
    let otherFileURL = otherFileURL

    return WorkspaceStore(
      snapshotBuilder: WorkspaceStoreStubSnapshotBuilder { _ in
        buildCount.increment()
        beforeBuild?(buildCount.count)

        if buildFails.value {
          throw WorkspaceSnapshotBuildError(message: "Failed to load workspace registry.")
        }

        return WorkspaceSnapshot(
          sessions: [],
          personas: [
            WorkspaceListItem(id: "solo", displayName: "Solo", fileURL: soloFileURL, sourceScope: .project),
            WorkspaceListItem(id: "other", displayName: "Other", fileURL: otherFileURL, sourceScope: .project),
          ],
          directives: [],
          kits: [],
          skills: []
        )
      },
      workspaceValidator: WorkspaceStoreStubWorkspaceValidator { _ in
        WorkspaceValidationSnapshot(summary: "ok", issues: [])
      },
      libraryEntityManager: WorkspaceStoreStubLibraryEntityManager(
        loadRawJSONHandler: { fileURL in
          readCount.increment()
          return try readHandler?(fileURL) ?? disk.value
        },
        validateRawJSONHandler: { rawJSON, _, _ in try validateHandler(rawJSON) },
        saveRawJSONHandler: { _, _, rawJSON, _ in try saveHandler(rawJSON) },
        copyGlobalItemToProjectHandler: { _, _, _ in }
      )
    )
  }

  private func loadItems(_ store: WorkspaceStore) async throws -> [WorkspaceListItem] {
    store.workspaceURL = workspaceURL
    store.loadWorkspace()
    await waitFor { store.snapshot.personas.count == 2 }
    return store.snapshot.personas
  }

  private func loadSoloItem(_ store: WorkspaceStore) async throws -> WorkspaceListItem {
    try #require(try await loadItems(store).first)
  }

  private func makeSessionStore(
    previewCount: CallCounter = CallCounter(),
    buildCount: CallCounter = CallCounter(),
    loadDraft: @escaping @Sendable (URL) throws -> WorkspaceSessionDraft = { _ in
      WorkspaceSessionDraft(id: "", personaId: "", directiveId: "", kitOverrides: [])
    },
    preview: @escaping @Sendable (WorkspaceSessionListItem) throws -> String
  ) -> WorkspaceStore {
    let sessions = ["session-a", "session-b"].map { sessionID in
      WorkspaceSessionListItem(
        id: sessionID,
        personaId: "persona",
        directiveId: "directive",
        fileURL: URL(fileURLWithPath: "/Workspace/.personakit/Sessions/\(sessionID).session.json"),
        sourceScope: .project
      )
    }

    return WorkspaceStore(
      snapshotBuilder: WorkspaceStoreStubSnapshotBuilder { _ in
        buildCount.increment()
        return WorkspaceSnapshot(
          sessions: sessions,
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
        loadDraftHandler: loadDraft,
        saveSessionHandler: { _, draft, _, _, _, _ in draft.id },
        deleteSessionHandler: { _, _ in }
      ),
      sessionPreviewManager: WorkspaceStoreStubSessionPreviewManager(
        loadPreviewHandler: { _, session in
          previewCount.increment()
          return try preview(session)
        },
        exportPreviewHandler: { _, _ in }
      )
    )
  }

  private func yieldTasks(_ iterations: Int = 50) async {
    for _ in 0..<iterations {
      await Task.yield()
    }
  }
}
