import ContextWorkspaceCore

struct StudioDiagnosticsIssueGroup: Equatable, Sendable, Identifiable {
  let id: String
  let entityType: WorkspaceValidationEntityType
  let entityID: String?
  let filePath: String?
  let issues: [WorkspaceValidationIssue]

  var title: String {
    if let entityID {
      return "\(entityType.rawValue.capitalized) \(entityID)"
    }

    if let filePath {
      return "\(entityType.rawValue.capitalized) \(filePath)"
    }

    return entityType.rawValue.capitalized
  }

  var issueCountText: String {
    "\(issues.count) issue\(issues.count == 1 ? "" : "s")"
  }

  var fieldSummary: String {
    let fields = Set(issues.map(\.field))
      .sorted()
      .joined(separator: ", ")

    guard !fields.isEmpty else {
      return "Fields unavailable"
    }

    return "Fields: \(fields)"
  }

  var revealIssue: WorkspaceValidationIssue? {
    issues.first { $0.filePath != nil }
  }

  var navigationIssue: WorkspaceValidationIssue {
    issues[0]
  }
}

enum StudioDiagnosticsIssueGrouping {
  static func groups(
    for issues: [WorkspaceValidationIssue]
  ) -> [StudioDiagnosticsIssueGroup] {
    let grouped = Dictionary(grouping: issues) { issue in
      groupKey(for: issue)
    }

    return grouped.keys.sorted().compactMap { key in
      guard let issues = grouped[key],
        let firstIssue = issues.first
      else {
        return nil
      }

      let sortedIssues = issues.sorted { lhs, rhs in
        if lhs.field != rhs.field {
          return lhs.field < rhs.field
        }

        if lhs.message != rhs.message {
          return lhs.message < rhs.message
        }

        return (lhs.filePath ?? "") < (rhs.filePath ?? "")
      }

      return StudioDiagnosticsIssueGroup(
        id: key,
        entityType: firstIssue.entityType,
        entityID: firstIssue.entityId,
        filePath: firstIssue.filePath,
        issues: sortedIssues
      )
    }
  }

  private static func groupKey(
    for issue: WorkspaceValidationIssue
  ) -> String {
    if let entityID = issue.entityId {
      return [
        issue.entityType.rawValue,
        entityID,
      ].joined(separator: "::")
    }

    return [
      issue.entityType.rawValue,
      issue.filePath ?? "",
    ].joined(separator: "::")
  }
}
