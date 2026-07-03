import ContextCore
import ContextWorkspaceCore
import StudioFoundation

extension WorkspaceStore {
  /// Creates a prefilled draft for new-persona creation.
  func defaultPersonaDraft() -> WorkspacePersonaDraft {
    libraryFeatureModel.defaultPersonaDraft()
  }

  /// Saves a new persona draft to project scope and returns an optional error message.
  func createPersona(draft: WorkspacePersonaDraft) async -> String? {
    await libraryFeatureModel.createPersona(
      draft: draft,
      snapshot: snapshot,
      workspaceURL: workspaceURL,
      currentWorkspaceURLProvider: { self.workspaceURL },
      onWorkspaceMutation: { self.loadWorkspace() }
    )
  }

  /// Creates a prefilled raw JSON presentation for new library item creation.
  func newLibraryEditorPresentation(
    entityType: WorkspaceLibraryEntityType
  ) -> WorkspaceLibraryEditorPresentation? {
    libraryFeatureModel.newLibraryEditorPresentation(
      entityType: entityType,
      workspaceURL: workspaceURL
    )
  }

  /// Loads raw JSON for a selected project-scoped library item.
  func openLibraryEditor(
    selectedItem: WorkspaceListItem?,
    entityType: WorkspaceLibraryEntityType?
  ) async -> WorkspaceLibraryEditorPresentation? {
    await libraryFeatureModel.openLibraryEditor(
      selectedItem: selectedItem,
      entityType: entityType,
      snapshot: snapshot,
      workspaceURL: workspaceURL,
      currentWorkspaceURL: { self.workspaceURL }
    )
  }

  /// Validates raw JSON from the library editor and returns an optional error message.
  func validateLibraryEditorRawJSON(
    _ rawJSON: String,
    presentation: WorkspaceLibraryEditorPresentation
  ) async -> String? {
    await libraryFeatureModel.validateLibraryEditorRawJSON(
      rawJSON,
      presentation: presentation
    )
  }

  /// Saves raw JSON from the library editor and returns an optional error message.
  func saveLibraryEditorRawJSON(
    _ rawJSON: String,
    presentation: WorkspaceLibraryEditorPresentation
  ) async -> String? {
    await libraryFeatureModel.saveLibraryEditorRawJSON(
      rawJSON,
      presentation: presentation,
      snapshot: snapshot,
      currentWorkspaceURLProvider: { self.workspaceURL },
      onWorkspaceMutation: { self.loadWorkspace() }
    )
  }

  /// Copies a selected global library item into project scope and updates status state.
  func copySelectedGlobalLibraryItem(
    selectedItem: WorkspaceListItem?,
    entityType: WorkspaceLibraryEntityType?
  ) async -> Bool {
    await libraryFeatureModel.copySelectedGlobalLibraryItem(
      selectedItem: selectedItem,
      entityType: entityType,
      snapshot: snapshot,
      workspaceURL: workspaceURL,
      currentWorkspaceURL: { self.workspaceURL },
      onWorkspaceMutation: { self.loadWorkspace() }
    )
  }
}
