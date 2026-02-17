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
      return nil
    }

    if availableSessionIDs.contains(currentSelectedSessionID) {
      return currentSelectedSessionID
    }

    return nil
  }

  static func unresolvedIssueBadgeText(
    issueCount: Int?
  ) -> String? {
    guard
      let issueCount,
      issueCount > 0
    else {
      return nil
    }

    return String(issueCount)
  }
}
