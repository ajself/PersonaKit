import ContextCore
import MCP
import Testing

@testable import ContextMCP

struct MCPPromptTests {
  @Test
  func promptListIsDeterministic() {
    let scopes = ScopeSet(projectScopeURL: fixtureKitRootURL(), globalScopeURL: nil)
    let service = MCPPromptService(scopes: scopes)

    let prompts = service.listPrompts()

    #expect(
      prompts.map(\.name) == [
        "personakit.session.export",
        "personakit.session.graph",
      ]
    )
  }

  @Test
  func promptArgumentsRequirePersonaId() {
    let args: [String: Value] = [
      "directiveId": .string("apply-style")
    ]

    do {
      _ = try MCPPromptArgumentParser.parse(args)
      #expect(Bool(false))
    } catch let error as MCPPromptArgumentError {
      #expect(error == .missing("personaId"))
    } catch {
      #expect(Bool(false))
    }
  }

  @Test
  func promptArgumentsParseKitOverrides() throws {
    let args: [String: Value] = [
      "personaId": .string("senior-swiftui-engineer"),
      "directiveId": .string("apply-style"),
      "kits": .string(" swift-style, repo-constraints , ,"),
    ]

    let parsed = try MCPPromptArgumentParser.parse(args)

    #expect(parsed.kitOverrides == ["swift-style", "repo-constraints"])
  }

  @Test
  func promptArgumentsRejectNonStringKits() {
    let args: [String: Value] = [
      "personaId": .string("senior-swiftui-engineer"),
      "directiveId": .string("apply-style"),
      "kits": .array([]),
    ]

    do {
      _ = try MCPPromptArgumentParser.parse(args)
      #expect(Bool(false))
    } catch let error as MCPPromptArgumentError {
      #expect(error == .invalidType("kits"))
    } catch {
      #expect(Bool(false))
    }
  }
}
