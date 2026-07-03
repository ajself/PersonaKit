import ContextWorkspaceCore
import Foundation

struct StudioWorkspaceCount: Equatable, Sendable, Identifiable {
  let id: String
  let title: String
  let count: Int
}

enum StudioWorkspaceValidationStatus: Equatable, Sendable {
  case clean
  case issues(Int)
  case validating
  case failed
  case notRun

  var title: String {
    switch self {
    case .clean:
      return "No issues"
    case .issues(let count):
      return "\(count) issue\(count == 1 ? "" : "s")"
    case .validating:
      return "Validating"
    case .failed:
      return "Validation failed"
    case .notRun:
      return "Not validated"
    }
  }

  static func status(
    validation: WorkspaceValidationSnapshot,
    validationErrorMessage: String?
  ) -> StudioWorkspaceValidationStatus {
    if validationErrorMessage != nil {
      return .failed
    }

    if validation.summary == WorkspaceValidationSnapshot.empty.summary {
      return .notRun
    }

    if validation.summary == "Validating workspace..." {
      return .validating
    }

    if validation.issues.isEmpty {
      return .clean
    }

    return .issues(validation.issues.count)
  }
}

struct StudioWorkspaceSummaryState: Equatable, Sendable {
  let workspacePath: String
  let validationStatus: StudioWorkspaceValidationStatus
  let counts: [StudioWorkspaceCount]

  init(
    workspaceURL: URL,
    snapshot: WorkspaceSnapshot,
    validation: WorkspaceValidationSnapshot,
    validationErrorMessage: String?,
    globalLibraryConnected: Bool = true
  ) {
    workspacePath = workspaceURL.standardizedFileURL.path()
    // While the global library is disconnected, fold unresolved-reference issues out of
    // the headline count so it matches the Validation Results panel (which shows the
    // Connect banner instead of those false errors).
    let countedValidation: WorkspaceValidationSnapshot

    if globalLibraryConnected {
      countedValidation = validation
    } else {
      countedValidation = WorkspaceValidationSnapshot(
        summary: validation.summary,
        issues: validation.issues.filter { !$0.referencesUnresolvedID }
      )
    }

    validationStatus = StudioWorkspaceValidationStatus.status(
      validation: countedValidation,
      validationErrorMessage: validationErrorMessage
    )
    counts = [
      StudioWorkspaceCount(id: "sessions", title: "Sessions", count: snapshot.sessions.count),
      StudioWorkspaceCount(id: "personas", title: "Personas", count: snapshot.personas.count),
      StudioWorkspaceCount(id: "directives", title: "Directives", count: snapshot.directives.count),
      StudioWorkspaceCount(id: "kits", title: "Kits", count: snapshot.kits.count),
      StudioWorkspaceCount(id: "skills", title: "Skills", count: snapshot.skills.count),
    ]
  }

  var workspaceDisplayName: String {
    let name = URL(fileURLWithPath: workspacePath).lastPathComponent

    guard !name.isEmpty else {
      return workspacePath
    }

    return name
  }

  var chipTitle: String {
    workspaceDisplayName
  }

  var accessibilitySummary: String {
    let countText =
      counts
      .map { "\($0.title) \($0.count)" }
      .joined(separator: ", ")

    return [
      "Workspace Status",
      workspacePath,
      "Validation \(validationStatus.title)",
      countText,
    ].joined(separator: ", ")
  }
}
