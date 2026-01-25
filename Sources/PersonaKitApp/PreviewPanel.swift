import Foundation

enum PreviewPanel: String, CaseIterable, Identifiable {
  case prompt = "Prompt"
  case json = "JSON"

  var id: String { rawValue }
}
