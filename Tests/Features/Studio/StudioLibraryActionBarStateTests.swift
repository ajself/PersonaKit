import ContextCore
import ContextWorkspaceCore
import Foundation
import Testing

@testable import StudioFeatures

struct StudioLibraryActionBarStateTests {
  @Test
  func personasProjectSelectionUsesRawJSONEditAndDisablesCopy() {
    let state = StudioLibraryActionBarState(
      selection: .personas,
      selectedItem: makeItem(scope: .project),
      isLoadingLibraryEditor: false
    )

    #expect(state.editAction == .rawJSON)
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
  func essentialsProjectSelectionUsesMarkdownEdit() {
    let state = StudioLibraryActionBarState(
      selection: .essentials,
      selectedItem: makeItem(scope: .project),
      isLoadingLibraryEditor: false
    )

    #expect(state.editAction == .markdown)
    #expect(!state.showsCreateAction)
    #expect(!state.canCreate)
    #expect(state.canReveal)
    #expect(state.canEdit)
    #expect(!state.canCopyToProject)
  }

  @Test
  func essentialsGlobalSelectionEnablesCopyAndDisablesEdit() {
    let state = StudioLibraryActionBarState(
      selection: .essentials,
      selectedItem: makeItem(scope: .global),
      isLoadingLibraryEditor: false
    )

    #expect(state.editAction == .markdown)
    #expect(!state.showsCreateAction)
    #expect(!state.canCreate)
    #expect(state.canReveal)
    #expect(!state.canEdit)
    #expect(state.canCopyToProject)
  }

  @Test
  func loadingDisablesEditAndCopyAcrossLibrarySelections() {
    let state = StudioLibraryActionBarState(
      selection: .personas,
      selectedItem: makeItem(scope: .project),
      isLoadingLibraryEditor: true
    )

    #expect(state.editAction == .rawJSON)
    #expect(state.showsCreateAction)
    #expect(!state.canCreate)
    #expect(state.canReveal)
    #expect(!state.canEdit)
    #expect(!state.canCopyToProject)
    #expect(state.isLoadingEditor)
  }

  @Test
  func directivesSelectionHidesCreateAction() {
    let state = StudioLibraryActionBarState(
      selection: .directives,
      selectedItem: makeItem(scope: .project),
      isLoadingLibraryEditor: false
    )

    #expect(state.editAction == .rawJSON)
    #expect(!state.showsCreateAction)
    #expect(!state.canCreate)
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
