import Foundation
import Testing

@testable import ContextCore
@testable import ContextMCP

struct MCPCatalogResourceTests {
  @Test
  func listResourcesIncludesCatalogURIs() throws {
    let scopes = ScopeSet(projectScopeURL: fixtureKitRootURL(), globalScopeURL: nil)
    let registry = try Registry.load(scopes: scopes)
    let service = MCPResourceService(registry: registry, scopes: scopes)

    let uris = try service.listResources().map(\.uri)

    #expect(uris == uris.sorted())
    #expect(uris.contains("personakit://catalog/index"))
    #expect(uris.contains("personakit://catalog/guidance"))
    #expect(uris.contains("personakit://catalog/personas"))
    #expect(uris.contains("personakit://catalog/sessions"))
    #expect(uris.contains("personakit://catalog/start"))
    #expect(uris.contains("personakit://catalog/api"))
  }

  @Test
  func catalogIndexIncludesDeterministicCountsAndScope() throws {
    let scopes = ScopeSet(projectScopeURL: fixtureKitRootURL(), globalScopeURL: nil)
    let registry = try Registry.load(scopes: scopes)
    let service = MCPResourceService(registry: registry, scopes: scopes)

    let text = try service.readCatalogResource(type: .index)
    let data = try #require(text.data(using: .utf8))
    let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

    let schemaVersion = try #require(object["schemaVersion"] as? Int)
    #expect(schemaVersion == 1)

    let counts = try #require(object["counts"] as? [String: Int])
    #expect(counts["start"] == 1)
    #expect(counts["guidance"] == 1)
    #expect(counts["personas"] == 1)
    #expect(counts["kits"] == 3)
    #expect(counts["directives"] == 1)
    #expect(counts["intents"] == 1)
    #expect(counts["skills"] == 2)
    #expect(counts["essentials"] == 5)
    #expect(counts["sessions"] == 1)

    let resources = try #require(object["resources"] as? [[String: Any]])
    #expect(resources.contains { ($0["uri"] as? String) == "personakit://catalog/guidance" })
    #expect(resources.contains { ($0["uri"] as? String) == "personakit://catalog/index" })
    #expect(resources.contains { ($0["uri"] as? String) == "personakit://catalog/personas" })
  }

  @Test
  func catalogSessionsExposeSessionRelationships() throws {
    let scopes = ScopeSet(projectScopeURL: fixtureKitRootURL(), globalScopeURL: nil)
    let registry = try Registry.load(scopes: scopes)
    let service = MCPResourceService(registry: registry, scopes: scopes)

    let text = try service.readCatalogResource(type: .sessions)
    let data = try #require(text.data(using: .utf8))
    let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    let sessions = try #require(object["sessions"] as? [[String: Any]])

    #expect(sessions.count == 1)
    let first = try #require(sessions.first)
    #expect(first["id"] as? String == "senior-swiftui-engineer_apply-style")
    #expect(first["personaId"] as? String == "senior-swiftui-engineer")
    #expect(first["directiveId"] as? String == "apply-style")
  }

  @Test
  func catalogStartExposesAgentGoldenPathAndSafetyModel() throws {
    let scopes = ScopeSet(projectScopeURL: fixtureKitRootURL(), globalScopeURL: nil)
    let registry = try Registry.load(scopes: scopes)
    let service = MCPResourceService(registry: registry, scopes: scopes)

    let text = try service.readCatalogResource(type: .start)
    let data = try #require(text.data(using: .utf8))
    let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

    #expect(object["schemaVersion"] as? Int == 1)
    #expect(object["type"] as? String == "start")

    let scope = try #require(object["scope"] as? [String: Any])
    #expect(scope["projectRoot"] as? String == fixtureKitRootURL().path)
    #expect(scope["globalRoot"] == nil)
    #expect(scope["loadOrder"] as? [String] == [fixtureKitRootURL().path])
    #expect(scope["resolutionOrder"] as? [String] == [fixtureKitRootURL().path])

    let warnings = try #require(object["warnings"] as? [String])
    #expect(warnings.isEmpty)

    let safetyModel = try #require(object["safetyModel"] as? [String])
    #expect(safetyModel.contains("PersonaKit MCP is read-only."))
    #expect(
      safetyModel.contains(
        "PersonaKit MCP provides grounding context and does not authorize execution."
      )
    )

