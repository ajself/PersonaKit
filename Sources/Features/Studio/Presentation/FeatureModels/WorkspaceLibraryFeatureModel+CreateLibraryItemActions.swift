import ContextCore
import ContextWorkspaceCore
import Foundation

extension WorkspaceLibraryFeatureModel {
  /// Creates a prefilled JSON editor presentation for new library item creation.
  func newLibraryEditorPresentation(
    entityType: WorkspaceLibraryEntityType,
    workspaceURL: URL?
  ) -> WorkspaceLibraryEditorPresentation? {
    guard let workspaceURL = workspaceURL?.standardizedFileURL else {
      setAction(
        message: "No workspace is currently selected.",
        isError: true
      )
      return nil
    }

    do {
      return WorkspaceLibraryEditorPresentation(
        itemID: "new-\(entityType.rawValue)",
        entityType: entityType,
        fileURL: WorkspaceLibraryCreateSupport.placeholderLibraryFileURL(
          workspaceURL: workspaceURL,
          entityType: entityType
        ),
        rawJSON: try WorkspaceLibraryCreateSupport.starterRawJSON(entityType: entityType),
        workspaceURL: workspaceURL,
        isCreatingNewItem: true
      )
    } catch {
      setAction(
        message: error.localizedDescription,
        isError: true
      )
      return nil
    }
  }

  /// Creates a prefilled markdown editor presentation for new essential creation.
  func newEssentialEditorPresentation(
    workspaceURL: URL?
  ) -> WorkspaceEssentialEditorPresentation? {
    guard let workspaceURL = workspaceURL?.standardizedFileURL else {
      setAction(
        message: "No workspace is currently selected.",
        isError: true
      )
      return nil
    }

    let title = "New Essential"

    return WorkspaceEssentialEditorPresentation(
      fileURL: WorkspaceLibraryCreateSupport.placeholderEssentialFileURL(workspaceURL: workspaceURL),
      itemID: WorkspaceEssentialDraftBuilder.suggestedID(from: title),
      markdown: WorkspaceEssentialDraftBuilder.buildMarkdown(
        title: title,
        body: nil,
        template: .starter
      ),
      workspaceURL: workspaceURL,
      isCreatingNewItem: true
    )
  }
}
