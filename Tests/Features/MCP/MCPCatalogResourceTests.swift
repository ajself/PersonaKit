import ContextCore
import Foundation
import Testing

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
    #expect(uris.contains("personakit://catalog/personas"))
    #expect(uris.contains("personakit://catalog/sessions"))
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
    #expect(counts["personas"] == 1)
    #expect(counts["kits"] == 3)
    #expect(counts["directives"] == 1)
    #expect(counts["intents"] == 1)
    #expect(counts["skills"] == 2)
    #expect(counts["essentials"] == 5)
    #expect(counts["sessions"] == 1)

    let resources = try #require(object["resources"] as? [[String: Any]])
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
}
