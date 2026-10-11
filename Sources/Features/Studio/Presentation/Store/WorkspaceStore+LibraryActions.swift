import ContextCore
import ContextWorkspaceCore
import Foundation
import StudioFoundation

extension WorkspaceStore {
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

  /// Loads the selected item's raw JSON and presents the JSON editor sheet.
  func presentLibraryEditor(
    selectedItem: WorkspaceListItem?,
    entityType: WorkspaceLibraryEntityType?
  ) {
    libraryFeatureModel.presentRawJSONEditor(
      selectedItem: selectedItem,
      entityType: entityType,
      snapshot: snapshot,
      workspaceURL: workspaceURL,
      currentWorkspaceURL: { self.workspaceURL }
    )
  }

  func presentNewLibraryEditor(entityType: WorkspaceLibraryEntityType) {
    libraryFeatureModel.presentNewLibraryEditor(
      entityType: entityType,
      workspaceURL: workspaceURL
    )
  }

  func presentPersonaEditor() {
    libraryFeatureModel.presentPersonaEditor(
      snapshot: snapshot,
      workspaceURL: workspaceURL
    )
  }

  func dismissLibraryEditor() {
    libraryFeatureModel.dismissRawJSONEditor()
  }

  func dismissPersonaEditor() {
    libraryFeatureModel.dismissPersonaEditor()
  }

  /// Copies the selected global item into project scope.
  func copyGlobalLibraryItemToProject(
    selectedItem: WorkspaceListItem?,
    entityType: WorkspaceLibraryEntityType?
  ) {
    libraryFeatureModel.copyGlobalItemToProject(
      selectedItem: selectedItem,
      entityType: entityType,
      snapshot: snapshot,
      workspaceURL: workspaceURL,
      currentWorkspaceURL: { self.workspaceURL },
      onWorkspaceMutation: { self.loadWorkspace() }
    )
  }

  /// Shows `item` in the library detail pane.
  func selectLibraryDetailItem(
    _ item: WorkspaceListItem?,
    entityType: WorkspaceLibraryEntityType?
  ) {
    libraryFeatureModel.selectDetailItem(
      item.map { StudioLibraryDetailItem(item: $0, entityType: entityType) }
    )
  }

  func updateLibraryDetailForm(_ update: (inout WorkspaceLibraryEntityFormState) -> Void) {
    libraryFeatureModel.updateDetailForm(update)
  }

  func revertLibraryDetailDraft() {
    libraryFeatureModel.revertDetailDraft()
  }

  func validateLibraryDetailDraft() {
    libraryFeatureModel.validateDetailDraft(workspaceURL: workspaceURL)
  }

  func saveLibraryDetailDraft() {
    libraryFeatureModel.saveDetailDraft(
      snapshot: snapshot,
      workspaceURL: workspaceURL,
      currentWorkspaceURLProvider: { self.workspaceURL },
      onWorkspaceMutation: { self.loadWorkspace() }
    )
  }
}
