import Foundation

/// Package-scoped state for session preview loading, errors, and naming.
package struct WorkspaceSessionPreviewState: Sendable {
  package private(set) var previewSessionID: String?
  package private(set) var preview: String
  package private(set) var errorMessage: String?
  package private(set) var isLoading: Bool

  package init(
    previewSessionID: String? = nil,
    preview: String = "",
    errorMessage: String? = nil,
    isLoading: Bool = false
  ) {
    self.previewSessionID = previewSessionID
    self.preview = preview
    self.errorMessage = errorMessage
    self.isLoading = isLoading
  }

  package mutating func beginLoading(sessionID: String) {
    previewSessionID = sessionID
    preview = ""
    errorMessage = nil
    isLoading = true
  }

  package mutating func setLoadedPreview(_ preview: String) {
    self.preview = preview
    errorMessage = nil
    isLoading = false
  }

  package mutating func setPreview(_ preview: String) {
    self.preview = preview
  }

  package mutating func setFailedPreview(message: String) {
    preview = ""
    errorMessage = message
    isLoading = false
  }

  package mutating func clear() {
    previewSessionID = nil
    preview = ""
    errorMessage = nil
    isLoading = false
  }

  package func defaultFilename() -> String {
    guard let previewSessionID else {
      return "session-preview.md"
    }

    return "\(previewSessionID).md"
  }
}
