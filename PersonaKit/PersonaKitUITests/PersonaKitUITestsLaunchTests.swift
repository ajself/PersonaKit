import XCTest

final class PersonaKitUITestsLaunchTests: XCTestCase {
  override class var runsForEachTargetApplicationUIConfiguration: Bool {
    true
  }

  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  @MainActor
  func testLaunchScreenshot() throws {
    let app = XCUIApplication()
    app.launchArguments.append("--no-auto-activate")
    app.launch()

    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = "PersonaKit Studio Launch"
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}
