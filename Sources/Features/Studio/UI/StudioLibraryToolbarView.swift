import ContextCore
import ContextWorkspaceCore
import SwiftUI

/// Toolbar for library list actions.
struct StudioLibraryToolbarView: View {
  let actionState: StudioLibraryActionBarState
  @Binding var searchText: String
  let searchPrompt: String
  let onNew: () -> Void

  var body: some View {
    StudioActionBarView(
      actions: actionItems,
      isLoading: actionState.isLoadingEditor,
      searchText: $searchText,
      searchPrompt: searchPrompt
    )
  }

  private var actionItems: [StudioActionItem] {
    var actions: [StudioActionItem] = []

    if actionState.showsCreateAction {
      actions.append(
        StudioActionItem(
          id: "library-new",
          group: .primary,
          title: "New",
          systemImage: "plus",
          role: .primary,
          isEnabled: actionState.canCreate,
          action: onNew
        )
      )
    }

    return actions
  }
}
