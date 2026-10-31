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
