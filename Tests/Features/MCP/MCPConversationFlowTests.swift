import ContextCore
import Foundation
import MCP
import Testing

@testable import ContextMCP

struct MCPConversationFlowTests {
  @Test
  func catalogRecommendTraceFlowUsesConsistentSessionIdentity() throws {
    let scopes = ScopeSet(projectScopeURL: fixtureKitRootURL(), globalScopeURL: nil)
    let registry = try Registry.load(scopes: scopes)
    let resourceService = MCPResourceService(registry: registry, scopes: scopes)
    let toolService = MCPToolService(scopes: scopes)

    let personasPayload: CatalogListPayload = try decodeJSON(
      text: resourceService.readCatalogResource(type: .personas)
    )
    #expect(personasPayload.type == "personas")
    #expect(personasPayload.ids.contains("senior-swiftui-engineer"))

    let recommendationResult = try toolService.callTool(
      name: "personakit_recommend_session",
      arguments: [
        "goal": "Apply SwiftUI style guide with safe refactor review",
        "limit": 3,
      ]
    )
    let recommendationText = try requireFirstText(recommendationResult)
    let recommendationPayload: RecommendationPayload = try decodeJSON(text: recommendationText)

    #expect(recommendationPayload.goalTerms == ["apply", "guide", "refactor", "review", "safe", "style", "swiftui"])
    #expect(recommendationPayload.consideredSessions == ["senior-swiftui-engineer_apply-style"])

    let firstRecommendation = try #require(recommendationPayload.recommendations.first)
    #expect(firstRecommendation.sessionId == "senior-swiftui-engineer_apply-style")
    #expect(firstRecommendation.personaId == "senior-swiftui-engineer")
    #expect(firstRecommendation.directiveId == "apply-style")

    let traceResult = try toolService.callTool(
      name: "personakit_trace_session",
      arguments: [
        "sessionId": .string(firstRecommendation.sessionId),
      ]
    )
    let traceText = try requireFirstText(traceResult)
    let tracePayload: SessionTracePayload = try decodeJSON(text: traceText)

    #expect(tracePayload.session.id == firstRecommendation.sessionId)
    #expect(tracePayload.resolved.personaId == firstRecommendation.personaId)
    #expect(tracePayload.resolved.directiveId == firstRecommendation.directiveId)
    #expect(tracePayload.resolved.kitIds == ["repo-constraints", "swift-style", "swiftui-style"])
  }

  @Test
  func resolveTraceFlowNormalizesPathAndFeedsTrace() throws {
    let scopes = ScopeSet(projectScopeURL: fixtureKitRootURL(), globalScopeURL: nil)
    let toolService = MCPToolService(scopes: scopes)

    let resolveResult = try toolService.callTool(
      name: "personakit_resolve_session_ref",
      arguments: [
        "sessionRef": "Sessions/senior-swiftui-engineer_apply-style.session.json",
      ]
    )
    let resolveText = try requireFirstText(resolveResult)
    let resolvePayload: SessionReferenceResolutionPayload = try decodeJSON(text: resolveText)

    #expect(resolvePayload.sourceRefType == "path")
    #expect(resolvePayload.normalizedSessionId == "senior-swiftui-engineer_apply-style")

    let traceResult = try toolService.callTool(
      name: "personakit_trace_session",
      arguments: [
        "sessionId": .string(resolvePayload.normalizedSessionId),
      ]
    )
    let traceText = try requireFirstText(traceResult)
    let tracePayload: SessionTracePayload = try decodeJSON(text: traceText)

    #expect(tracePayload.session.id == resolvePayload.normalizedSessionId)
    #expect(tracePayload.resolved.personaId == resolvePayload.personaId)
    #expect(tracePayload.resolved.directiveId == resolvePayload.directiveId)
  }

