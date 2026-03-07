import ContextCore
import Foundation
import MCP
import Testing

@testable import ContextMCP

struct MCPToolTests {
  @Test
  func toolListIsDeterministic() {
    let scopes = ScopeSet(projectScopeURL: fixtureKitRootURL(), globalScopeURL: nil)
    let service = MCPToolService(scopes: scopes)

    let tools = service.listTools()

    #expect(
      tools.map(\.name) == [
        "personakit_compare_entities",
        "personakit_explain_entity",
        "personakit_export",
        "personakit_graph",
        "personakit_recommend_session",
        "personakit_trace_session",
        "personakit_validate",
      ]
    )
  }

  @Test
  func toolCallExportMatchesFixture() throws {
    let scopes = ScopeSet(projectScopeURL: fixtureKitRootURL(), globalScopeURL: nil)
    let service = MCPToolService(scopes: scopes)

    let result = try service.callTool(
      name: "personakit_export",
      arguments: [
        "personaId": "senior-swiftui-engineer",
        "directiveId": "apply-style",
      ]
    )

    guard let output = firstText(result) else {
      #expect(Bool(false))
      return
    }

    let fixtureURL = fixturesRootURL()
      .appendingPathComponent("expected/export_senior-swiftui-engineer_apply-style.md")
    let expected = try String(contentsOf: fixtureURL, encoding: .utf8)

    #expect(normalizedTrailingNewline(output) == normalizedTrailingNewline(expected))
  }

  @Test
  func toolCallGraphMatchesFixture() throws {
    let scopes = ScopeSet(projectScopeURL: fixtureKitRootURL(), globalScopeURL: nil)
    let service = MCPToolService(scopes: scopes)

    let result = try service.callTool(
      name: "personakit_graph",
      arguments: [
        "personaId": "senior-swiftui-engineer",
        "directiveId": "apply-style",
      ]
    )

    guard let output = firstText(result) else {
      #expect(Bool(false))
      return
    }

    let fixtureURL = fixturesRootURL()
      .appendingPathComponent("expected/graph_senior-swiftui-engineer_apply-style.txt")
    let expected = try String(contentsOf: fixtureURL, encoding: .utf8)

    #expect(normalizedTrailingNewline(output) == normalizedTrailingNewline(expected))
  }

  @Test
  func explainEntityToolReturnsPersonaLinks() throws {
    let scopes = ScopeSet(projectScopeURL: fixtureKitRootURL(), globalScopeURL: nil)
    let service = MCPToolService(scopes: scopes)

    let result = try service.callTool(
      name: "personakit_explain_entity",
      arguments: [
        "entityType": "persona",
        "id": "senior-swiftui-engineer",
      ]
    )

    let output = try #require(firstText(result))
    let object = try #require(jsonObject(output))

    #expect(object["entityType"] as? String == "persona")
    #expect(object["id"] as? String == "senior-swiftui-engineer")

    let data = try #require(object["data"] as? [String: Any])
    let defaultKitIds = try #require(data["defaultKitIds"] as? [String])
    #expect(defaultKitIds == ["repo-constraints", "swift-style", "swiftui-style"])
  }

  @Test
  func compareEntitiesToolReportsDeterministicDifferences() throws {
    let scopes = ScopeSet(projectScopeURL: fixtureKitRootURL(), globalScopeURL: nil)
    let service = MCPToolService(scopes: scopes)

    let result = try service.callTool(
      name: "personakit_compare_entities",
      arguments: [
        "entityType": "skill",
        "leftId": "codex-cli",
        "rightId": "autonomous-agent-loop",
      ]
    )

    let output = try #require(firstText(result))
    let object = try #require(jsonObject(output))

    #expect(object["entityType"] as? String == "skill")
    let scalarDifferences = try #require(object["scalarDifferences"] as? [[String: Any]])
    #expect(!scalarDifferences.isEmpty)
  }

  @Test
  func recommendSessionToolReturnsRankedSession() throws {
    let scopes = ScopeSet(projectScopeURL: fixtureKitRootURL(), globalScopeURL: nil)
    let service = MCPToolService(scopes: scopes)

    let result = try service.callTool(
      name: "personakit_recommend_session",
      arguments: [
        "goal": "Apply SwiftUI style guide with safe refactor review",
        "limit": 3,
      ]
    )

    let output = try #require(firstText(result))
    let object = try #require(jsonObject(output))

    let recommendations = try #require(object["recommendations"] as? [[String: Any]])
    #expect(recommendations.count == 1)
    let first = try #require(recommendations.first)
    #expect(first["sessionId"] as? String == "senior-swiftui-engineer_apply-style")
  }

  @Test
  func traceSessionToolResolvesDependencySets() throws {
    let scopes = ScopeSet(projectScopeURL: fixtureKitRootURL(), globalScopeURL: nil)
    let service = MCPToolService(scopes: scopes)

    let result = try service.callTool(
      name: "personakit_trace_session",
      arguments: [
        "sessionId": "senior-swiftui-engineer_apply-style",
      ]
    )

    let output = try #require(firstText(result))
    let object = try #require(jsonObject(output))

    let resolved = try #require(object["resolved"] as? [String: Any])
    let kitIds = try #require(resolved["kitIds"] as? [String])
    #expect(kitIds == ["repo-constraints", "swift-style", "swiftui-style"])
  }
}

private func firstText(_ result: CallTool.Result) -> String? {
  guard let first = result.content.first else {
    return nil
  }
  if case .text(let text) = first {
    return text
  }
  return nil
}

private func jsonObject(_ text: String) -> [String: Any]? {
  guard let data = text.data(using: .utf8) else {
    return nil
  }

  return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
}
