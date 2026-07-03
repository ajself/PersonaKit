import ContextCore
import ContextWorkspaceCore
import StudioFoundation

enum StudioLibraryDetailMode: String, CaseIterable, Sendable {
  case edit
  case json

  var title: String {
    title(for: nil)
  }

  func title(
    for selection: SidebarItem?
  ) -> String {
    switch self {
    case .edit:
      return "Edit"
    case .json:
      return "JSON"
    }
  }
}

enum StudioLibraryDetailModeResolver {
  static func availableModes(
    selection: SidebarItem,
    selectedItem: WorkspaceListItem?,
    entityType: WorkspaceLibraryEntityType?
  ) -> [StudioLibraryDetailMode] {
    guard
      selectedItem?.sourceScope == .project,
      let entityType,
      entityType.supportsMinimalForm
    else {
      return [.json]
    }

    return [.edit, .json]
  }

  static func resolvedMode(
    persistedRawValue: String?,
    selection: SidebarItem,
    selectedItem: WorkspaceListItem?,
    entityType: WorkspaceLibraryEntityType?
  ) -> StudioLibraryDetailMode {
    effectiveMode(
      preferredMode: preferredMode(persistedRawValue: persistedRawValue),
      selection: selection,
      selectedItem: selectedItem,
      entityType: entityType
    )
  }

  static func preferredMode(
    persistedRawValue: String?
  ) -> StudioLibraryDetailMode {
    mode(for: persistedRawValue)
  }

  static func effectiveMode(
    preferredMode: StudioLibraryDetailMode,
    selection: SidebarItem,
    selectedItem: WorkspaceListItem?,
    entityType: WorkspaceLibraryEntityType?
  ) -> StudioLibraryDetailMode {
    let modes = availableModes(
      selection: selection,
      selectedItem: selectedItem,
      entityType: entityType
    )

    guard modes.contains(preferredMode) else {
      return .json
    }

    return preferredMode
  }

  static func persistedRawValue(
    for mode: StudioLibraryDetailMode
  ) -> String {
    mode.rawValue
  }

  private static func mode(
    for rawValue: String?
  ) -> StudioLibraryDetailMode {
    switch rawValue {
    case nil:
      return .edit
    case StudioLibraryDetailMode.edit.rawValue,
      "form":
      return .edit
    case StudioLibraryDetailMode.json.rawValue:
      return .json
    default:
      return .json
    }
  }
}

enum StudioLibraryInlineFormDraftStateResolver {
  static func isReady(
    draftPreviewRequestID: String?,
    previewRequestID: String
  ) -> Bool {
    draftPreviewRequestID == previewRequestID
  }

  static func isDirty(
    effectiveMode: StudioLibraryDetailMode,
    draftPreviewRequestID: String?,
    previewRequestID: String,
    draftRawJSON: String,
    previewText: String
  ) -> Bool {
    guard effectiveMode == .edit,
      isReady(
        draftPreviewRequestID: draftPreviewRequestID,
        previewRequestID: previewRequestID
      )
    else {
      return false
    }

    return draftRawJSON != previewText
  }
}
