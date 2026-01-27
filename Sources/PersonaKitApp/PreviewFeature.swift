/// Preview feature state.
enum PreviewFeature {
  /// Preview-specific UI state.
  struct State {
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

}
