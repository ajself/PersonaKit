import ContextCore
import ContextWorkspaceCore
import SwiftUI

/// Toolbar for library and essentials list actions.
struct StudioLibraryToolbarView: View {
  let actionState: StudioLibraryActionBarState
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
    [
      StudioActionItem(
        id: "library-reveal",
        group: .selection,
        title: "Reveal",
        systemImage: "folder",
        role: .standard,
        isEnabled: actionState.canReveal,
        action: onRevealInFinder
      ),
      StudioActionItem(
        id: "library-edit",
        group: .selection,
        title: "Edit",
        systemImage: "pencil",
        role: .standard,
        isEnabled: actionState.canEdit,
        action: onEdit
      ),
      StudioActionItem(
        id: "library-copy",
        group: .selection,
        title: "Copy to Project",
        systemImage: "arrow.down.doc",
        role: .standard,
        isEnabled: actionState.canCopyToProject,
        action: onCopyToProject
      ),
    ]
  }
}
