import Foundation
import Testing

@testable import PersonaKitCore

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
    try writeEssential(
      id: "shared-essential",
      content: "# Global Essential\n",
      root: globalScope
    )

    let scopes = ScopeSet(projectScopeURL: projectScope, globalScopeURL: globalScope)
    let registry = try Registry.load(scopes: scopes)
    let definition = SessionDefinition(personaId: "persona", directiveId: "directive", kitOverrides: nil)
    let resolved = try Resolver.resolve(definition: definition, registry: registry, scopes: scopes)

    #expect(resolved.essentials.count == 1)
    #expect(
      resolved.essentials.first?.url.standardizedFileURL.path
        == globalScope
        .appendingPathComponent("Packs/essentials/shared-essential.md")
        .standardizedFileURL.path
    )
  }

  @Test
  func essentialResolvesFromProjectWhenPresentInBoth() throws {
    let root = try makeTempDirectory()
    let home = try makeTempDirectory()
    let projectScope = root.appendingPathComponent(".personakit")
    let globalScope = home.appendingPathComponent(".personakit")

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
    try writeEssential(
      id: "shared-essential",
      content: "# Project Essential\n",
      root: projectScope
    )
    try writeEssential(
      id: "shared-essential",
      content: "# Global Essential\n",
      root: globalScope
    )

    let scopes = ScopeSet(projectScopeURL: projectScope, globalScopeURL: globalScope)
    let registry = try Registry.load(scopes: scopes)
    let definition = SessionDefinition(personaId: "persona", directiveId: "directive", kitOverrides: nil)
    let resolved = try Resolver.resolve(definition: definition, registry: registry, scopes: scopes)

    #expect(resolved.essentials.count == 1)
    #expect(
      resolved.essentials.first?.url.standardizedFileURL.path
        == projectScope
        .appendingPathComponent("Packs/essentials/shared-essential.md")
        .standardizedFileURL.path
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
      \"requiresIntentTemplateIds\": [],
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
