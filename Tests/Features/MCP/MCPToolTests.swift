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
        "personakit_export",
        "personakit_graph",
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
