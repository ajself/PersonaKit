/// Composer feature handling for ``AppStore``.
extension AppStore {
  /// Routes composer actions to state mutations.
  func handleComposer(_ action: ComposerFeature.Action) {
    switch action {
    case .requestFocus(let sectionKey):
      state.composer.focusRequest = ComposerFeature.FocusRequest(id: uuid(), sectionKey: sectionKey)
    case .setSelectedPersonaID(let id):
      state.composer.selectedPersonaID = id
      requestPreviewRecompute()
    case .setComposerValue(let key, let value):
      state.composer.composerValues[key] = value
      requestPreviewRecompute()
    }
  }
}
