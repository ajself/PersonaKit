import Foundation
import StudioFoundation
import Testing

struct WorkspaceLibraryActionStateTests {
  @Test
  func completeRequestAcceptsEquivalentStandardizedWorkspaceURLs() {
    var state = WorkspaceLibraryActionState()
    let requestID = state.beginRequest()

    let expectedWorkspaceURL = URL(fileURLWithPath: "/tmp/Workspace")
    let currentWorkspaceURL = URL(fileURLWithPath: "/tmp/Workspace/../Workspace")

    let didComplete = state.completeRequest(
      requestID: requestID,
      currentWorkspaceURL: currentWorkspaceURL,
      expectedWorkspaceURL: expectedWorkspaceURL
    )

    #expect(didComplete)
    #expect(!state.isLoadingEditor)
  }

  @Test
  func completeRequestRejectsDifferentWorkspaceURLs() {
    var state = WorkspaceLibraryActionState()
    let requestID = state.beginRequest()

    let didComplete = state.completeRequest(
      requestID: requestID,
      currentWorkspaceURL: URL(fileURLWithPath: "/tmp/WorkspaceA"),
      expectedWorkspaceURL: URL(fileURLWithPath: "/tmp/WorkspaceB")
    )

    #expect(!didComplete)
    #expect(state.isLoadingEditor)
  }

  @Test
  func completeRequestRejectsStaleRequestID() {
    var state = WorkspaceLibraryActionState()
    let requestID = state.beginRequest()
    let _ = state.beginRequest()

    let didComplete = state.completeRequest(
      requestID: requestID,
      currentWorkspaceURL: URL(fileURLWithPath: "/tmp/Workspace"),
      expectedWorkspaceURL: URL(fileURLWithPath: "/tmp/Workspace")
    )

    #expect(!didComplete)
    #expect(state.isLoadingEditor)
  }
}
