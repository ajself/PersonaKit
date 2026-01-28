import Dependencies
import PersonaKitCore

/// Composer feature behaviors for ``AppModel``.
extension AppModel {
  /// Requests focus for a composer section by key.
  func requestComposerFocus(sectionKey: String) {
    @Dependency(\.uuid) var uuid
    composer.focusRequest = ComposerModel.FocusRequest(id: uuid(), sectionKey: sectionKey)
  }

  /// Updates the selected persona and schedules preview recompute.
  func selectPersona(id: String?) {
    composer.selectedPersonaID = id
    requestPreviewRecompute()
    handlePreviewRecomputeIfNeeded()
  }

  /// Updates the composed prompt values and schedules preview recompute.
  func updateComposerValue(key: String, value: String) {
    composer.composerValues[key] = value
    requestPreviewRecompute()
    handlePreviewRecomputeIfNeeded()
  }
}
