import Foundation

/// The available preview panels for the detail view.
enum PreviewPanel: String, CaseIterable, Identifiable {
  case prompt = "Prompt"
  case json = "JSON"

  /// Stable identifier for SwiftUI list and picker usage.
  var id: String { rawValue }
}
