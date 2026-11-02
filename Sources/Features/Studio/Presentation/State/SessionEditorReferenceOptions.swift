import ContextWorkspaceCore
import Foundation

/// Picker options for a session's persona or directive reference.
///
/// An id the session names but the workspace hasn't loaded stays selectable as its own
/// option, so opening the editor never silently swaps it for a different entity.
struct SessionEditorReferenceOptions: Equatable, Sendable {
  let loadedIDs: [String]
  /// Name-first picker titles for the loaded ids.
  let titlesByID: [String: String]
  /// The session's id when it names nothing in `loadedIDs`; `nil` otherwise.
  let unloadedID: String?
  let initialSelection: String

  /// Options for the loaded items in id order, like the library list, titled name-first.
  init(requestedID: String, loadedItems: [WorkspaceListItem]) {
    let titlesByID = Dictionary(
      loadedItems.map { ($0.id, StudioReferenceTitle.nameFirst(name: $0.displayName, id: $0.id)) },
      uniquingKeysWith: { first, _ in first }
    )

    self.init(
      requestedID: requestedID,
      loadedIDs: titlesByID.keys.sorted(),
      titlesByID: titlesByID
    )
  }

  init(requestedID: String, loadedIDs: [String], titlesByID: [String: String] = [:]) {
    self.loadedIDs = loadedIDs
    self.titlesByID = titlesByID

    if requestedID.isEmpty {
      // A new session names nothing yet; start on the first loaded entity.
      unloadedID = nil
      initialSelection = loadedIDs.first ?? ""
    } else if loadedIDs.contains(requestedID) {
      unloadedID = nil
      initialSelection = requestedID
    } else {
      unloadedID = requestedID
      initialSelection = requestedID
    }
  }

  func isLoaded(_ id: String) -> Bool {
    loadedIDs.contains(id)
  }

  func title(for id: String) -> String {
    titlesByID[id] ?? id
  }

  static func unloadedTitle(for id: String) -> String {
    "\(id) (not loaded)"
  }
}