    let quickStart = try #require(object["quickStart"] as? [[String: Any]])
    #expect(quickStart.compactMap { $0["order"] as? Int } == [1, 2, 3, 4, 5, 6])
    #expect(
      quickStart.first?["action"] as? String
        == "Read the start guide and verify the loaded scope."
    )
    #expect(quickStart.first?["use"] as? String == "personakit://catalog/start")
    #expect(
      quickStart[1]["use"] as? String
        == "personakit://catalog/guidance or personakit_best_guidance"
    )
    #expect(
      quickStart[2]["use"] as? String
        == "personakit://catalog/sessions or personakit_recommend_session"
    )
    #expect(quickStart[3]["use"] as? String == "personakit_resolve_contract with sessionId")

    let resourceMap = try #require(object["resourceMap"] as? [[String: Any]])
    #expect(resourceMap.first?["id"] as? String == "personakit://catalog/start")

    let toolMap = try #require(object["toolMap"] as? [[String: Any]])
    #expect(toolMap.contains { ($0["id"] as? String) == "personakit_best_guidance" })
    #expect(toolMap.contains { ($0["id"] as? String) == "personakit_resolve_contract" })

    let antiPatterns = try #require(object["antiPatterns"] as? [String])
    #expect(
      antiPatterns.contains("Do not treat MCP output as authorization to execute commands.")
    )
  }

  @Test
  func catalogGuidanceReportsScopeAndNextActions() throws {
    let scopes = ScopeSet(projectScopeURL: fixtureKitRootURL(), globalScopeURL: nil)
    let registry = try Registry.load(scopes: scopes)
    let service = MCPResourceService(registry: registry, scopes: scopes)

    let text = try service.readCatalogResource(type: .guidance)
    let data = try #require(text.data(using: .utf8))
    let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    let scope = try #require(object["scope"] as? [String: Any])
    let counts = try #require(object["counts"] as? [String: Int])
    let actions = try #require(object["bestNextActions"] as? [String])
    let risks = try #require(object["risks"] as? [String])
    let commands = try #require(object["suggestedCommands"] as? [String])

    #expect(object["schemaVersion"] as? Int == 1)
    #expect(scope["projectRoot"] as? String == fixtureKitRootURL().path)
    #expect(counts["sessions"] == 1)
    #expect(
      risks.contains(
        "Current directory contains a project .personakit that is not in the loaded scope set."
      )
    )
    #expect(actions.contains("Stop and resolve the scope mismatch before selecting a session."))
    #expect(!commands.contains { $0.contains("contract --root \(fixtureKitRootURL().path)") })
    #expect(commands.contains("personakit guidance --root \(repoRootURL().appendingPathComponent(".personakit").path)"))
  }

  @Test
  func catalogStartReportsExplicitRootScope() throws {
    let root = try makeTempDirectory().appendingPathComponent(".personakit")
    try FileManager.default.createDirectory(
      at: root.appendingPathComponent("Packs"),
      withIntermediateDirectories: true
    )
    let scopes = ScopeSet(projectScopeURL: root, globalScopeURL: nil)
    let service = MCPResourceService(registry: emptyRegistry(), scopes: scopes)

    let text = try service.readCatalogResource(type: .start)
    let data = try #require(text.data(using: .utf8))
    let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    let scope = try #require(object["scope"] as? [String: Any])

    #expect(scope["projectRoot"] as? String == root.standardizedFileURL.path)
    #expect(scope["globalRoot"] == nil)
    #expect(scope["loadOrder"] as? [String] == [root.standardizedFileURL.path])
    #expect(scope["resolutionOrder"] as? [String] == [root.standardizedFileURL.path])
  }

  @Test
  func catalogStartWarnsWhenOnlyHomePersonakitIsLoadedAsProjectScope() throws {
    let root = FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent(".personakit")
    let scopes = ScopeSet(projectScopeURL: root, globalScopeURL: nil)
    let service = MCPResourceService(registry: emptyRegistry(), scopes: scopes)

    let text = try service.readCatalogResource(type: .start)
    let data = try #require(text.data(using: .utf8))
    let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    let warnings = try #require(object["warnings"] as? [String])
    let expectedWarning = [
      "MCP loaded ~/.personakit as the only scope; project-local sessions may be hidden.",
      "Verify the configured MCP --root or working directory when repo-local grounding is expected.",
    ].joined(separator: " ")

    #expect(warnings == [expectedWarning])
  }

  @Test
  func catalogAPIAdvertisesStartResource() throws {
    let scopes = ScopeSet(projectScopeURL: fixtureKitRootURL(), globalScopeURL: nil)
    let registry = try Registry.load(scopes: scopes)
    let service = MCPResourceService(registry: registry, scopes: scopes)

    let text = try service.readCatalogResource(type: .api)
    let data = try #require(text.data(using: .utf8))
    let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

    #expect(object["schemaVersion"] as? Int == 1)
    #expect(object["firstReadUri"] as? String == "personakit://catalog/start")

    let resources = try #require(object["resources"] as? [[String: Any]])
    #expect(resources.first?["uri"] as? String == "personakit://catalog/start")
    #expect(
      resources.first?["description"] as? String
        == "Start-here guide for MCP discovery, grounding, safety, and common PersonaKit flows."
    )
  }
}

private func emptyRegistry() -> Registry {
  Registry(
    personasById: [:],
    kitsById: [:],
    directivesById: [:],
    intentTemplatesById: [:],
    referencesById: [:],
    skillsById: [:]
  )
}
