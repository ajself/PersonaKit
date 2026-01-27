/// Preview feature handling for ``AppStore``.
extension AppStore {
  /// Routes preview actions to state mutations.
  func handlePreview(_ action: PreviewFeature.Action) {
    switch action {
    case .setJSONPreview(let text):
      updateJSONPreview(text, scheduleFormat: true)
    }
  }

  /// Marks the preview for recomputation at the end of the send cycle.
  func requestPreviewRecompute() {
    state.preview.needsRecompute = true
  }

  /// Runs preview recomputation when marked by feature reducers.
  func handlePreviewRecomputeIfNeeded() {
    guard state.preview.needsRecompute else { return }
    state.preview.needsRecompute = false
    recomputePreview()
  }
}
