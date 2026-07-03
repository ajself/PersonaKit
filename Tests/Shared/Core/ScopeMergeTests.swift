import Foundation
import Testing

@testable import ContextCore

struct ScopeMergeTests {
  @Test
  func projectOverridesGlobalPersona() throws {
    let root = try makeTempDirectory()
    let home = try makeTempDirectory()
    let projectScope = root.appendingPathComponent(".personakit")
    let globalScope = home.appendingPathComponent(".personakit")

    try writePersona(
      id: "shared-persona",
      name: "Project Persona",
      summary: "Project summary",
      root: projectScope
    )
    try writePersona(
      id: "shared-persona",
      name: "Global Persona",
      summary: "Global summary",
      root: globalScope
    )

    let scopes = ScopeSet(projectScopeURL: projectScope, globalScopeURL: globalScope)
    let registry = try Registry.load(scopes: scopes)

    #expect(registry.personasById["shared-persona"]?.name == "Project Persona")
    #expect(registry.personasById["shared-persona"]?.summary == "Project summary")
  }

  @Test
  func projectOverridesGlobalDirective() throws {
    let root = try makeTempDirectory()
    let home = try makeTempDirectory()
    let projectScope = root.appendingPathComponent(".personakit")
    let globalScope = home.appendingPathComponent(".personakit")

    try writeDirective(
      id: "shared-directive",
      title: "Project Directive",
      goal: "Project goal",
      root: projectScope
    )
    try writeDirective(
      id: "shared-directive",
      title: "Global Directive",
      goal: "Global goal",
      root: globalScope
    )

    let scopes = ScopeSet(projectScopeURL: projectScope, globalScopeURL: globalScope)
    let registry = try Registry.load(scopes: scopes)

    #expect(registry.directivesById["shared-directive"]?.title == "Project Directive")
    #expect(registry.directivesById["shared-directive"]?.goal == "Project goal")
  }

  @Test
  func essentialResolvesFromGlobalWhenMissingInProject() throws {
    let root = try makeTempDirectory()
    let home = try makeTempDirectory()
    let projectScope = root.appendingPathComponent(".personakit")
    let globalScope = home.appendingPathComponent(".personakit")

    try writeBasicScopeMergeFixture(
      projectScope: projectScope,
      globalScope: globalScope,
      globalEssentialContent: "# Global Essential\n"
    )

    let scopes = ScopeSet(projectScopeURL: projectScope, globalScopeURL: globalScope)
    let registry = try Registry.load(scopes: scopes)
    let resolved = try resolveBasicScopeMergeSession(registry: registry, scopes: scopes)
    let resolvedEssential = try #require(
      resolved.essentials.first(where: { $0.id == "shared-essential" })
    )
    let expectedPath =
      globalScope
      .appendingPathComponent("Packs/essentials/shared-essential.md")
      .standardizedFileURL.path

    #expect(resolved.essentials.count == 3)
    #expect(resolvedEssential.url.standardizedFileURL.path == expectedPath)
  }

  @Test
  func essentialResolvesFromProjectWhenPresentInBoth() throws {
    let root = try makeTempDirectory()
    let home = try makeTempDirectory()
    let projectScope = root.appendingPathComponent(".personakit")
    let globalScope = home.appendingPathComponent(".personakit")

    try writeBasicScopeMergeFixture(
      projectScope: projectScope,
      projectEssentialContent: "# Project Essential\n",
      globalScope: globalScope,
      globalEssentialContent: "# Global Essential\n"
    )

    let scopes = ScopeSet(projectScopeURL: projectScope, globalScopeURL: globalScope)
    let registry = try Registry.load(scopes: scopes)
    let resolved = try resolveBasicScopeMergeSession(registry: registry, scopes: scopes)
    let resolvedEssential = try #require(
      resolved.essentials.first(where: { $0.id == "shared-essential" })
    )
    let expectedPath =
      projectScope
      .appendingPathComponent("Packs/essentials/shared-essential.md")
      .standardizedFileURL.path

    #expect(resolved.essentials.count == 3)
    #expect(resolvedEssential.url.standardizedFileURL.path == expectedPath)
  }

  @Test
  func essentialResolvesFromProjectWhenUsingRelativeScopeURLs() throws {
    let root = try makeTempDirectory()
    let home = try makeTempDirectory()
    let projectScope = URL(
      fileURLWithPath: "project/.personakit",
      relativeTo: root
    ).standardizedFileURL
    let globalScope = URL(
      fileURLWithPath: "global/.personakit",
      relativeTo: home
    ).standardizedFileURL

    try writeBasicScopeMergeFixture(
      projectScope: projectScope,
      projectEssentialContent: "# Project Essential\n",
      globalScope: globalScope,
      globalEssentialContent: "# Global Essential\n"
    )

    let scopes = ScopeSet(projectScopeURL: projectScope, globalScopeURL: globalScope)
    let registry = try Registry.load(scopes: scopes)
    let resolved = try resolveBasicScopeMergeSession(registry: registry, scopes: scopes)
    let resolvedEssential = try #require(
      resolved.essentials.first(where: { $0.id == "shared-essential" })
    )
    let expectedProjectEssentialPath =
      projectScope
      .appendingPathComponent("Packs/essentials/shared-essential.md")
      .standardizedFileURL.path
    let unexpectedGlobalEssentialPath =
      globalScope
      .appendingPathComponent("Packs/essentials/shared-essential.md")
      .standardizedFileURL.path

    #expect(resolved.essentials.count == 3)
    #expect(resolvedEssential.url.standardizedFileURL.path == expectedProjectEssentialPath)
    #expect(resolvedEssential.url.standardizedFileURL.path != unexpectedGlobalEssentialPath)
  }
}

