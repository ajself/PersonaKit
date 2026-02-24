import SwiftUI

/// Semantic grouping for action placement inside the shared Studio action bar.
enum StudioActionGroup: Sendable {
  case primary
  case selection
  case destructive
}

/// Visual role for a Studio action item.
enum StudioActionRole: Sendable {
  case primary
  case standard
  case destructive
}

/// Shared action descriptor used by Studio action bars.
struct StudioActionItem: Identifiable {
  let id: String
  let group: StudioActionGroup
  let title: String
  let systemImage: String
  let role: StudioActionRole
  let isEnabled: Bool
  let action: () -> Void
}
