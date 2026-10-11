import ContextCore
import ContextWorkspaceCore
import Foundation
import StudioFoundation
import Testing

@testable import StudioFeatures

struct StudioLibraryDetailStateTests {
  private let originalSource = #"{"id":"solo","name":"Solo","summary":"Original."}"#
  private let changedSource = #"{"id":"solo","name":"Solo","summary":"Changed elsewhere."}"#

  @Test
  func loadedProjectItemStartsWithACleanDraft() {
    var state = loadedState()

    #expect(!state.isLoading)
    #expect(state.isDraftReady)
    #expect(state.formState.primaryText == "Solo")
    #expect(!state.isDraftDirty)

    state.updateForm { $0.primaryText = "Mine" }

    #expect(state.isDraftDirty)
  }

  @Test
  func reloadWithACleanDraftFollowsTheFileOnDisk() {
    var state = loadedState()

    state.applyLoadedSource(changedSource)

    #expect(state.sourceText == changedSource)
    #expect(state.draftRawJSON == changedSource)
    #expect(state.formState.secondaryText == "Changed elsewhere.")
    #expect(!state.hasChangedOnDisk)
  }

  @Test
  func reloadKeepsUnsavedEditsAndFlagsTheDiskChange() {
    var state = loadedState()
    state.updateForm { $0.primaryText = "Mine" }
    let editedDraft = state.draftRawJSON

    state.applyLoadedSource(changedSource)

    #expect(state.draftRawJSON == editedDraft)
    #expect(state.formState.primaryText == "Mine")
    #expect(state.sourceText == changedSource)
    #expect(state.isDraftDirty)
    #expect(state.hasChangedOnDisk)
  }

  @Test
  func reloadThatMatchesTheDraftClearsTheNotice() {
    var state = loadedState()
    state.updateForm { $0.primaryText = "Mine" }
    state.applyLoadedSource(changedSource)

    state.applyLoadedSource(state.draftRawJSON)

    #expect(!state.isDraftDirty)
    #expect(!state.hasChangedOnDisk)
  }

  @Test
  func unchangedReloadIsANoOp() {
    var state = loadedState()
    state.updateForm { $0.primaryText = "Mine" }
    let before = state

    state.applyLoadedSource(originalSource)

    #expect(state == before)
  }

  @Test
  func revertAfterADiskChangeLoadsTheNewVersion() {
    var state = loadedState()
    state.updateForm { $0.primaryText = "Mine" }
    state.applyLoadedSource(changedSource)

    state.revertDraft()

    #expect(state.draftRawJSON == changedSource)
    #expect(state.formState.primaryText == "Solo")
    #expect(!state.isDraftDirty)
    #expect(!state.hasChangedOnDisk)
  }

  @Test
  func failedReadKeepsUnsavedEdits() {
    var state = loadedState()
    state.updateForm { $0.primaryText = "Mine" }
    let editedDraft = state.draftRawJSON

    state.applyFailedSource(message: "File vanished mid-save.")

    #expect(state.draftRawJSON == editedDraft)
    #expect(state.errorMessage == nil)
    #expect(state.isDraftDirty)
  }

  @Test
  func successfulSaveMakesTheDraftTheSource() {
    var state = loadedState()
    state.updateForm { $0.primaryText = "Mine" }
    state.applyLoadedSource(changedSource)

    state.beginSaving()
    state.finishSaving(errorMessage: nil)

    #expect(!state.isSaving)
    #expect(!state.isDraftDirty)
    #expect(!state.hasChangedOnDisk)
    #expect(state.inlineMessage == "Saved solo.")
  }

  @Test
  func globalItemsAreReadOnly() {
    var state = StudioLibraryDetailState()
    state.select(makeItem(scope: .global))
    state.applyLoadedSource(originalSource)

    #expect(state.sourceText == originalSource)
    #expect(!state.isDraftReady)

    state.updateForm { $0.primaryText = "Mine" }

    #expect(!state.isDraftDirty)
  }

  @Test
  func selectingAnotherItemDiscardsTheDraft() {
    var state = loadedState()
    state.updateForm { $0.primaryText = "Mine" }

    state.select(makeItem(id: "other", scope: .project))

    #expect(state.isLoading)
    #expect(state.draftRawJSON.isEmpty)
    #expect(!state.isDraftDirty)
  }

  @Test
  func sourceFormatterPrettyPrintsJSONAndPassesOtherTextThrough() {
    #expect(
      StudioLibrarySourceFormatter.displayText(for: #"{"b":1,"a":2}"#)
        == "{\n  \"a\" : 2,\n  \"b\" : 1\n}"
    )
    #expect(StudioLibrarySourceFormatter.displayText(for: "# Skill") == "# Skill")
  }

  private func loadedState() -> StudioLibraryDetailState {
    var state = StudioLibraryDetailState()
    state.select(makeItem(scope: .project))
    state.applyLoadedSource(originalSource)
    return state
  }

  private func makeItem(
    id: String = "solo",
    scope: WorkspaceSourceScope
  ) -> StudioLibraryDetailItem {
    StudioLibraryDetailItem(
      item: WorkspaceListItem(
        id: id,
        displayName: id,
        fileURL: URL(fileURLWithPath: "/Workspace/.personakit/Packs/personas/\(id).persona.json"),
        sourceScope: scope
      ),
      entityType: .persona
    )
  }
}
