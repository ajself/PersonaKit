import SwiftUI

/// What a menu command can ask of one Studio window. The focused window publishes its own, so a command
/// changes that window and leaves the others alone.
@MainActor
struct StudioWindowActions {
  let navigate: @MainActor (StudioNavigationTarget) -> Void
  let presentAgentSetup: @MainActor () -> Void
}

extension FocusedValues {
  /// The focused Studio window's actions; nil while no Studio window is focused.
  @Entry var studioWindowActions: StudioWindowActions?
}
