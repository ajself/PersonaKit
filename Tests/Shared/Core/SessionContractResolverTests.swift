import Foundation
import Testing

@testable import ContextCore

struct SessionContractResolverTests {
  @Test
  func resolveSnapshotPreservesInjectedContractOrderingAndRequestedSkillClassification() throws {
    let scopes = ScopeSet(projectScopeURL: fixtureKitRootURL(), globalScopeURL: nil)

    let result = try SessionContractResolver.resolve(
      scopes: scopes,
      personaId: "senior-swiftui-engineer",
      directiveId: "apply-style",
      kitOverrides: [],
      requestedSkillIds: [
        "missing-skill",
        "codex-cli",
        "autonomous-agent-loop",
      ]
    )
    let snapshot = SessionContractResolver.snapshot(from: result, scopes: scopes)

    #expect(snapshot.scope.mode == "project-only")
    #expect(snapshot.scope.projectRoot == fixtureKitRootURL().standardizedFileURL.path)
    #expect(snapshot.scope.globalRoot == nil)
    #expect(snapshot.scope.resolutionOrder == [fixtureKitRootURL().standardizedFileURL.path])
    #expect(snapshot.personaId == "senior-swiftui-engineer")
    #expect(snapshot.directiveId == "apply-style")
    #expect(snapshot.kitIds == ["repo-constraints", "swift-style", "swiftui-style"])
    #expect(
      snapshot.injectedContractIds == [
        "persona-activation-contract",
        "skill-authorization-contract",
      ]
    )
    #expect(snapshot.requestedSkillIds == ["autonomous-agent-loop", "codex-cli", "missing-skill"])
    #expect(snapshot.undeclaredRequestedSkillIds == ["missing-skill"])
    #expect(snapshot.unauthorizedRequestedSkillIds == ["autonomous-agent-loop"])
    #expect(
      snapshot.failureReasons == [
        "requested skill autonomous-agent-loop is declared in PersonaKit but not authorized by persona senior-swiftui-engineer",
        "requested skill missing-skill is not declared in PersonaKit",
      ]
    )
    #expect(snapshot.isAuthorized == false)
  }

  @Test
  func resolveWithoutDirectiveKeepsPersonaKitCoverageButNoDirectiveDrivenRequirements() throws {
    let scopes = ScopeSet(projectScopeURL: fixtureKitRootURL(), globalScopeURL: nil)

    let result = try SessionContractResolver.resolve(
      scopes: scopes,
      personaId: "senior-swiftui-engineer",
      directiveId: nil,
      kitOverrides: []
    )

    #expect(result.directive == nil)
    #expect(result.kits.map(\.id) == ["repo-constraints", "swift-style", "swiftui-style"])
    #expect(
      result.availableGroundingSkills.map(\.id) == [
        "swift-style-guide-reference",
        "swiftui-style-guide-reference",
        "tools-and-constraints",
      ]
    )
    #expect(result.skills.isEmpty)
    #expect(result.skillAuthorization.requiredSkillIds.isEmpty)
    #expect(result.skillAuthorization.authorizedSkillIds == ["codex-cli"])
    #expect(
      result.injectedContractIds == [
        "persona-activation-contract",
        "skill-authorization-contract",
      ]
    )
  }

  @Test
  func resolveWithoutDirectiveKeepsKitCapabilitySkillsOutOfRequirements() throws {
    let root = try makeTempDirectory().appendingPathComponent("PersonaKit")
    try copyFixtureKit(to: root)
    try Data(
      """
      {
        "id": "kit-tool",
        "version": "1.0",
        "name": "Kit Tool",
        "description": "Capability skill only a kit declares.",
        "capabilities": ["run-commands"]
      }
      """.utf8
    ).write(to: root.appendingPathComponent("Packs/skills/kit-tool.skill.json"))
    try Data(
      """
      {
        "id": "repo-constraints",
        "version": "1.0",
        "name": "Repository Constraints Kit",
        "summary": "Rules specific to this codebase.",
        "skillIds": ["kit-tool", "tools-and-constraints"]
      }
      """.utf8
    ).write(to: root.appendingPathComponent("Packs/kits/repo-constraints.kit.json"))
    let scopes = ScopeSet(projectScopeURL: root, globalScopeURL: nil)

    let personaOnly = try SessionContractResolver.resolve(
      scopes: scopes,
      personaId: "senior-swiftui-engineer",
      directiveId: nil,
      kitOverrides: []
    )
    let withDirective = try SessionContractResolver.resolve(
      scopes: scopes,
      personaId: "senior-swiftui-engineer",
      directiveId: "apply-style",
      kitOverrides: []
    )

    #expect(personaOnly.skills.isEmpty)
    #expect(personaOnly.availableGroundingSkills.map(\.id).contains("tools-and-constraints"))
    #expect(withDirective.skills.map(\.id) == ["codex-cli", "kit-tool"])
  }

  @Test
  func resolveMissingScopesFailsWithDeterministicRegistryError() {
    let scopes = ScopeSet(projectScopeURL: nil, globalScopeURL: nil)

    do {
      _ = try SessionContractResolver.resolve(
        scopes: scopes,
        personaId: "senior-swiftui-engineer",
        directiveId: "apply-style",
        kitOverrides: []
      )
      Issue.record("Expected missing-scope registry failure.")
    } catch let error as RegistryLoadError {
      #expect(
        error.errors == [
          RegistryError(
            relativePath: "Packs",
            entityType: .packsRoot,
            id: nil,
            message: "Missing Packs directory."
          )
        ]
      )
    } catch {
      Issue.record("Unexpected error: \(error)")
    }
  }

  @Test
  func contractScopeSnapshotReportsClosedModeVocabularyAndPrecedence() {
    let project = URL(fileURLWithPath: "/tmp/project/.personakit")
    let global = URL(fileURLWithPath: "/tmp/global/.personakit")

    let merged = ResolvedContractScopeSnapshot(
      scopes: ScopeSet(projectScopeURL: project, globalScopeURL: global)
    )
    #expect(merged.mode == "merged")
    #expect(merged.projectRoot == project.path)
    #expect(merged.globalRoot == global.path)
    #expect(merged.loadOrder == [global.path, project.path])
    #expect(merged.resolutionOrder == [project.path, global.path])

    let projectOnly = ResolvedContractScopeSnapshot(
      scopes: ScopeSet(projectScopeURL: project, globalScopeURL: nil)
    )
    #expect(projectOnly.mode == "project-only")
    #expect(projectOnly.globalRoot == nil)

    let globalOnly = ResolvedContractScopeSnapshot(
      scopes: ScopeSet(projectScopeURL: nil, globalScopeURL: global)
    )
    #expect(globalOnly.mode == "global-only")
    #expect(globalOnly.projectRoot == nil)

    let none = ResolvedContractScopeSnapshot(
      scopes: ScopeSet(projectScopeURL: nil, globalScopeURL: nil)
    )
    #expect(none.mode == "none")
    #expect(none.loadOrder.isEmpty)
    #expect(none.resolutionOrder.isEmpty)
  }
}
