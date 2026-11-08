import ContextCore
import Foundation

/// Contract for building markdown previews from workspace session selections.
public protocol WorkspaceSessionPreviewBuilding: Sendable {
  func build(
    projectScopeURL: URL,
    globalScopeURL: URL?,
    sessionId: String?,
    personaId: String,
    directiveId: String,
    kitOverrides: [String]
  ) throws -> String
}

/// Bridge between Studio and core resolver/exporter preview generation.
public struct WorkspaceSessionPreviewBuilder: WorkspaceSessionPreviewBuilding, Sendable {
  public init() {}

  /// Builds a markdown preview by validating, resolving, and exporting a session definition.
  ///
  /// - Parameters:
  ///   - projectScopeURL: Required project scope root (`.personakit`) for the active workspace.
  ///   - globalScopeURL: Optional global scope root (`~/.personakit`).
  ///   - sessionId: Optional source session id when previewing a saved session file.
  ///   - personaId: Session persona id.
  ///   - directiveId: Session directive id.
  ///   - kitOverrides: Session kit override ids.
  /// - Returns: Deterministic markdown preview text, stripped of hidden characters as the CLI and MCP exports are.
  /// - Throws: ``WorkspaceSnapshotBuildError`` with user-facing preview failure details.
  public func build(
    projectScopeURL: URL,
    globalScopeURL: URL?,
    sessionId: String?,
    personaId: String,
    directiveId: String,
    kitOverrides: [String]
  ) throws -> String {
    let scopes = ScopeSet(
      projectScopeURL: projectScopeURL,
      globalScopeURL: globalScopeURL
    )

    do {
      let export = try SessionExporter.export(
        scopes: scopes,
        personaId: personaId,
        directiveId: directiveId,
        kitOverrides: kitOverrides,
        sessionId: sessionId
      )
      // Studio copies and exports this text, so a person sees what an agent reading the handoff sees.
      return TerminalText.sanitized(export)
    } catch let error as ExportError {
      throw WorkspaceSnapshotBuildError(
        message: Self.previewMessage(for: error)
      )
    } catch {
      throw WorkspaceSnapshotBuildError(
        message: "Failed to build session preview: \(error.localizedDescription)"
      )
    }
  }

  private static func previewMessage(for error: ExportError) -> String {
    switch error {
    case .validationFailed(let validationResult):
      let details = validationResult.errors.prefix(3).map { $0.lineDescription() }.joined(separator: " ")
      return "Session preview validation failed. \(details)"
    case .resolutionFailed(let resolutionError, _):
      let details = resolutionError.errors.prefix(3).map { resolutionError in
        "\(resolutionError.sourceType.rawValue) \(resolutionError.sourceId) \(resolutionError.field) \(resolutionError.message) missingId=\(resolutionError.missingId)"
      }
      .joined(separator: " ")
      return "Session preview resolution failed. \(details)"
    case .readFailed(let message, _):
      return "Session preview read failed: \(message)"
    }
  }
}
