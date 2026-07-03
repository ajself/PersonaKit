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
