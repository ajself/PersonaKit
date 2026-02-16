import Foundation

/// Package-scoped state machine for Studio library action request lifecycle.
package struct WorkspaceLibraryActionState: Sendable {
  package private(set) var requestID: Int
  package private(set) var message: String?
  package private(set) var isError: Bool
  package private(set) var isLoadingEditor: Bool

  package init(
    requestID: Int = 0,
    message: String? = nil,
    isError: Bool = false,
    isLoadingEditor: Bool = false
  ) {
    self.requestID = requestID
    self.message = message
    self.isError = isError
    self.isLoadingEditor = isLoadingEditor
  }

  @discardableResult
  package mutating func beginRequest() -> Int {
    requestID += 1
    isLoadingEditor = true
    message = nil
    isError = false

    return requestID
  }

  package mutating func completeRequest(
    requestID: Int,
    currentWorkspaceURL: URL?,
    expectedWorkspaceURL: URL?
  ) -> Bool {
    guard self.requestID == requestID else {
      return false
    }

    let currentWorkspace = currentWorkspaceURL?.standardizedFileURL
    let expectedWorkspace = expectedWorkspaceURL?.standardizedFileURL

    guard currentWorkspace == expectedWorkspace else {
      return false
    }

    isLoadingEditor = false
    return true
  }

  package mutating func invalidateRequests() {
    requestID += 1
    isLoadingEditor = false
  }

  package mutating func reset() {
    message = nil
    isError = false
    isLoadingEditor = false
  }

  package mutating func setAction(
    message: String,
    isError: Bool
  ) {
    self.message = message
    self.isError = isError
  }
}
