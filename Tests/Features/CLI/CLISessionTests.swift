import Foundation
import Testing

@testable import ContextCLI
@testable import ContextCore

struct CLISessionTests {
  @Test
  func exportViaSessionMatchesGoldenFile() throws {
    let root = fixtureKitRootURL()
    let fixtureURL = fixturesRootURL()
      .appendingPathComponent("expected/export_senior-swiftui-engineer_apply-style.md")
    let expected = try String(contentsOf: fixtureURL, encoding: .utf8)

    var status: Int32 = 0
    let output = captureStdout {
      status = PersonaKitCLI().run(arguments: [
        "personakit",
        "export",
        "--root",
        root.path,
        "--session",
        "senior-swiftui-engineer_apply-style",
      ])
    }

    #expect(status == 0)
    #expect(normalizedTrailingNewline(output) == normalizedTrailingNewline(expected))
  }

  @Test
  func graphViaSessionMatchesGoldenFile() throws {
    let root = fixtureKitRootURL()
    let fixtureURL = fixturesRootURL()
      .appendingPathComponent("expected/graph_senior-swiftui-engineer_apply-style.txt")
    let expected = try String(contentsOf: fixtureURL, encoding: .utf8)

    var status: Int32 = 0
    let output = captureStdout {
      status = PersonaKitCLI().run(arguments: [
        "personakit",
        "graph",
        "--root",
        root.path,
        "--session",
        "senior-swiftui-engineer_apply-style",
      ])
    }

    #expect(status == 0)
    #expect(normalizedTrailingNewline(output) == normalizedTrailingNewline(expected))
  }

  @Test
  func contractViaSessionReturnsStructuredJSON() throws {
    let root = fixtureKitRootURL()

    var status: Int32 = 0
    let output = captureStdout {
      status = PersonaKitCLI().run(arguments: [
        "personakit",
        "contract",
        "--root",
        root.path,
        "--session",
        "senior-swiftui-engineer_apply-style",
        "--check-skills",
        "codex-cli,missing-skill",
      ])
    }

    #expect(status == 0)

    let data = try #require(output.data(using: .utf8))
    let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

    #expect(object["personaId"] as? String == "senior-swiftui-engineer")
    #expect(object["directiveId"] as? String == "apply-style")
    #expect(object["authorizedSkillIds"] as? [String] == ["codex-cli"])
    #expect(object["undeclaredRequestedSkillIds"] as? [String] == ["missing-skill"])
    #expect(object["isAuthorized"] as? Bool == false)
  }

  @Test
  func resolveReferencesViaSessionReturnsStructuredJSON() throws {
    let root = fixtureKitRootURL()

    var status: Int32 = 0
    let output = captureStdout {
      status = PersonaKitCLI().run(arguments: [
        "personakit",
        "resolve-references",
        "--root",
        root.path,
        "--session",
        "senior-swiftui-engineer_apply-style",
        "--target-path",
        "Sources/FooView.swift",
        "--reference-tag",
        "swiftui",
      ])
    }

    #expect(status == 0)

    let data = try #require(output.data(using: .utf8))
    let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    let matchedReferences = try #require(object["matchedReferences"] as? [[String: Any]])
    #expect(matchedReferences.map { $0["id"] as? String } == [
      "swift-style-guide-reference",
      "swiftui-style-guide-reference",
    ])
  }

  @Test
  func exportRequiresDirectiveWhenPersonaProvided() {
    var status: Int32 = 0
    let stderrOutput = captureStderr {
      status = PersonaKitCLI().run(arguments: [
        "personakit",
        "export",
        "--persona",
        "senior-swiftui-engineer",
      ])
    }

    #expect(status == 1)
    #expect(stderrOutput.contains("Error:"))
  }

  @Test
  func exportRejectsMixingSessionWithPersonaDirectiveFlags() {
    var status: Int32 = 0
    let stderrOutput = captureStderr {
      status = PersonaKitCLI().run(arguments: [
        "personakit",
        "export",
        "--session",
        "senior-swiftui-engineer_apply-style",
        "--persona",
        "senior-swiftui-engineer",
        "--directive",
        "apply-style",
      ])
    }

    #expect(status == 1)
    #expect(stderrOutput.contains("Error:"))
  }
}
