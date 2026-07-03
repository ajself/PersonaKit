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
  func promptArgumentsRejectSessionIdMixedWithPersonaSelection() {
    let args: [String: Value] = [
      "sessionId": .string("senior-swiftui-engineer_apply-style"),
      "personaId": .string("senior-swiftui-engineer"),
      "directiveId": .string("apply-style"),
    ]

    do {
      _ = try MCPPromptArgumentParser.parse(args)
      #expect(Bool(false))
    } catch let error as MCPPromptArgumentError {
      #expect(
        error
          == .invalidValue(
            "sessionId",
            "cannot be combined with personaId, directiveId, or kits"
          )
      )
    } catch {
      #expect(Bool(false))
    }
  }

  @Test
  func promptArgumentsRejectSessionIdMixedWithKits() {
    let args: [String: Value] = [
      "sessionId": .string("senior-swiftui-engineer_apply-style"),
      "kits": .string("swift-style"),
    ]

    do {
      _ = try MCPPromptArgumentParser.parse(args)
      #expect(Bool(false))
    } catch let error as MCPPromptArgumentError {
      #expect(
        error
          == .invalidValue(
            "sessionId",
            "cannot be combined with personaId, directiveId, or kits"
          )
      )
    } catch {
      #expect(Bool(false))
    }
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

  @Test
  func promptArgumentsParseReferenceTriggers() throws {
    let args: [String: Value] = [
      "personaId": .string("senior-swiftui-engineer"),
      "directiveId": .string("apply-style"),
      "targetPaths": .string(" Sources/FooView.swift , Views/BarView.swift "),
      "skillTags": .string(" swiftui , "),
    ]

    let parsed = try MCPPromptArgumentParser.parse(args)

    #expect(parsed.targetPaths == ["Sources/FooView.swift", "Views/BarView.swift"])
    #expect(parsed.skillTags == ["swiftui"])
  }
}
