import ContextCore
import Foundation

extension WorkspaceLibraryFeatureModel {
  func beginRequest() -> Int {
    state.beginRequest()
  }

  func completeRequest(
    requestID: Int,
    expectedWorkspaceURL: URL?,
    currentWorkspaceURL: URL?
  ) -> Bool {
    state.completeRequest(
      requestID: requestID,
      currentWorkspaceURL: currentWorkspaceURL,
      expectedWorkspaceURL: expectedWorkspaceURL
    )
  }

  func requiredWorkspaceURL(_ workspaceURL: URL?) throws -> URL {
    guard let workspaceURL else {
      throw WorkspaceSnapshotBuildError(
        message: "No workspace is currently selected."
      )
    }

    return workspaceURL.standardizedFileURL
  }

  func setAction(
    message: String,
    isError: Bool
  ) {
    state.setAction(
      message: message,
      isError: isError
    )
  }
}
