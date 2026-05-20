/// Stable mode for Studio inspector content.
enum StudioInspectorMode: String, CaseIterable, Sendable {
  case primary
  case help

  static let storageKey = "studio.inspector.mode"

  static func resolved(
    rawValue: String
  ) -> StudioInspectorMode {
    StudioInspectorMode(rawValue: rawValue) ?? .primary
  }
}
