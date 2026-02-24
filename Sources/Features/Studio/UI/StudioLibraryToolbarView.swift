import ContextCore
import ContextWorkspaceCore
import SwiftUI

/// Toolbar for library and essentials list actions.
struct StudioLibraryToolbarView: View {
  let actionState: StudioLibraryActionBarState
  let onNew: () -> Void
  let onRevealInFinder: () -> Void
  let onEdit: () -> Void
  let onCopyToProject: () -> Void

  var body: some View {
    StudioActionBarView(
      actions: actionItems,
      isLoading: actionState.isLoadingEditor
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

    actions.append(
      StudioActionItem(
        id: "library-reveal",
        group: .selection,
        title: "Reveal",
        systemImage: "folder",
        role: .standard,
        isEnabled: actionState.canReveal,
        action: onRevealInFinder
      )
    )
    actions.append(
      StudioActionItem(
        id: "library-edit",
        group: .selection,
        title: "Edit",
        systemImage: "pencil",
        role: .standard,
        isEnabled: actionState.canEdit,
        action: onEdit
      )
    )
    actions.append(
      StudioActionItem(
        id: "library-copy",
        group: .selection,
        title: "Copy to Project",
        systemImage: "arrow.down.doc",
        role: .standard,
        isEnabled: actionState.canCopyToProject,
        action: onCopyToProject
      )
    )

    return actions
  }
}
