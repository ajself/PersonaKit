import ContextCore
import Testing

@testable import ContextMCP

struct MCPResolutionErrorFormattingTests {
  @Test
  func invalidSessionFormattingUsesSessionIDAndExpectedPath() {
    let formattedError = MCPInternalSupport.formatResolutionError(
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
