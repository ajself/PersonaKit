import Foundation

/// Picker options for a session's persona or directive reference.
///
/// An id the session names but the workspace hasn't loaded stays selectable as its own
/// option, so opening the editor never silently swaps it for a different entity.
struct SessionEditorReferenceOptions: Equatable, Sendable {
  let loadedIDs: [String]
  /// The session's id when it names nothing in `loadedIDs`; `nil` otherwise.
  let unloadedID: String?
  let initialSelection: String

  init(requestedID: String, loadedIDs: [String]) {
    self.loadedIDs = loadedIDs

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

  static func unloadedTitle(for id: String) -> String {
    "\(id) (not loaded)"
  }
}
