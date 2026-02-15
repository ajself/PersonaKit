import ContextCore
import Foundation

/// Raw JSON editor payload used by Studio library editing flows.
struct WorkspaceLibraryEditorPresentation: Equatable, Identifiable, Sendable {
  let itemID: String
  let entityType: WorkspaceLibraryEntityType
  let fileURL: URL
  let rawJSON: String
  let workspaceURL: URL

  var id: String {
    "\(workspaceURL.path())::\(entityType.rawValue)::\(itemID)"
  }
}

/// Markdown editor payload used by Studio essentials editing flows.
struct WorkspaceEssentialEditorPresentation: Equatable, Identifiable, Sendable {
  let fileURL: URL
  let itemID: String
  let markdown: String
  let workspaceURL: URL

  var id: String {
    "\(workspaceURL.path())::\(itemID)"
  }
}
