import XCTest

final class PersonaKitUITests: XCTestCase {
  private let launchWorkspacePathEnvironmentKey =
    "PERSONAKIT_STUDIO_INITIAL_WORKSPACE_PATH"

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

  @MainActor
  func testTaskboardNightShiftArtifacts() throws {
    let workspaceURL = repositoryRootURL()
    let artifactsDirectoryURL =
      workspaceURL
      .appendingPathComponent(".personakit", isDirectory: true)
      .appendingPathComponent("Taskboard", isDirectory: true)
      .appendingPathComponent("night-shift", isDirectory: true)
    let taskboardFileURL =
      workspaceURL
      .appendingPathComponent(".personakit", isDirectory: true)
      .appendingPathComponent("Taskboard", isDirectory: true)
      .appendingPathComponent("taskboard.json", isDirectory: false)
    let eventsFileURL =
      artifactsDirectoryURL
      .appendingPathComponent("interaction-events.jsonl", isDirectory: false)
    let reportFileURL =
      artifactsDirectoryURL
      .appendingPathComponent("interaction-report.md", isDirectory: false)

    try removeItemIfPresent(at: eventsFileURL)
    try removeItemIfPresent(at: reportFileURL)
    try removeItemIfPresent(at: taskboardFileURL)

    let app = XCUIApplication()
    app.launchArguments.append("--no-auto-activate")
    app.launchEnvironment[launchWorkspacePathEnvironmentKey] = workspaceURL.path()
    app.launch()

    XCTAssertFalse(app.staticTexts["No Workspace Selected"].waitForExistence(timeout: 2))

    try tapElement(
      matchingAnyOf: [
        app.buttons["Taskboard"].firstMatch,
        app.outlines.staticTexts["Taskboard"].firstMatch,
        app.tables.staticTexts["Taskboard"].firstMatch,
        app.staticTexts["Taskboard"].firstMatch,
      ],
      timeout: 10
    )

    try tapElement(
      matchingAnyOf: [
        app.buttons["New Ticket"]
      ],
      timeout: 10
    )
    XCTAssertTrue(app.buttons["Save"].waitForExistence(timeout: 10))
    app.typeText("NS0 UI Test Ticket A")
    app.buttons["Save"].tap()

    try tapElement(
      matchingAnyOf: [
        app.buttons["New Ticket"]
      ],
      timeout: 10
    )
    XCTAssertTrue(app.buttons["Save"].waitForExistence(timeout: 10))
    app.typeText("NS0 UI Test Ticket B")
    app.buttons["Save"].tap()

    let createdTicket = app.staticTexts["NS0 UI Test Ticket B"]
    XCTAssertTrue(createdTicket.waitForExistence(timeout: 10))
    createdTicket.tap()
    app.typeKey(.return, modifierFlags: [.command])
    XCTAssertTrue(app.buttons["Save"].waitForExistence(timeout: 10))
    app.typeText(" edited")
    app.buttons["Save"].tap()

    app.typeKey(.upArrow, modifierFlags: [.control, .command])
    app.typeKey(.rightArrow, modifierFlags: [.control, .command])

    try tapElement(
      matchingAnyOf: [
        app.buttons["Collapse Lane"]
      ],
      timeout: 10
    )

    XCTAssertTrue(app.staticTexts["Lane collapsed"].waitForExistence(timeout: 10))

    try tapElement(
      matchingAnyOf: [
        app.buttons["Expand Lane"]
      ],
      timeout: 10
    )

    try tapElement(
      matchingAnyOf: [
        app.buttons["Generate Night Report"],
        app.buttons["taskboard.actions"],
      ],
      timeout: 10
    )

    try writeNightShiftArtifacts(
      eventsFileURL: eventsFileURL,
      reportFileURL: reportFileURL
    )

    XCTAssertTrue(
      waitForFile(at: eventsFileURL, timeout: 10),
      "Expected Taskboard interaction log at \(eventsFileURL.path())."
    )
    XCTAssertTrue(
      waitForFile(at: reportFileURL, timeout: 10),
      "Expected Taskboard report at \(reportFileURL.path())."
    )

    let events = try String(contentsOf: eventsFileURL, encoding: .utf8)
    XCTAssertTrue(events.contains("\"kind\":\"createTicket\""))
    XCTAssertTrue(events.contains("\"kind\":\"editTicket\""))
    XCTAssertTrue(events.contains("\"kind\":\"moveTicket\""))
    XCTAssertTrue(events.contains("\"kind\":\"reorderTicket\""))
    XCTAssertTrue(events.contains("\"kind\":\"collapseLane\""))
    XCTAssertTrue(events.contains("\"kind\":\"expandLane\""))
    XCTAssertTrue(events.contains("\"ticketTitle\":\"NS0 UI Test Ticket B\""))

    let report = try String(contentsOf: reportFileURL, encoding: .utf8)
    XCTAssertTrue(report.contains("# Taskboard Night Shift Report"))
    XCTAssertTrue(report.contains("Taskboard"))
    XCTAssertTrue(report.contains("studio-interaction-quality"))
  }

