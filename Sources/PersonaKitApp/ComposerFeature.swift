import Foundation

/// Composer feature state.
enum ComposerFeature {
  /// A focus request that targets a specific composer section by key.
  struct FocusRequest: Equatable {
    let id: UUID
    let sectionKey: String
  }

  /// Composer-specific UI state.
  struct State {
    var selectedPersonaID: String?
    var composerValues: [String: String]
    var focusRequest: FocusRequest?

    init(
      selectedPersonaID: String? = nil,
      composerValues: [String: String] = [:],
      focusRequest: FocusRequest? = nil
    ) {
      self.selectedPersonaID = selectedPersonaID
      self.composerValues = composerValues
      self.focusRequest = focusRequest
    }
  }

}
