import ContextCore
import ContextWorkspaceCore
import Foundation
import Testing

@testable import StudioFeatures

struct StudioLibraryActionBarStateTests {
  @Test
  func personasProjectSelectionUsesInlineFormEditAndDisablesCopy() {
    let state = StudioLibraryActionBarState(
      selection: .personas,
      selectedItem: makeItem(scope: .project),
      entityType: .persona,
      isLoadingLibraryEditor: false
    )

    #expect(state.editAction == .inlineForm)
    #expect(state.showsCreateAction)
    #expect(state.canCreate)
    #expect(state.canReveal)
    #expect(state.canEdit)
    #expect(!state.canCopyToProject)
    #expect(!state.isLoadingEditor)
  }

  @Test
  func personasGlobalSelectionDisablesEditAndEnablesCopy() {
    let state = StudioLibraryActionBarState(
      selection: .personas,
      selectedItem: makeItem(scope: .global),
      entityType: .persona,
      isLoadingLibraryEditor: false
    )

    #expect(state.editAction == .rawJSON)
    #expect(state.showsCreateAction)
    #expect(state.canCreate)
    #expect(state.canReveal)
    #expect(!state.canEdit)
    #expect(state.canCopyToProject)
  }

  @Test
  func loadingDisablesEditAndCopyAcrossLibrarySelections() {
    let state = StudioLibraryActionBarState(
      selection: .personas,
      selectedItem: makeItem(scope: .project),
      entityType: .persona,
      isLoadingLibraryEditor: true
    )

    #expect(state.editAction == .inlineForm)
    #expect(state.showsCreateAction)
    #expect(!state.canCreate)
    #expect(state.canReveal)
    #expect(!state.canEdit)
    #expect(!state.canCopyToProject)
    #expect(state.isLoadingEditor)
  }

  @Test
  func skillsProjectSelectionUsesInlineFormEdit() {
    let state = StudioLibraryActionBarState(
      selection: .skills,
      selectedItem: makeItem(scope: .project),
      entityType: .skill,
      isLoadingLibraryEditor: false
    )

    #expect(state.editAction == .inlineForm)
    #expect(state.showsCreateAction)
    #expect(state.canCreate)
    #expect(state.canReveal)
    #expect(state.canEdit)
    #expect(!state.canCopyToProject)
  }

  @Test
  func directivesSelectionShowsCreateAction() {
    let state = StudioLibraryActionBarState(
      selection: .directives,
      selectedItem: makeItem(scope: .project),
      entityType: .directive,
      isLoadingLibraryEditor: false
    )

    #expect(state.editAction == .inlineForm)
    #expect(state.showsCreateAction)
    #expect(state.canCreate)
  }

  private func makeItem(
    scope: WorkspaceSourceScope
  ) -> WorkspaceListItem {
    WorkspaceListItem(
      id: "item-a",
      displayName: "Item A",
      fileURL: URL(fileURLWithPath: "/Workspace/.personakit/Packs/personas/item-a.persona.json"),
      sourceScope: scope
    )
  }
}
