import Observation

/// Preview feature state owner.
@MainActor
@Observable
final class PreviewModel {
  var promptPreview: String
  var jsonPreview: String
  var needsRecompute: Bool

  init(
    promptPreview: String = "",
    jsonPreview: String = "",
    needsRecompute: Bool = false
  ) {
    self.promptPreview = promptPreview
    self.jsonPreview = jsonPreview
    self.needsRecompute = needsRecompute
  }
}
