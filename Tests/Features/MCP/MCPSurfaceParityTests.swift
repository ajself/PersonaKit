import ContextCore
import MCP
import Testing

@testable import ContextMCP

struct MCPSurfaceParityTests {
  @Test
  func exportPromptMatchesExportToolOutput() throws {
    let scopes = ScopeSet(projectScopeURL: fixtureKitRootURL(), globalScopeURL: nil)
    let promptService = MCPPromptService(scopes: scopes)
    let toolService = MCPToolService(scopes: scopes)

    let promptResult = try promptService.getPrompt(
      name: "personakit.session.export",
      arguments: [
        "personaId": .string("senior-swiftui-engineer"),
        "directiveId": .string("apply-style"),
      ]
    )
    let toolResult = try toolService.callTool(
      name: "personakit_export",
      arguments: [
        "personaId": "senior-swiftui-engineer",
        "directiveId": "apply-style",
      ]
    )

    let promptText = try #require(firstPromptText(promptResult))
    let toolText = try #require(firstToolText(toolResult))

    #expect(normalizedTrailingNewline(promptText) == normalizedTrailingNewline(toolText))
  }

  @Test
  func graphPromptMatchesGraphToolOutput() throws {
    let scopes = ScopeSet(projectScopeURL: fixtureKitRootURL(), globalScopeURL: nil)
    let promptService = MCPPromptService(scopes: scopes)
    let toolService = MCPToolService(scopes: scopes)

    let promptResult = try promptService.getPrompt(
      name: "personakit.session.graph",
      arguments: [
        "personaId": .string("senior-swiftui-engineer"),
        "directiveId": .string("apply-style"),
      ]
    )
    let toolResult = try toolService.callTool(
      name: "personakit_graph",
      arguments: [
        "personaId": "senior-swiftui-engineer",
        "directiveId": "apply-style",
      ]
    )

    let promptText = try #require(firstPromptText(promptResult))
    let toolText = try #require(firstToolText(toolResult))

    #expect(normalizedTrailingNewline(promptText) == normalizedTrailingNewline(toolText))
  }

  @Test
  func listSurfacesStayAlignedWithCurrentDefinitions() {
    let scopes = ScopeSet(projectScopeURL: fixtureKitRootURL(), globalScopeURL: nil)
    let promptService = MCPPromptService(scopes: scopes)
    let toolService = MCPToolService(scopes: scopes)

    #expect(
      promptService.listPrompts().map(\.name)
        == MCPPromptName.allCases.sorted { $0.rawValue < $1.rawValue }.map(\.rawValue)
    )
    #expect(
      toolService.listTools().map(\.name)
        == MCPToolName.allCases.sorted { $0.rawValue < $1.rawValue }.map(\.rawValue)
    )
  }
}

private func firstPromptText(_ result: GetPrompt.Result) -> String? {
  guard let first = result.messages.first else {
    return nil
  }

  guard first.role == .user else {
    return nil
  }

  if case .text(text: let text) = first.content {
    return text
  }

  return nil
}

private func firstToolText(_ result: CallTool.Result) -> String? {
  guard let first = result.content.first else {
    return nil
  }

  if case .text(let text, _, _) = first {
    return text
  }

  return nil
}
