import Foundation
import Testing

@testable import StudioFeatures

struct StudioAgentSetupGuideTests {
  @Test
  func stepsRunCLIThenMCPThenPluginThenEnforcement() {
    #expect(StudioAgentSetupGuide.steps.map(\.id) == ["cli", "mcp", "opencode-plugin", "enforce"])
  }

  @Test
  func commandsMatchTheDocumentedStrings() {
    let commands = Dictionary(
      uniqueKeysWithValues: StudioAgentSetupGuide.steps.flatMap(\.commands).map { ($0.id, $0.text) }
    )

    #expect(commands["cli-releases"] == "https://github.com/ajself/PersonaKit/releases/latest")
    #expect(commands["mcp-claude"] == #"claude mcp add personakit --scope user -- "$(which personakit)" mcp"#)
    #expect(commands["mcp-opencode"]?.contains(#""command": ["/usr/local/bin/personakit", "mcp"]"#) == true)
    #expect(commands["opencode-plugin-install"] == "make opencode-install")
    #expect(commands["enforce-claude"] == "personakit enforce install --session <id>")
    #expect(commands["enforce-opencode"] == "personakit enforce install --host opencode --session <id>")
  }

  @Test
  func openCodeSnippetIsValidJSON() throws {
    let snippet = try #require(
      StudioAgentSetupGuide.steps.flatMap(\.commands).first { $0.id == "mcp-opencode" }?.text
    )

    _ = try JSONSerialization.jsonObject(with: Data(snippet.utf8))
  }
}