private func basicScopeMergeDefinition() -> SessionDefinition {
  SessionDefinition(
    personaId: "persona",
    directiveId: "directive",
    kitOverrides: nil
  )
}

private func resolveBasicScopeMergeSession(
  registry: Registry,
  scopes: ScopeSet
) throws -> ResolvedSession {
  try Resolver.resolve(
    definition: basicScopeMergeDefinition(),
    registry: registry,
    scopes: scopes
  )
}

private func writeBasicScopeMergeFixture(
  projectScope: URL,
  projectEssentialContent: String? = nil,
  globalScope: URL? = nil,
  globalEssentialContent: String? = nil
) throws {
  try writePersona(
    id: "persona",
    name: "Project Persona",
    summary: "Project summary",
    defaultKitIds: ["kit"],
    root: projectScope
  )
  try writeKit(
    id: "kit",
    name: "Project Kit",
    summary: "Project summary",
    essentialIds: ["shared-essential"],
    root: projectScope
  )
  try writeDirective(
    id: "directive",
    title: "Directive",
    goal: "Goal",
    root: projectScope
  )
  if let projectEssentialContent {
    try writeEssential(
      id: "shared-essential",
      content: projectEssentialContent,
      root: projectScope
    )
  }

  if let globalScope, let globalEssentialContent {
    try writeEssential(
      id: "shared-essential",
      content: globalEssentialContent,
      root: globalScope
    )
  }
}

private func writePersona(
  id: String,
  name: String,
  summary: String,
  defaultKitIds: [String] = [],
  root: URL
) throws {
  let directory = root.appendingPathComponent("Packs/personas")
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  let json = """
    {
      \"id\": \"\(id)\",
      \"version\": \"1.0\",
      \"name\": \"\(name)\",
      \"summary\": \"\(summary)\",
      \"responsibilities\": [],
      \"values\": [],
      \"nonGoals\": [],
      \"defaultKitIds\": \(jsonArray(defaultKitIds)),
      \"allowedSkillIds\": [],
      \"forbiddenSkillIds\": []
    }
    """
  try Data(json.utf8).write(to: directory.appendingPathComponent("\(id).persona.json"))
}

private func writeKit(
  id: String,
  name: String,
  summary: String,
  essentialIds: [String],
  root: URL
) throws {
  let directory = root.appendingPathComponent("Packs/kits")
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  let json = """
    {
      \"id\": \"\(id)\",
      \"version\": \"1.0\",
      \"name\": \"\(name)\",
      \"summary\": \"\(summary)\",
      \"essentialIds\": \(jsonArray(essentialIds))
    }
    """
  try Data(json.utf8).write(to: directory.appendingPathComponent("\(id).kit.json"))
}

private func writeDirective(
  id: String,
  title: String,
  goal: String,
  root: URL
) throws {
  let directory = root.appendingPathComponent("Packs/directives")
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  let json = """
    {
      \"id\": \"\(id)\",
      \"version\": \"1.0\",
      \"title\": \"\(title)\",
      \"goal\": \"\(goal)\",
      \"steps\": [],
      \"acceptanceCriteria\": [],
      \"verification\": [],
      \"requiresSkillIds\": []
    }
    """
  try Data(json.utf8).write(to: directory.appendingPathComponent("\(id).directive.json"))
}

private func writeEssential(
  id: String,
  content: String,
  root: URL
) throws {
  let directory = root.appendingPathComponent("Packs/essentials")
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  try Data(content.utf8).write(to: directory.appendingPathComponent("\(id).md"))
}

private func jsonArray(_ values: [String]) -> String {
  let escaped = values.map { value in
    "\"" + value.replacingOccurrences(of: "\"", with: "\\\"") + "\""
  }
  return "[" + escaped.joined(separator: ", ") + "]"
}
