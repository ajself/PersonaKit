import XCTest

final class PersonaKitUITests: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  @MainActor
  func testLaunchShowsStudioEmptyState() throws {
    let app = XCUIApplication()
    app.launchArguments.append("--no-auto-activate")
    app.launch()

    XCTAssertTrue(app.staticTexts["No Workspace Selected"].waitForExistence(timeout: 5))
  }

  @MainActor
  func testLaunchPerformance() throws {
    measure(metrics: [XCTApplicationLaunchMetric()]) {
      let app = XCUIApplication()
      app.launchArguments.append("--no-auto-activate")
      app.launch()
    }
  }
}
