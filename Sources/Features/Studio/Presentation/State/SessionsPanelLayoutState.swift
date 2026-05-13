import Foundation

enum SessionsDetailMode: String, CaseIterable, Sendable {
  case preview
  case map

  var title: String {
    switch self {
    case .preview:
      return "Preview"
    case .map:
      return "Map"
    }
  }

  var systemImage: String {
    switch self {
    case .preview:
      return "doc.text.magnifyingglass"
    case .map:
      return "point.3.connected.trianglepath.dotted"
    }
  }

  var accessibilityHint: String {
    switch self {
    case .preview:
      return "Shows resolved export text for the selected session."
    case .map:
      return "Shows dependency relationships and resolution issues for the selected session."
    }
  }
}

enum SessionsPanelLayoutState {
  static func resolvedDetailMode(
    persistedRawValue: String?
  ) -> SessionsDetailMode {
    guard
      let persistedRawValue,
      let mode = SessionsDetailMode(rawValue: persistedRawValue)
    else {
      return .preview
    }

    return mode
  }

  static func persistedRawValue(
    for mode: SessionsDetailMode
  ) -> String {
    mode.rawValue
  }

  static func reconciledSelection(
    currentSelectedSessionID: String?,
    availableSessionIDs: [String]
  ) -> String? {
    guard let currentSelectedSessionID else {
      return availableSessionIDs.first
    }

    if availableSessionIDs.contains(currentSelectedSessionID) {
      return currentSelectedSessionID
    }

    return nil
  }

  static func unresolvedIssueBadgeText(
    issueCount: Int?
  ) -> String? {
    guard let issueCount, issueCount > 0 else {
      return nil
    }

    return String(issueCount)
  }

  static func expectedSessionMapRequestKey(
    for selectedSessionID: String
  ) -> String {
    return "session:\(selectedSessionID)"
  }

  static func unresolvedIssueBadgeText(
    issueCount: Int?,
    mapRequestKey: String,
    selectedSessionID: String
  ) -> String? {
    guard mapRequestKey == expectedSessionMapRequestKey(for: selectedSessionID) else {
      return nil
    }

    return unresolvedIssueBadgeText(
      issueCount: issueCount
    )
  }

  static func personaMetadataLine(
    personaID: String
  ) -> String {
    "persona: \(personaID)"
  }

  static func directiveMetadataLine(
    directiveID: String
  ) -> String {
    "directive: \(directiveID)"
  }

  static func workstreamMetadataLine(
    workstreamID: String,
    phase: String
  ) -> String {
    "workstream: \(workstreamID) · phase: \(phase)"
  }

  static func mapHealthText(
    isLoading: Bool,
    mapIsFullyResolved: Bool?,
    unresolvedIssueCount: Int?
  ) -> String {
    if isLoading {
      return "Refreshing..."
    }

    guard let mapIsFullyResolved else {
      return "Unavailable"
    }

    if mapIsFullyResolved {
      return "Resolved"
    }

    return unresolvedIssueSummary(
      issueCount: unresolvedIssueCount ?? 0
    )
  }

  static func unresolvedIssueSummary(
    issueCount: Int
  ) -> String {
    "\(issueCount) issue\(issueCount == 1 ? "" : "s")"
  }
}
