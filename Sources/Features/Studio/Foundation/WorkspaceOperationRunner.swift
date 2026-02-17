import ContextCore
import ContextWorkspaceCore
import Foundation

/// Package-scoped async operation coordinator used by Studio workspace owners.
package actor WorkspaceOperationRunner {
  private let snapshotBuilder: any WorkspaceSnapshotBuilding
  private let workspaceValidator: any WorkspaceValidating
  private let sessionManager: any WorkspaceSessionManaging
  private let essentialManager: any WorkspaceEssentialManaging
  private let libraryEntityManager: any WorkspaceLibraryEntityManaging
  private let sessionPreviewManager: any WorkspaceSessionPreviewManaging
  private let sessionMapBuilder: any WorkspaceSessionMapBuilding
  private let workspaceRelationshipMapBuilder: any WorkspaceRelationshipMapBuilding

  package init(
    snapshotBuilder: any WorkspaceSnapshotBuilding,
    workspaceValidator: any WorkspaceValidating,
    sessionManager: any WorkspaceSessionManaging,
    essentialManager: any WorkspaceEssentialManaging,
    libraryEntityManager: any WorkspaceLibraryEntityManaging,
    sessionPreviewManager: any WorkspaceSessionPreviewManaging,
    sessionMapBuilder: any WorkspaceSessionMapBuilding,
    workspaceRelationshipMapBuilder: any WorkspaceRelationshipMapBuilding
  ) {
    self.snapshotBuilder = snapshotBuilder
    self.workspaceValidator = workspaceValidator
    self.sessionManager = sessionManager
    self.essentialManager = essentialManager
    self.libraryEntityManager = libraryEntityManager
    self.sessionPreviewManager = sessionPreviewManager
    self.sessionMapBuilder = sessionMapBuilder
    self.workspaceRelationshipMapBuilder = workspaceRelationshipMapBuilder
  }

  package func loadSnapshot(workspaceURL: URL) throws -> WorkspaceSnapshot {
    try snapshotBuilder.build(workspaceURL: workspaceURL)
  }

  package func validate(workspaceURL: URL) throws -> WorkspaceValidationSnapshot {
    try workspaceValidator.validate(workspaceURL: workspaceURL)
  }

  package func validate(
    workspaceURL: URL,
    snapshot: WorkspaceSnapshot
  ) throws -> WorkspaceValidationSnapshot {
    let coreValidation = try workspaceValidator.validate(workspaceURL: workspaceURL)
    let sessionIssues = WorkspaceSessionDiagnostics.validateSessions(
      workspaceURL: workspaceURL,
      snapshot: snapshot
    )

    return WorkspaceValidationSnapshot(
      summary: coreValidation.summary,
      issues: coreValidation.issues + sessionIssues
    )
  }

  package func loadSessionDraft(fileURL: URL) throws -> WorkspaceSessionDraft {
    try sessionManager.loadDraft(fileURL: fileURL)
  }

  package func saveSession(
    workspaceURL: URL,
    draft: WorkspaceSessionDraft,
    originalSessionID: String?,
    validPersonaIDs: Set<String>,
    validDirectiveIDs: Set<String>,
    validKitIDs: Set<String>
  ) throws -> String {
    try sessionManager.saveSession(
      workspaceURL: workspaceURL,
      draft: draft,
      originalSessionID: originalSessionID,
      validPersonaIDs: validPersonaIDs,
      validDirectiveIDs: validDirectiveIDs,
      validKitIDs: validKitIDs
    )
  }

  package func deleteSession(
    workspaceURL: URL,
    sessionID: String
  ) throws {
    try sessionManager.deleteSession(
      workspaceURL: workspaceURL,
      sessionID: sessionID
    )
  }

  package func loadEssentialMarkdown(fileURL: URL) throws -> String {
    try essentialManager.loadMarkdown(fileURL: fileURL)
  }

  package func saveEssentialMarkdown(
    workspaceURL: URL,
    itemID: String,
    markdown: String
  ) throws {
    try essentialManager.saveMarkdown(
      workspaceURL: workspaceURL,
      itemID: itemID,
      markdown: markdown
    )
  }

  package func copyGlobalEssentialToProject(
    workspaceURL: URL,
    item: WorkspaceListItem
  ) throws {
    try essentialManager.copyGlobalEssentialToProject(
      workspaceURL: workspaceURL,
      item: item
    )
  }

  package func loadLibraryItemRawJSON(fileURL: URL) throws -> String {
    try libraryEntityManager.loadRawJSON(fileURL: fileURL)
  }

  package func validateLibraryItemRawJSON(
    _ rawJSON: String,
    itemID: String,
    entityType: WorkspaceLibraryEntityType
  ) throws {
    try libraryEntityManager.validateRawJSON(
      rawJSON,
      entityType: entityType,
      expectedID: itemID
    )
  }

  package func saveLibraryItemRawJSON(
    workspaceURL: URL,
    itemID: String,
    rawJSON: String,
    entityType: WorkspaceLibraryEntityType
  ) throws {
    try libraryEntityManager.saveRawJSON(
      workspaceURL: workspaceURL,
      itemID: itemID,
      rawJSON: rawJSON,
      entityType: entityType
    )
  }

  package func copyLibraryItemToProject(
    workspaceURL: URL,
    item: WorkspaceListItem,
    entityType: WorkspaceLibraryEntityType
  ) throws {
    try libraryEntityManager.copyGlobalItemToProject(
      workspaceURL: workspaceURL,
      item: item,
      entityType: entityType
    )
  }

  package func loadSessionPreview(
    workspaceURL: URL,
    session: WorkspaceSessionListItem
  ) throws -> String {
    try sessionPreviewManager.loadPreview(
      workspaceURL: workspaceURL,
      session: session
    )
  }

  package func exportSessionPreview(
    _ preview: String,
    to destinationURL: URL
  ) throws {
    try sessionPreviewManager.exportPreview(
      preview,
      to: destinationURL
    )
  }

  package func loadSessionMap(
    workspaceURL: URL,
    personaId: String,
    directiveId: String,
    kitOverrides: [String]
  ) throws -> WorkspaceSessionMap {
    try sessionMapBuilder.build(
      workspaceURL: workspaceURL,
      personaId: personaId,
      directiveId: directiveId,
      kitOverrides: kitOverrides
    )
  }

  package func loadWorkspaceRelationshipMap(workspaceURL: URL) throws -> WorkspaceSessionMap {
    try workspaceRelationshipMapBuilder.build(workspaceURL: workspaceURL)
  }
}
