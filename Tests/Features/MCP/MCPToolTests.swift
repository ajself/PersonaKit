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
        "personakit_resolve_contract",
        "personakit_resolve_references",
        "personakit_resolve_session_ref",
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
  func contractToolReturnsStructuredAuthorizationPayload() throws {
    let scopes = ScopeSet(projectScopeURL: fixtureKitRootURL(), globalScopeURL: nil)
    let service = MCPToolService(scopes: scopes)

    let result = try service.callTool(
      name: "personakit_resolve_contract",
      arguments: [
        "sessionId": "senior-swiftui-engineer_apply-style",
        "requestedSkillIds": ["codex-cli", "missing-skill"],
      ]
    )

    let output = try #require(firstText(result))
    let object = try #require(jsonObject(output))

    #expect(object["personaId"] as? String == "senior-swiftui-engineer")
    #expect(object["directiveId"] as? String == "apply-style")
    #expect(
      object["injectedContractIds"] as? [String] == [
        "persona-activation-contract",
        "skill-authorization-contract",
      ]
    )
    #expect(object["authorizedSkillIds"] as? [String] == ["codex-cli"])
    #expect(object["undeclaredRequestedSkillIds"] as? [String] == ["missing-skill"])
    #expect(object["isAuthorized"] as? Bool == false)
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
  func resolveSessionRefToolNormalizesSessionID() throws {
    let scopes = ScopeSet(projectScopeURL: fixtureKitRootURL(), globalScopeURL: nil)
    let service = MCPToolService(scopes: scopes)

    let result = try service.callTool(
      name: "personakit_resolve_session_ref",
      arguments: [
        "sessionRef": "senior-swiftui-engineer_apply-style"
      ]
    )

    let output = try #require(firstText(result))
    let object = try #require(jsonObject(output))

    #expect(object["normalizedSessionId"] as? String == "senior-swiftui-engineer_apply-style")
    #expect(object["sourceRefType"] as? String == "id")
    #expect(object["personaId"] as? String == "senior-swiftui-engineer")
    #expect(object["directiveId"] as? String == "apply-style")
  }

  @Test
  func resolveSessionRefToolNormalizesSessionPath() throws {
    let scopes = ScopeSet(projectScopeURL: fixtureKitRootURL(), globalScopeURL: nil)
    let service = MCPToolService(scopes: scopes)

    let result = try service.callTool(
      name: "personakit_resolve_session_ref",
      arguments: [
        "sessionRef": "Sessions/senior-swiftui-engineer_apply-style.session.json"
      ]
    )

    let output = try #require(firstText(result))
    let object = try #require(jsonObject(output))

    #expect(object["normalizedSessionId"] as? String == "senior-swiftui-engineer_apply-style")
    #expect(object["sourceRefType"] as? String == "path")
  }

  @Test
  func traceSessionToolResolvesDependencySets() throws {
    let scopes = ScopeSet(projectScopeURL: fixtureKitRootURL(), globalScopeURL: nil)
    let service = MCPToolService(scopes: scopes)

    let result = try service.callTool(
      name: "personakit_trace_session",
      arguments: [
        "sessionId": "senior-swiftui-engineer_apply-style"
      ]
    )

    let output = try #require(firstText(result))
    let object = try #require(jsonObject(output))

    let resolved = try #require(object["resolved"] as? [String: Any])
    let kitIds = try #require(resolved["kitIds"] as? [String])
    #expect(kitIds == ["repo-constraints", "swift-style", "swiftui-style"])
    let availableReferenceIds = try #require(resolved["availableReferenceIds"] as? [String])
    #expect(availableReferenceIds == ["swift-style-guide-reference", "swiftui-style-guide-reference"])
    let essentialIds = try #require(resolved["essentialIds"] as? [String])
    #expect(
      essentialIds == [
        "persona-activation-contract",
        "skill-authorization-contract",
        "environment",
        "non-goals",
        "swift-style-guide",
        "swiftui-style-guide",
        "tools-and-constraints",
      ]
    )
    let edges = try #require(object["edges"] as? [String: Any])
    let systemEssentialIds = try #require(edges["systemEssentialIds"] as? [String])
    #expect(systemEssentialIds == ["persona-activation-contract", "skill-authorization-contract"])
    let skillAuthorization = try #require(resolved["skillAuthorization"] as? [String: Any])
    #expect(skillAuthorization["allowedSkillIds"] as? [String] == ["codex-cli"])
    #expect(skillAuthorization["authorizedSkillIds"] as? [String] == ["codex-cli"])
    #expect(skillAuthorization["requiredSkillIds"] as? [String] == ["codex-cli"])
    #expect(skillAuthorization["unauthorizedRequiredSkillIds"] as? [String] == [])
    #expect(skillAuthorization["isAuthorized"] as? Bool == true)
  }

  @Test
  func explainDirectiveToolIncludesWorkstreamSummary() throws {
    let scopes = ScopeSet(projectScopeURL: try makeWorkstreamFixtureRoot(), globalScopeURL: nil)
    let service = MCPToolService(scopes: scopes)

    let result = try service.callTool(
      name: "personakit_explain_entity",
      arguments: [
        "entityType": "directive",
        "id": "apply-style",
      ]
    )

    let output = try #require(firstText(result))
    let object = try #require(jsonObject(output))
    let data = try #require(object["data"] as? [String: Any])
    let workstream = try #require(data["workstream"] as? [String: Any])

    #expect(workstream["id"] as? String == "style-workstream")
    #expect(workstream["phase"] as? String == "planning")
    #expect(workstream["entrySessionId"] as? String == "senior-swiftui-engineer_apply-style")
    #expect(workstream["requiredCloseoutSessionId"] as? String == "style-closeout")
    #expect(workstream["nodeCount"] as? Int == 3)
    #expect(workstream["edgeCount"] as? Int == 2)
  }

  @Test
  func traceSessionToolIncludesWorkstreamRoutingPayload() throws {
    let scopes = ScopeSet(projectScopeURL: try makeWorkstreamFixtureRoot(), globalScopeURL: nil)
    let service = MCPToolService(scopes: scopes)

    let result = try service.callTool(
      name: "personakit_trace_session",
      arguments: [
        "sessionId": "senior-swiftui-engineer_apply-style"
      ]
    )

    let output = try #require(firstText(result))
    let object = try #require(jsonObject(output))
    let workstream = try #require(object["workstream"] as? [String: Any])

    #expect(workstream["id"] as? String == "style-workstream")
    #expect(workstream["phase"] as? String == "planning")
    #expect(workstream["currentSessionId"] as? String == "senior-swiftui-engineer_apply-style")
    #expect(workstream["requiredCloseoutSessionId"] as? String == "style-closeout")
    #expect(workstream["nextSessionIds"] as? [String] == ["style-followup"])

    let nodes = try #require(workstream["nodes"] as? [[String: Any]])
    #expect(nodes.count == 3)

    let edges = try #require(workstream["edges"] as? [[String: Any]])
    #expect(edges.count == 2)
  }

  @Test
  func explainReferenceToolReturnsTriggerMetadata() throws {
    let scopes = ScopeSet(projectScopeURL: fixtureKitRootURL(), globalScopeURL: nil)
    let service = MCPToolService(scopes: scopes)

    let result = try service.callTool(
      name: "personakit_explain_entity",
      arguments: [
        "entityType": "reference",
        "id": "swiftui-style-guide-reference",
      ]
    )

    let output = try #require(firstText(result))
    let object = try #require(jsonObject(output))
    #expect(object["entityType"] as? String == "reference")

    let data = try #require(object["data"] as? [String: Any])
    let triggerSummaries = try #require(data["triggerSummaries"] as? [String])
    #expect(triggerSummaries == ["referenceTags=swiftui", "paths=**/*View.swift, **/Views/**/*.swift"])
  }

  @Test
  func resolveReferencesToolReturnsMatchedReferences() throws {
    let scopes = ScopeSet(projectScopeURL: fixtureKitRootURL(), globalScopeURL: nil)
    let service = MCPToolService(scopes: scopes)

    let result = try service.callTool(
      name: "personakit_resolve_references",
      arguments: [
        "personaId": "senior-swiftui-engineer",
        "directiveId": "apply-style",
        "targetPaths": ["Sources/FooView.swift"],
        "referenceTags": ["swiftui"],
      ]
    )

    let output = try #require(firstText(result))
    let object = try #require(jsonObject(output))
    let matchedReferences = try #require(object["matchedReferences"] as? [[String: Any]])

    #expect(matchedReferences.map { $0["id"] as? String } == [
      "swift-style-guide-reference",
      "swiftui-style-guide-reference",
    ])
  }

  @Test
  func explainIntentToolIncludesParameterConstraints() throws {
    let root = try makeTempDirectory().appendingPathComponent("FixtureKit")
    try copyFixtureKit(to: root)

    let intentURL = root.appendingPathComponent("Packs/intents/swift-refactor-safe.intent.json")
    let data = try Data(contentsOf: intentURL)
    var object = try #require(
      JSONSerialization.jsonObject(with: data) as? [String: Any]
    )
    var parameters = try #require(object["parameters"] as? [[String: Any]])
    parameters.append(
      [
        "name": "secondaryFile",
        "type": "string",
        "required": true,
      ]
    )
    object["parameters"] = parameters
    object["parameterConstraints"] = [
      [
        "kind": "allDistinct",
        "parameterNames": ["targetFiles", "secondaryFile"],
      ]
    ]
    let updatedData = try JSONSerialization.data(
      withJSONObject: object,
      options: [.prettyPrinted, .sortedKeys]
    )
    try updatedData.write(to: intentURL)

    let scopes = ScopeSet(projectScopeURL: root, globalScopeURL: nil)
    let service = MCPToolService(scopes: scopes)
    let result = try service.callTool(
      name: "personakit_explain_entity",
      arguments: [
        "entityType": "intent",
        "id": "swift-refactor-safe",
      ]
    )

    let output = try #require(firstText(result))
    let response = try #require(jsonObject(output))
    let payload = try #require(response["data"] as? [String: Any])
    let constraints = try #require(payload["parameterConstraints"] as? [String])

    #expect(constraints == ["allDistinct:targetFiles,secondaryFile"])
  }
}

private func firstText(_ result: CallTool.Result) -> String? {
  guard let first = result.content.first else {
    return nil
  }
  if case let .text(text, _, _) = first {
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
