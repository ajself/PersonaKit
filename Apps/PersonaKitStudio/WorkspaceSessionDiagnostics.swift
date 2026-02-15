import Foundation
import PersonaKitCore

/// Session-specific diagnostics appended to workspace validation results.
enum WorkspaceSessionDiagnostics {
  /// Minimal session document used for diagnostics-level decoding.
  struct SessionDocument: Codable, Sendable {
    let id: String
    let personaId: String
    let directiveId: String
    let kitOverrides: [String]?
  }

  /// Validates project-scoped session files against filename and reference rules.
  static func validateSessions(
    workspaceURL _: URL,
    snapshot: WorkspaceSnapshot,
    fileManager: FileManager = .default
  ) -> [WorkspaceValidationIssue] {
    let personaIDs = Set(snapshot.personas.map(\.id))
    let directiveIDs = Set(snapshot.directives.map(\.id))
    let kitIDs = Set(snapshot.kits.map(\.id))
    let projectSessions = snapshot.sessions
      .filter { $0.sourceScope == .project }
      .sorted { lhs, rhs in
        lhs.fileURL.standardizedFileURL.path() < rhs.fileURL.standardizedFileURL.path()
      }

    var issues: [WorkspaceValidationIssue] = []
    let decoder = JSONDecoder()

    for session in projectSessions {
      let fileURL = session.fileURL.standardizedFileURL

      guard fileManager.fileExists(atPath: fileURL.path()) else {
        continue
      }

      let document: SessionDocument

      do {
        let data = try Data(contentsOf: fileURL)
        document = try decoder.decode(SessionDocument.self, from: data)
      } catch {
        issues.append(
          WorkspaceValidationIssue(
            entityType: .session,
            entityId: session.id,
            field: "json",
            filePath: fileURL.path(),
            message: "Failed to decode session JSON: \(error.localizedDescription)",
            severity: .error
          )
        )

        continue
      }

      let expectedFileName = "\(document.id).session.json"

      if fileURL.lastPathComponent != expectedFileName {
        issues.append(
          WorkspaceValidationIssue(
            entityType: .session,
            entityId: document.id,
            field: "id",
            filePath: fileURL.path(),
            message: "Session id does not match filename.",
            severity: .error
          )
        )
      }

      if !personaIDs.contains(document.personaId) {
        issues.append(
          WorkspaceValidationIssue(
            entityType: .session,
            entityId: document.id,
            field: "personaId",
            filePath: fileURL.path(),
            message: "Session personaId references missing persona id \"\(document.personaId)\".",
            severity: .error
          )
        )
      }

      if !directiveIDs.contains(document.directiveId) {
        issues.append(
          WorkspaceValidationIssue(
            entityType: .session,
            entityId: document.id,
            field: "directiveId",
            filePath: fileURL.path(),
            message: "Session directiveId references missing directive id \"\(document.directiveId)\".",
            severity: .error
          )
        )
      }

      let uniqueKitOverrideIDs = Set(
        (document.kitOverrides ?? []).map {
          $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        .filter { !$0.isEmpty }
      )
      .sorted()

      for kitID in uniqueKitOverrideIDs where !kitIDs.contains(kitID) {
        issues.append(
          WorkspaceValidationIssue(
            entityType: .session,
            entityId: document.id,
            field: "kitOverrides",
            filePath: fileURL.path(),
            message: "Session kitOverrides references missing kit id \"\(kitID)\".",
            severity: .error
          )
        )
      }
    }

    return issues
  }
}
