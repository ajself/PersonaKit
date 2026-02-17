import ContextWorkspaceCore
import Foundation

/// Package-scoped state for session dependency map loading and error handling.
package struct WorkspaceSessionMapState: Sendable {
  package private(set) var requestKey: String?
  package private(set) var map: WorkspaceSessionMap?
  package private(set) var errorMessage: String?
  package private(set) var isLoading: Bool

  package init(
    requestKey: String? = nil,
    map: WorkspaceSessionMap? = nil,
    errorMessage: String? = nil,
    isLoading: Bool = false
  ) {
    self.requestKey = requestKey
    self.map = map
    self.errorMessage = errorMessage
    self.isLoading = isLoading
  }

  package mutating func beginLoading(requestKey: String) {
    self.requestKey = requestKey
    map = nil
    errorMessage = nil
    isLoading = true
  }

  package mutating func setLoadedMap(_ map: WorkspaceSessionMap) {
    self.map = map
    errorMessage = nil
    isLoading = false
  }

  package mutating func setFailedMap(message: String) {
    map = nil
    errorMessage = message
    isLoading = false
  }

  package mutating func clear() {
    requestKey = nil
    map = nil
    errorMessage = nil
    isLoading = false
  }
}
