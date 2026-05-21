import ContextCore
import Testing

@testable import ContextCLI

struct CLIResolutionErrorFormattingTests {
  @Test
  func invalidSessionFormattingUsesSessionIDAndExpectedPath() {
    let formattedError = CLIHelpers.formatResolutionError(
      .invalidSession(
        sessionId: "broken",
        expectedPath: "Sessions/broken.session.json",
        message: "Failed to decode session file for broken."
      )
    )

    #expect(
      formattedError
        == "session broken session: Invalid session file at Sessions/broken.session.json: Failed to decode session file for broken. sessionId=broken expectedPath=Sessions/broken.session.json"
    )
  }
}
