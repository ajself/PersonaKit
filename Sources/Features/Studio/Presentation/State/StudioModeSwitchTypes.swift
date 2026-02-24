import SwiftUI

/// Shared descriptor for segment items shown in Studio mode-switch rails.
struct StudioModeSwitchItem<ID: Hashable>: Identifiable {
  let id: ID
  let title: String
  let systemImage: String
  let badgeText: String?
  let accessibilityHint: String?
}
