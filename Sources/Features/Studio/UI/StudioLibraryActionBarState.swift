import ContextCore
import ContextWorkspaceCore

enum StudioLibraryEditAction: Equatable, Sendable {
  case markdown
  case rawJSON
}

/// Consolidated action state for Studio library/essentials command bars.
struct StudioLibraryActionBarState {
  let editAction: StudioLibraryEditAction?
  let canReveal: Bool
  let canEdit: Bool
  let canCopyToProject: Bool
  let isLoadingEditor: Bool

  init(
    selection: SidebarItem,
    selectedItem: WorkspaceListItem?,
    isLoadingLibraryEditor: Bool
  ) {
    let isProjectSelection = selectedItem?.sourceScope == .project
    let isGlobalSelection = selectedItem?.sourceScope == .global

    switch selection {
    case .essentials:
      editAction = .markdown

    case .personas,
      .directives,
      .kits,
      .skills,
      .intents:
      editAction = .rawJSON

    default:
      editAction = nil
    }

    canReveal = selectedItem != nil
    canEdit = editAction != nil && isProjectSelection && !isLoadingLibraryEditor
    canCopyToProject = editAction != nil && isGlobalSelection && !isLoadingLibraryEditor
    isLoadingEditor = isLoadingLibraryEditor
  }
}