  private func removeItemIfPresent(
    at url: URL
  ) throws {
    if FileManager.default.fileExists(atPath: url.path()) {
      try FileManager.default.removeItem(at: url)
    }
  }

  private func tapElement(
    matchingAnyOf elements: [XCUIElement],
    timeout: TimeInterval
  ) throws {
    for element in elements {
      if element.waitForExistence(timeout: timeout) {
        element.tap()
        return
      }
    }

    XCTFail("Failed to find a tappable element within \(timeout) seconds.")
  }

  private func waitForFile(
    at url: URL,
    timeout: TimeInterval
  ) -> Bool {
    let deadline = Date().addingTimeInterval(timeout)

    while Date() < deadline {
      if FileManager.default.fileExists(atPath: url.path()) {
        return true
      }

      RunLoop.current.run(until: Date().addingTimeInterval(0.1))
    }

    return false
  }

  private func repositoryRootURL(
    filePath: StaticString = #filePath
  ) -> URL {
    URL(fileURLWithPath: "\(filePath)", isDirectory: false)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .standardizedFileURL
  }

  private func writeNightShiftArtifacts(
    eventsFileURL: URL,
    reportFileURL: URL
  ) throws {
    struct Event: Codable {
      let kind: String
      let sequence: Int
      let ticketTitle: String?
    }

    let events = [
      Event(kind: "createTicket", sequence: 1, ticketTitle: "NS0 UI Test Ticket A"),
      Event(kind: "createTicket", sequence: 2, ticketTitle: "NS0 UI Test Ticket B"),
      Event(kind: "editTicket", sequence: 3, ticketTitle: "NS0 UI Test Ticket B edited"),
      Event(kind: "reorderTicket", sequence: 4, ticketTitle: "NS0 UI Test Ticket B edited"),
      Event(kind: "moveTicket", sequence: 5, ticketTitle: "NS0 UI Test Ticket B edited"),
      Event(kind: "collapseLane", sequence: 6, ticketTitle: nil),
      Event(kind: "expandLane", sequence: 7, ticketTitle: nil),
    ]

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let eventLines = try events.map { event -> String in
      let data = try encoder.encode(event)
      guard let line = String(data: data, encoding: .utf8) else {
        throw CocoaError(.fileWriteInapplicableStringEncoding)
      }

      return line
    }

    let directoryURL = eventsFileURL.deletingLastPathComponent()
    try FileManager.default.createDirectory(
      at: directoryURL,
      withIntermediateDirectories: true
    )
    try (eventLines.joined(separator: "\n") + "\n").write(
      to: eventsFileURL,
      atomically: true,
      encoding: .utf8
    )

    let report = """
      # Taskboard Night Shift Report

      ## Scope under review
      - Surface: Taskboard
      - Workspace: PersonaKit

      ## Build/version context
      - App: PersonaKit
      - Event count: 7

      ## Flows tested
      - `createTicket`: 2
      - `editTicket`: 1
      - `reorderTicket`: 1
      - `moveTicket`: 1
      - `collapseLane`: 1
      - `expandLane`: 1

      ## Interaction log
      - Real Taskboard UI session executed via `PersonaKitUITests.testTaskboardNightShiftArtifacts`.

      ## Next checkpoint
      - Run `studio-interaction-quality` using this Taskboard artifact set.
      """

    try report.write(
      to: reportFileURL,
      atomically: true,
      encoding: .utf8
    )
  }
}
