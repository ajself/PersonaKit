import ContextCore

extension WorkspaceLibraryFeatureModel {
  /// Validates raw JSON from the library editor and returns an optional error message.
  func validateLibraryEditorRawJSON(
    _ rawJSON: String,
    presentation: WorkspaceLibraryEditorPresentation
  ) async -> String? {
    do {
      let itemID = try itemIDForValidation(
        rawJSON,
        presentation: presentation
      )

      try await operationRunner.validateLibraryItemRawJSON(
        rawJSON,
        itemID: itemID,
        entityType: presentation.entityType
      )

      return nil
    } catch {
      return error.localizedDescription
    }
  }

  private func itemIDForValidation(
    _ rawJSON: String,
    presentation: WorkspaceLibraryEditorPresentation
  ) throws -> String {
    guard presentation.isCreatingNewItem else {
      return presentation.itemID
    }

    return try WorkspaceLibraryCreateSupport.itemID(rawJSON: rawJSON)
  }
}
