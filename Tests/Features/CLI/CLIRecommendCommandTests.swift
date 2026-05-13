import Foundation
import Testing

@testable import ContextCLI
@testable import ContextCore

struct CLIRecommendCommandTests {
  @Test
  func recommendSuggestsMatchingSession() {
    let root = fixtureKitRootURL()

    var status: Int32 = 0
    let output = captureStdout {
      status = PersonaKitCLI().run(arguments: [
        "personakit",
        "recommend",
        "--root",
        root.path,
        "--goal",
        "Apply SwiftUI style guide with safe refactor review",
      ])
    }

    #expect(status == 0)
    #expect(output.contains("1. senior-swiftui-engineer_apply-style"))
    #expect(output.contains("persona: Senior SwiftUI Engineer (senior-swiftui-engineer)"))
    #expect(output.contains("directive: Apply Swift + SwiftUI style guides (apply-style)"))
    #expect(output.contains("skills: codex-cli"))
    #expect(output.contains("references: swift-style-guide-reference, swiftui-style-guide-reference"))
    #expect(output.contains("stop points: Avoid unrelated refactors."))
    #expect(
      output.contains(
        "personakit contract --root \(root.path) --session senior-swiftui-engineer_apply-style"
      )
    )
    #expect(
      output.contains(
        "personakit run --root \(root.path) --session senior-swiftui-engineer_apply-style --agent <agent> -- \"<task>\""
      )
    )
  }

  @Test
  func recommendReportsNoStrongMatch() {
    let root = fixtureKitRootURL()

    var status: Int32 = 0
    let output = captureStdout {
      status = PersonaKitCLI().run(arguments: [
        "personakit",
        "recommend",
        "--root",
        root.path,
        "--goal",
        "warehouse forklift barcode",
      ])
    }

    #expect(status == 0)
    #expect(output.contains("No strong session match found."))
    #expect(output.contains("PersonaKit may not be needed for this task."))
    #expect(output.contains("personakit list --root \(root.path) sessions"))
    #expect(output.contains("personakit contract --root \(root.path) --session <id>"))
  }

  @Test
  func recommendSurfacesInvalidSessionDefinitions() throws {
    let root = try makeTempDirectory().appendingPathComponent(".personakit")
    try copyFixtureKit(to: root)

    let invalidSession = SessionFile(
      id: "broken-session",
      personaId: "missing-persona",
      directiveId: "apply-style",
      kitOverrides: nil
    )
    let sessionURL = root.appendingPathComponent("Sessions/broken-session.session.json")
    let sessionData = try JSONEncoder().encode(invalidSession)
    try sessionData.write(to: sessionURL)

    var status: Int32 = 0
    let stderrOutput = captureStderr {
      status = PersonaKitCLI().run(arguments: [
        "personakit",
        "recommend",
        "--root",
        root.path,
        "--goal",
        "Apply SwiftUI style guide",
      ])
    }

    #expect(status == 1)
    #expect(stderrOutput.contains("Invalid session definitions found."))
    #expect(stderrOutput.contains("session broken-session personaId: Missing persona id. missingId=missing-persona"))
  }

  @Test
  func recommendPrefersReviewLaneForReviewGoal() throws {
    let scopes = ScopeSet(projectScopeURL: internalAgentRootURL(), globalScopeURL: nil)
    let registry = try Registry.load(scopes: scopes)
    let sessions = try SessionFileLoader.list(scopes: scopes)

    let result = SessionRecommendationSupport.recommend(
      goal: "Review the current SwiftUI change",
      sessions: sessions,
      registry: registry
    )

    #expect(result.invalidSessions.isEmpty)
    #expect(result.recommendations.first?.sessionId == "architectural-editor-review")
  }

  @Test
  func recommendFailsWhenSessionsMissing() throws {
    let root = try makeTempDirectory().appendingPathComponent(".personakit")
    try copyFixtureKit(to: root)
    try FileManager.default.removeItem(at: root.appendingPathComponent("Sessions"))

    var status: Int32 = 0
    let stderrOutput = captureStderr {
      status = PersonaKitCLI().run(arguments: [
        "personakit",
        "recommend",
        "--root",
        root.path,
        "--goal",
        "Apply SwiftUI style guide",
      ])
    }

    #expect(status == 1)
    #expect(stderrOutput.contains("No session files found."))
  }
}
