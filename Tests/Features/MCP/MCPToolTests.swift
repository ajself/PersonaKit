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
        "personakit_best_guidance",
        "personakit_compare_entities",
        "personakit_explain_entity",
        "personakit_export",
        "personakit_graph",
        "personakit_recommend_session",
        "personakit_resolve_contract",
        "personakit_resolve_grounding_skills",
        "personakit_resolve_session_ref",
        "personakit_trace_session",
        "personakit_validate",
      ]
    )
  }

  @Test
  func groundingToolDescriptionsExplainWhenToUseThem() {
    let scopes = ScopeSet(projectScopeURL: fixtureKitRootURL(), globalScopeURL: nil)
    let service = MCPToolService(scopes: scopes)
    let descriptions = Dictionary(
      uniqueKeysWithValues: service.listTools().map { ($0.name, $0.description ?? "") }
    )

    #expect(
      descriptions["personakit_best_guidance"]?
        .contains("best next grounding steps") == true
    )
    #expect(
      descriptions["personakit_recommend_session"]?
        .contains("when the correct session id is not known") == true
    )
    #expect(
      descriptions["personakit_resolve_contract"]?
        .contains("before acting") == true
    )
    #expect(
      descriptions["personakit_trace_session"]?
        .contains("provenance review") == true
    )
    #expect(
      descriptions["personakit_resolve_grounding_skills"]?
        .contains("target paths or skill tags") == true
    )
    #expect(
      descriptions["personakit_export"]?
        .contains("human-readable grounding") == true
    )
  }

  @Test
  func mcpServerInstructionsPointAgentsAtStartResource() {
    #expect(MCPServerRunner.instructions.contains("personakit://catalog/start"))
    #expect(MCPServerRunner.instructions.contains("read-only grounding"))
    #expect(MCPServerRunner.instructions.contains("does not authorize execution"))
  }

  @Test
  func validateToolRejectsSessionsPathWhenItIsAFile() throws {
    let root = try makeMCPRootWithSessionsFile()
    let scopes = ScopeSet(projectScopeURL: root, globalScopeURL: nil)
    let service = MCPToolService(scopes: scopes)

    let result = try service.callTool(
      name: "personakit_validate",
      arguments: [:]
    )

    let output = try #require(firstText(result))
    let object = try #require(jsonObject(output))
    let errors = try #require(object["errors"] as? [String])

    #expect(object["ok"] as? Bool == false)
    #expect(errors.count == 1)
    #expect(
      errors.first
        == "session sessionFile: Session discovery path is not a directory: Sessions. expectedPath=Sessions"
    )
  }

  @Test
  func bestGuidanceToolReportsScopeAndCommands() throws {
    let scopes = ScopeSet(projectScopeURL: fixtureKitRootURL(), globalScopeURL: nil)
    let service = MCPToolService(scopes: scopes)

    let result = try service.callTool(
      name: "personakit_best_guidance",
      arguments: [:]
    )

    let output = try #require(firstText(result))
    let data = try #require(output.data(using: .utf8))
    let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    let scope = try #require(object["scope"] as? [String: Any])
    let risks = try #require(object["risks"] as? [String])
    let commands = try #require(object["suggestedCommands"] as? [String])

    #expect(scope["projectRoot"] as? String == fixtureKitRootURL().path)
    #expect(
      risks.contains(
        "Current directory contains a project .personakit that is not in the loaded scope set."
      )
    )
    #expect(!commands.contains { $0.contains("contract --root \(fixtureKitRootURL().path)") })
    #expect(commands.contains("personakit guidance --root \(repoRootURL().appendingPathComponent(".personakit").path)"))
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
  func toolCallExportAcceptsSessionID() throws {
    let scopes = ScopeSet(projectScopeURL: fixtureKitRootURL(), globalScopeURL: nil)
    let service = MCPToolService(scopes: scopes)

    let result = try service.callTool(
      name: "personakit_export",
      arguments: [
        "sessionId": "senior-swiftui-engineer_apply-style"
      ]
    )

    let output = try #require(firstText(result))
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
  func toolCallGraphAcceptsSessionID() throws {
    let scopes = ScopeSet(projectScopeURL: fixtureKitRootURL(), globalScopeURL: nil)
    let service = MCPToolService(scopes: scopes)

    let result = try service.callTool(
      name: "personakit_graph",
      arguments: [
        "sessionId": "senior-swiftui-engineer_apply-style"
      ]
    )

    let output = try #require(firstText(result))
    let fixtureURL = fixturesRootURL()
      .appendingPathComponent("expected/graph_senior-swiftui-engineer_apply-style.txt")
    let expected = try String(contentsOf: fixtureURL, encoding: .utf8)

    #expect(normalizedTrailingNewline(output) == normalizedTrailingNewline(expected))
  }

  @Test
  func toolCallRejectsMixedSessionIDAndPersonaInputs() throws {
    let scopes = ScopeSet(projectScopeURL: fixtureKitRootURL(), globalScopeURL: nil)
    let service = MCPToolService(scopes: scopes)

    do {
      _ = try service.callTool(
        name: "personakit_export",
        arguments: [
          "sessionId": "senior-swiftui-engineer_apply-style",
          "personaId": "senior-swiftui-engineer",
          "directiveId": "apply-style",
        ]
      )
      #expect(Bool(false))
    } catch {
      let message = errorMessage(error)
      #expect(message.contains("sessionId"))
      #expect(message.contains("cannot be combined"))
    }
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

    let scope = try #require(object["scope"] as? [String: Any])
    #expect(scope["mode"] as? String == "project-only")
    #expect(scope["projectRoot"] as? String == fixtureKitRootURL().standardizedFileURL.path)
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
    // Regression (S8): the persona's ambient `environment` is surfaced, not dropped.
    #expect(data["environmentCount"] as? Int == 2)
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
  func compareEntitiesSurfacesPersonaEnvironmentDifference() throws {
    // Regression (S8): `environment` is a compared persona field, not dropped.
    // senior-swiftui-engineer declares an environment; the added persona does not,
    // so the difference must appear.
    let root = try makeTempDirectory().appendingPathComponent("PersonaKit")
    try copyFixtureKit(to: root)
    let plainPersona = """
      {
        "id": "plain-persona",
        "version": "1.0",
        "name": "Plain Persona",
        "summary": "No ambient environment.",
        "responsibilities": [],
        "values": [],
        "nonGoals": [],
        "defaultKitIds": [],
        "allowedSkillIds": [],
        "forbiddenSkillIds": []
      }
      """
    try Data(plainPersona.utf8).write(
      to: root.appendingPathComponent("Packs/personas/plain-persona.persona.json")
    )

    let scopes = ScopeSet(projectScopeURL: root, globalScopeURL: nil)
    let service = MCPToolService(scopes: scopes)

    let result = try service.callTool(
      name: "personakit_compare_entities",
      arguments: [
        "entityType": "persona",
        "leftId": "senior-swiftui-engineer",
        "rightId": "plain-persona",
      ]
    )

    let output = try #require(firstText(result))
    let object = try #require(jsonObject(output))
    let listDifferences = try #require(object["listDifferences"] as? [[String: Any]])
    #expect(listDifferences.contains { ($0["field"] as? String) == "environment" })
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
  func recommendSessionToolReturnsNoStrongMatchForWeakGoal() throws {
    let scopes = ScopeSet(projectScopeURL: fixtureKitRootURL(), globalScopeURL: nil)
    let service = MCPToolService(scopes: scopes)

    let result = try service.callTool(
      name: "personakit_recommend_session",
      arguments: [
        "goal": "warehouse forklift barcode",
        "limit": 3,
      ]
    )

    let output = try #require(firstText(result))
    let object = try #require(jsonObject(output))
    let recommendations = try #require(object["recommendations"] as? [[String: Any]])
    #expect(recommendations.isEmpty)
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
    let availableGroundingSkillIds = try #require(resolved["availableGroundingSkillIds"] as? [String])
    #expect(
      availableGroundingSkillIds == [
        "swift-style-guide-reference",
        "swiftui-style-guide-reference",
        "tools-and-constraints",
      ]
    )
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
  func explainGroundingSkillReturnsTriggerMetadata() throws {
    let scopes = ScopeSet(projectScopeURL: fixtureKitRootURL(), globalScopeURL: nil)
    let service = MCPToolService(scopes: scopes)

    let result = try service.callTool(
      name: "personakit_explain_entity",
      arguments: [
        "entityType": "skill",
        "id": "swiftui-style-guide-reference",
      ]
    )

    let output = try #require(firstText(result))
    let object = try #require(jsonObject(output))
    #expect(object["entityType"] as? String == "skill")

    let data = try #require(object["data"] as? [String: Any])
    let triggerSummaries = try #require(data["triggerSummaries"] as? [String])
    #expect(triggerSummaries == ["skillTags=swiftui", "paths=**/*View.swift, **/Views/**/*.swift"])
  }

  @Test
  func resolveGroundingSkillsReturnsMatchedSkills() throws {
    let scopes = ScopeSet(projectScopeURL: fixtureKitRootURL(), globalScopeURL: nil)
    let service = MCPToolService(scopes: scopes)

    let result = try service.callTool(
      name: "personakit_resolve_grounding_skills",
      arguments: [
        "personaId": "senior-swiftui-engineer",
        "directiveId": "apply-style",
        "targetPaths": ["Sources/FooView.swift"],
        "skillTags": ["swiftui"],
      ]
    )

    let output = try #require(firstText(result))
    let object = try #require(jsonObject(output))
    let matchedGroundingSkills = try #require(object["matchedGroundingSkills"] as? [[String: Any]])

    #expect(
      matchedGroundingSkills.map { $0["id"] as? String } == [
        "swift-style-guide-reference",
        "swiftui-style-guide-reference",
        "tools-and-constraints",
      ]
    )
  }

  @Test
  func resolveGroundingSkillsAcceptsSessionIDWithSkillInputs() throws {
    let scopes = ScopeSet(projectScopeURL: fixtureKitRootURL(), globalScopeURL: nil)
    let service = MCPToolService(scopes: scopes)

    let result = try service.callTool(
      name: "personakit_resolve_grounding_skills",
      arguments: [
        "sessionId": "senior-swiftui-engineer_apply-style",
        "targetPaths": ["Sources/FooView.swift"],
        "skillTags": ["swiftui"],
      ]
    )

    let output = try #require(firstText(result))
    let object = try #require(jsonObject(output))
    let matchedGroundingSkills = try #require(object["matchedGroundingSkills"] as? [[String: Any]])

    #expect(
      matchedGroundingSkills.map { $0["id"] as? String } == [
        "swift-style-guide-reference",
        "swiftui-style-guide-reference",
        "tools-and-constraints",
      ]
    )
  }

}

private func firstText(_ result: CallTool.Result) -> String? {
  guard let first = result.content.first else {
    return nil
  }
  if case .text(let text, _, _) = first {
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

private func errorMessage(_ error: any Error) -> String {
  let localized = (error as NSError).localizedDescription

  return localized.isEmpty ? String(describing: error) : localized
}

private func makeMCPRootWithSessionsFile() throws -> URL {
  let root = try makeTempDirectory().appendingPathComponent("PersonaKit")
  try copyFixtureKit(to: root)
  let sessionsURL = root.appendingPathComponent("Sessions")
  try FileManager.default.removeItem(at: sessionsURL)
  try Data("not a directory".utf8).write(to: sessionsURL)

  return root
}
