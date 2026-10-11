import ContextCore
import ContextWorkspaceCore
import Foundation
import StudioFoundation

extension WorkspaceLibraryFeatureModel {
  /// Loads the selected item's raw JSON in an owned task and presents the JSON editor.
  func presentRawJSONEditor(
    selectedItem: WorkspaceListItem?,
    entityType: WorkspaceLibraryEntityType?,
    snapshot: WorkspaceSnapshot,
    workspaceURL: URL?,
    currentWorkspaceURL: @MainActor @escaping () -> URL?
  ) {
    editorOpenTask?.cancel()
    editorOpenTask = Task {
      let presentation = await openLibraryEditor(
        selectedItem: selectedItem,
        entityType: entityType,
        snapshot: snapshot,
        workspaceURL: workspaceURL,
        currentWorkspaceURL: currentWorkspaceURL
      )

      guard !Task.isCancelled else {
        return
      }

      editorOpenTask = nil

      if let presentation {
        rawJSONEditorPresentation = presentation
      }
    }
  }

  func presentNewLibraryEditor(
    entityType: WorkspaceLibraryEntityType,
    workspaceURL: URL?
  ) {
    rawJSONEditorPresentation = newLibraryEditorPresentation(
      entityType: entityType,
      workspaceURL: workspaceURL
    )
  }

  func presentPersonaEditor(
    snapshot: WorkspaceSnapshot,
    workspaceURL: URL?
  ) {
    guard let workspaceURL = workspaceURL?.standardizedFileURL else {
      return
    }

    personaEditorPresentation = PersonaEditorPresentation(
      workspaceURL: workspaceURL,
      draft: defaultPersonaDraft(),
      existingPersonaIDs: snapshot.personas.map(\.id),
      knownKits: snapshot.kits,
      knownSkills: snapshot.skills
    )
  }

  func dismissRawJSONEditor() {
    rawJSONEditorPresentation = nil
  }

  func dismissPersonaEditor() {
    personaEditorPresentation = nil
  }

  /// Copies the selected global item into project scope in an owned task.
  func copyGlobalItemToProject(
    selectedItem: WorkspaceListItem?,
    entityType: WorkspaceLibraryEntityType?,
    snapshot: WorkspaceSnapshot,
    workspaceURL: URL?,
    currentWorkspaceURL: @MainActor @escaping () -> URL?,
    onWorkspaceMutation: @MainActor @escaping () -> Void
  ) {
    copyTask?.cancel()
    copyTask = Task {
      _ = await copySelectedGlobalLibraryItem(
        selectedItem: selectedItem,
        entityType: entityType,
        snapshot: snapshot,
        workspaceURL: workspaceURL,
        currentWorkspaceURL: currentWorkspaceURL,
        onWorkspaceMutation: onWorkspaceMutation
      )

      guard !Task.isCancelled else {
        return
      }

      copyTask = nil
    }
  }
}