  @Test
  func recommendSessionOutputIsDeterministicAcrossRepeatedCalls() throws {
    let scopes = ScopeSet(projectScopeURL: fixtureKitRootURL(), globalScopeURL: nil)
    let toolService = MCPToolService(scopes: scopes)
    let arguments: [String: Value] = [
      "goal": "Apply SwiftUI style guide with safe refactor review",
      "limit": 3,
    ]

    let first = try requireFirstText(
      toolService.callTool(name: "personakit_recommend_session", arguments: arguments)
    )
    let second = try requireFirstText(
      toolService.callTool(name: "personakit_recommend_session", arguments: arguments)
    )

    #expect(normalizedTrailingNewline(first) == normalizedTrailingNewline(second))
  }

  @Test
  func recommendSessionErrorIncludesRecoveryHintWhenSessionsMissing() throws {
    let root = try makeTempDirectory().appendingPathComponent(".personakit")
    try copyFixtureKit(to: root)
    try FileManager.default.removeItem(at: root.appendingPathComponent("Sessions"))

    let scopes = ScopeSet(projectScopeURL: root, globalScopeURL: nil)
    let toolService = MCPToolService(scopes: scopes)

    do {
      _ = try toolService.callTool(
        name: "personakit_recommend_session",
        arguments: ["goal": "Anything"]
      )
      #expect(Bool(false))
    } catch {
      let message = errorMessage(error)
      #expect(message.contains("No session files found in active scopes."))
      #expect(message.contains("Recovery:"))
    }
  }

  @Test
  func explainEntityErrorIncludesRecoveryHintForUnknownPersona() throws {
    let scopes = ScopeSet(projectScopeURL: fixtureKitRootURL(), globalScopeURL: nil)
    let toolService = MCPToolService(scopes: scopes)

    do {
      _ = try toolService.callTool(
        name: "personakit_explain_entity",
        arguments: [
          "entityType": "persona",
          "id": "missing-persona",
        ]
      )
      #expect(Bool(false))
    } catch {
      let message = errorMessage(error)
      #expect(message.contains("persona not found: missing-persona"))
      #expect(message.contains("personakit://catalog/personas"))
      #expect(message.contains("Recovery:"))
    }
  }
}

private struct CatalogListPayload: Decodable {
  let schemaVersion: Int
  let type: String
  let ids: [String]
}

private struct RecommendationPayload: Decodable {
  let schemaVersion: Int
  let goal: String
  let goalTerms: [String]
  let consideredSessions: [String]
  let recommendations: [Recommendation]
}

private struct Recommendation: Decodable {
  let sessionId: String
  let personaId: String
  let directiveId: String
}

private struct SessionTracePayload: Decodable {
  let schemaVersion: Int
  let session: SessionTraceSession
  let resolved: SessionTraceResolved
}

private struct SessionReferenceResolutionPayload: Decodable {
  let sourceRefType: String
  let normalizedSessionId: String
  let personaId: String
  let directiveId: String
}

private struct SessionTraceSession: Decodable {
  let id: String
}

private struct SessionTraceResolved: Decodable {
  let personaId: String
  let directiveId: String
  let kitIds: [String]
}

private enum MCPConversationFlowTestError: Error {
  case missingTextContent
  case invalidUTF8
}

private func requireFirstText(_ result: CallTool.Result) throws -> String {
  guard let first = result.content.first else {
    throw MCPConversationFlowTestError.missingTextContent
  }
  if case .text(let text) = first {
    return text
  }
  throw MCPConversationFlowTestError.missingTextContent
}

private func decodeJSON<T: Decodable>(text: String) throws -> T {
  guard let data = text.data(using: .utf8) else {
    throw MCPConversationFlowTestError.invalidUTF8
  }
  return try JSONDecoder().decode(T.self, from: data)
}

private func errorMessage(_ error: any Error) -> String {
  let localized = (error as NSError).localizedDescription
  if localized.isEmpty {
    return String(describing: error)
  }
  return localized
}
