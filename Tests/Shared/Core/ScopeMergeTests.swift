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

private func jsonArray(_ values: [String]) -> String {
  let escaped = values.map { value in
    "\"" + value.replacingOccurrences(of: "\"", with: "\\\"") + "\""
  }
  return "[" + escaped.joined(separator: ", ") + "]"
}
