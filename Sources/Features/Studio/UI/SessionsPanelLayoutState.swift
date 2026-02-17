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
}
