import ContextCore
import ContextWorkspaceCore
import Foundation
import StudioFoundation

/// Raw JSON editor payload used by Studio library editing flows.
struct WorkspaceLibraryEditorPresentation: Equatable, Identifiable, Sendable {
  let itemID: String
  let entityType: WorkspaceLibraryEntityType
  let fileURL: URL
  let rawJSON: String
  let workspaceURL: URL
  let isCreatingNewItem: Bool

  init(
    itemID: String,
    entityType: WorkspaceLibraryEntityType,
    fileURL: URL,
    rawJSON: String,
    workspaceURL: URL,
    isCreatingNewItem: Bool = false
  ) {
    self.itemID = itemID
    self.entityType = entityType
    self.fileURL = fileURL
    self.rawJSON = rawJSON
    self.workspaceURL = workspaceURL
    self.isCreatingNewItem = isCreatingNewItem
  }

  var id: String {
    "\(workspaceURL.path())::\(entityType.rawValue)::\(itemID)::\(isCreatingNewItem)"
  }
}

/// Markdown editor payload used by Studio essentials editing flows.
struct WorkspaceEssentialEditorPresentation: Equatable, Identifiable, Sendable {
  let fileURL: URL
  let itemID: String
  let markdown: String
  let workspaceURL: URL
  let isCreatingNewItem: Bool

  init(
    fileURL: URL,
    itemID: String,
    markdown: String,
    workspaceURL: URL,
    isCreatingNewItem: Bool = false
  ) {
    self.fileURL = fileURL
    self.itemID = itemID
    self.markdown = markdown
    self.workspaceURL = workspaceURL
    self.isCreatingNewItem = isCreatingNewItem
  }

  var id: String {
    "\(workspaceURL.path())::\(itemID)::\(isCreatingNewItem)"
  }
}

/// Persona editor payload used by Studio persona-creation workflows.
struct PersonaEditorPresentation: Equatable, Identifiable, Sendable {
  let workspaceURL: URL
  let draft: WorkspacePersonaDraft
  let existingPersonaIDs: [String]
  let knownKits: [WorkspaceListItem]
  let knownSkills: [WorkspaceListItem]

  var id: String {
    "\(workspaceURL.path())::persona-editor"
  }
}
