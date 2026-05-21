import ContextCore
import ContextWorkspaceCore
import StudioFoundation

enum StudioLibraryEditAction: Equatable, Sendable {
  case inlineForm
  case markdown
  case rawJSON
}

/// Consolidated action state for Studio library/essentials command bars.
struct StudioLibraryActionBarState {
  let editAction: StudioLibraryEditAction?
  let canCreate: Bool
  let showsCreateAction: Bool
  let canReveal: Bool
  let canEdit: Bool
  let canCopyToProject: Bool
  let isLoadingEditor: Bool

  init(
    selection: SidebarItem,
    selectedItem: WorkspaceListItem?,
    entityType: WorkspaceLibraryEntityType?,
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
      .references,
      .skills,
      .intents:
      if isProjectSelection,
        entityType?.supportsMinimalForm == true
      {
        editAction = .inlineForm
      } else {
        editAction = .rawJSON
      }

    default:
      editAction = nil
    }

    showsCreateAction =
      selection == .personas
      || selection == .directives
      || selection == .kits
      || selection == .intents
      || selection == .essentials
      || selection == .references
      || selection == .skills
    canCreate = showsCreateAction && !isLoadingLibraryEditor
    canReveal = selectedItem != nil
    canEdit = editAction != nil && isProjectSelection && !isLoadingLibraryEditor
    canCopyToProject = editAction != nil && isGlobalSelection && !isLoadingLibraryEditor
    isLoadingEditor = isLoadingLibraryEditor
  }
}
