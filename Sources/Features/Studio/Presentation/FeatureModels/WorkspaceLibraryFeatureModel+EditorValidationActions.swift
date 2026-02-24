import ContextCore

extension WorkspaceLibraryFeatureModel {
  /// Validates raw JSON from the library editor and returns an optional error message.
  func validateLibraryEditorRawJSON(
    _ rawJSON: String,
    presentation: WorkspaceLibraryEditorPresentation
  ) async -> String? {
    do {
      try await operationRunner.validateLibraryItemRawJSON(
        rawJSON,
        itemID: presentation.itemID,
        entityType: presentation.entityType
      )

      return nil
    } catch {
      return error.localizedDescription
    }
  }
}
