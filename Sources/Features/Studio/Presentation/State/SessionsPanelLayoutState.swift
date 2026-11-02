import Foundation

enum SessionsDetailMode: String, CaseIterable, Sendable {
  case preview
  case map

  var title: String {
    switch self {
    case .preview:
      return "Handoff"
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
      return "Shows the handoff context for the selected session."
    case .map:
      return "Shows the selected session's dependencies and resolution issues."
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

  static func workstreamMetadataLine(
    workstreamID: String,
    phase: String
  ) -> String {
    "Workstream \(workstreamID) · Phase \(phase)"
  }

  /// The inspector's map status. The map loads only in Map mode, so Handoff mode points there.
  static func inspectorMapStatusText(
    detailMode: SessionsDetailMode,
    isLoading: Bool,
    mapIsFullyResolved: Bool?,
    unresolvedIssueCount: Int?,
    loadFailed: Bool
  ) -> String {
    if isLoading || mapIsFullyResolved != nil {
      return mapHealthText(
        isLoading: isLoading,
        mapIsFullyResolved: mapIsFullyResolved,
        unresolvedIssueCount: unresolvedIssueCount
      )
    }

    if loadFailed {
      return "Couldn't load"
    }

    if detailMode == .preview {
      return "Open Map to check (⌘2)"
    }

    return mapHealthText(isLoading: false, mapIsFullyResolved: nil, unresolvedIssueCount: nil)
  }

  static func mapHealthText(
    isLoading: Bool,
    mapIsFullyResolved: Bool?,
    unresolvedIssueCount: Int?
  ) -> String {
    if isLoading {
      return "Refreshing…"
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
