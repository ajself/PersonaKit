/// Preview feature behaviors for ``AppModel``.
extension AppModel {
  /// Updates the JSON preview text and schedules formatting.
  func updatePreviewJSON(_ text: String) {
    updateJSONPreview(text, scheduleFormat: true)
  }

  /// Marks the preview for recomputation at the end of an update cycle.
  func requestPreviewRecompute() {
    preview.needsRecompute = true
  }

  /// Runs preview recomputation when marked by feature updates.
  func handlePreviewRecomputeIfNeeded() {
    guard preview.needsRecompute else { return }
    preview.needsRecompute = false
    recomputePreview()
  }
}
