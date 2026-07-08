import ArgumentParser
import ContextCore
import Foundation
import MCP
import Testing

@testable import ContextCLI
@testable import ContextMCP

struct CLIMCPScopeResolutionTests {
  @Test
  func rootFlagWinsOverEnvironmentAndDiscovery() throws {
    let workspace = try makeTempDirectory()
    let projectScope = workspace.appendingPathComponent(".personakit")
    let globalHome = try makeTempDirectory()
    let globalScope = globalHome.appendingPathComponent(".personakit")
    let envRoot = try makeTempDirectory().appendingPathComponent("EnvRoot")
    let flagRoot = try makeTempDirectory().appendingPathComponent("FlagRoot")

    try createKitRoot(projectScope)
    try createKitRoot(globalScope)
    try createKitRoot(envRoot)
    try createKitRoot(flagRoot)

    let options = makeScopeOptions(rootPath: flagRoot.path)
    let scopes = try CLIHelpers.resolveMCPScopes(
      options: options,
      environment: ["PERSONAKIT_ROOT": envRoot.path],
      currentDirectoryPath: workspace.path,
      homeDirectory: globalHome
    )

    #expect(scopes.projectScopeURL?.path == flagRoot.path)
    #expect(scopes.globalScopeURL == nil)
  }

  @Test
  func environmentRootUsedWhenRootFlagMissing() throws {
    let workspace = try makeTempDirectory()
    let envRoot = try makeTempDirectory().appendingPathComponent("EnvRoot")
    let globalHome = try makeTempDirectory()
    let globalScope = globalHome.appendingPathComponent(".personakit")

    try createKitRoot(envRoot)
    try createKitRoot(globalScope)

    let scopes = try CLIHelpers.resolveMCPScopes(
      options: makeScopeOptions(),
      environment: ["PERSONAKIT_ROOT": envRoot.path],
      currentDirectoryPath: workspace.path,
      homeDirectory: globalHome
    )

    #expect(scopes.projectScopeURL?.path == envRoot.path)
    #expect(scopes.globalScopeURL == nil)
  }

  @Test
  func personakitRootOverrideRequiresPersonakitRoot() throws {
    do {
      _ = try CLIHelpers.resolveMCPScopes(
        options: makeScopeOptions(),
        environment: ["PERSONAKIT_ROOT_OVERRIDE": "1"]
      )
      #expect(Bool(false))
    } catch let error as ArgumentParser.ValidationError {
      #expect(error.message.contains("PERSONAKIT_ROOT_OVERRIDE requires PERSONAKIT_ROOT"))
    }
  }

  @Test
  func localProjectAndGlobalScopesMergedWhenBothExist() throws {
    let workspace = try makeTempDirectory()
    let nestedWorkspace = workspace.appendingPathComponent("a/b/c")
    let projectScope = workspace.appendingPathComponent(".personakit")
    let globalHome = try makeTempDirectory()
    let globalScope = globalHome.appendingPathComponent(".personakit")

    try FileManager.default.createDirectory(at: nestedWorkspace, withIntermediateDirectories: true)
    try createKitRoot(projectScope)
    try createKitRoot(globalScope)

    let scopes = try CLIHelpers.resolveMCPScopes(
      options: makeScopeOptions(),
      currentDirectoryPath: nestedWorkspace.path,
      homeDirectory: globalHome
    )

    #expect(scopes.projectScopeURL?.path == projectScope.path)
    #expect(scopes.globalScopeURL?.path == globalScope.path)
  }

  @Test
  func globalScopeUsedWhenProjectMissing() throws {
    let workspace = try makeTempDirectory()
    let globalHome = try makeTempDirectory()
    let globalScope = globalHome.appendingPathComponent(".personakit")

    try createKitRoot(globalScope)

    let scopes = try CLIHelpers.resolveMCPScopes(
      options: makeScopeOptions(),
      currentDirectoryPath: workspace.path,
      homeDirectory: globalHome
    )

    #expect(scopes.projectScopeURL == nil)
    #expect(scopes.globalScopeURL?.path == globalScope.path)
  }

  @Test
  func noGlobalBlocksGlobalFallback() throws {
    let workspace = try makeTempDirectory()
    let globalHome = try makeTempDirectory()
    let globalScope = globalHome.appendingPathComponent(".personakit")

    try createKitRoot(globalScope)

    do {
      _ = try CLIHelpers.resolveMCPScopes(
        options: makeScopeOptions(noGlobal: true),
        currentDirectoryPath: workspace.path,
        homeDirectory: globalHome
      )
      #expect(Bool(false))
    } catch let error as ArgumentParser.ValidationError {
      #expect(error.message.contains("No PersonaKit scope found for MCP"))
    }
  }

  @Test
  func noProjectSkipsProjectAndUsesGlobal() throws {
    let workspace = try makeTempDirectory()
    let projectScope = workspace.appendingPathComponent(".personakit")
    let globalHome = try makeTempDirectory()
    let globalScope = globalHome.appendingPathComponent(".personakit")

    try createKitRoot(projectScope)
    try createKitRoot(globalScope)

    let scopes = try CLIHelpers.resolveMCPScopes(
      options: makeScopeOptions(noProject: true),
      currentDirectoryPath: workspace.path,
      homeDirectory: globalHome
    )

    #expect(scopes.projectScopeURL == nil)
    #expect(scopes.globalScopeURL?.path == globalScope.path)
  }

  @Test
  func invalidOverrideRootMissingPacksFailsFast() throws {
    let root = try makeTempDirectory()

    do {
      _ = try CLIHelpers.resolveMCPScopes(
        options: makeScopeOptions(rootPath: root.path)
      )
      #expect(Bool(false))
    } catch let error as ArgumentParser.ValidationError {
      #expect(error.message.contains("must contain Packs/"))
    }
  }

  @Test
  func missingScopesProduceDeterministicError() throws {
    let workspace = try makeTempDirectory()
    let home = try makeTempDirectory()

    do {
      _ = try CLIHelpers.resolveMCPScopes(
        options: makeScopeOptions(),
        currentDirectoryPath: workspace.path,
        homeDirectory: home
      )
      #expect(Bool(false))
    } catch let error as ArgumentParser.ValidationError {
      #expect(error.message.contains("No PersonaKit scope found for MCP"))
    }
  }

  /// Regression for the `personakit mcp` global-scope bug: when a project
  /// `.personakit` exists, MCP startup must still merge the global scope so that
  /// global entities are visible and project entities can reference global kits.
  /// Previously `resolveMCPScopes` returned project-only, so global entities were
  /// invisible and any cross-scope contract failed to resolve.
  @Test
  func localMcpResourcesAndExportMergeGlobalScopeWhenProjectExists() throws {
    let workspace = try makeTempDirectory()
    let projectScope = workspace.appendingPathComponent(".personakit")
    let globalHome = try makeTempDirectory()
    let globalScope = globalHome.appendingPathComponent(".personakit")

    // Project persona depends on a kit that only exists in the global scope.
    try writePersona(
      id: "architectural-editor",
      name: "Architectural Editor",
      root: projectScope,
      defaultKitIds: ["global-shared-kit"]
    )
    try writeDirective(
      id: "review-architecture-invariants",
      title: "Review Architecture Invariants",
      root: projectScope
    )

    try writePersona(
      id: "global-only-persona",
      name: "Global Only Persona",
      root: globalScope
    )
    try writeKit(
      id: "global-shared-kit",
      name: "Global Shared Kit",
      root: globalScope
    )

    let scopes = try CLIHelpers.resolveMCPScopes(
      options: makeScopeOptions(),
      currentDirectoryPath: workspace.path,
      homeDirectory: globalHome
    )
    let registry = try Registry.load(scopes: scopes)
    let resourceService = MCPResourceService(registry: registry, scopes: scopes)
    let resources = try resourceService.listResources().map(\.name)

    #expect(resources.contains("architectural-editor"))
    #expect(resources.contains("global-only-persona"))

    let toolService = MCPToolService(scopes: scopes)
    let result = try toolService.callTool(
      name: "personakit_export",
      arguments: [
        "personaId": .string("architectural-editor"),
        "directiveId": .string("review-architecture-invariants"),
      ]
    )

    // Export succeeds only because the project persona's global kit resolved
    // across the merged scopes.
    let output = try #require(firstText(result))
    #expect(output.contains("architectural-editor"))
    #expect(output.contains("global-shared-kit"))
  }

  /// Guards that `personakit contract` (CLI) and the `personakit_resolve_contract`
  /// MCP tool emit byte-identical JSON for equivalent inputs. Parity holds today only
  /// by construction (both call `SessionContractResolver.snapshot(from:scopes:)` and
  /// encode with `[.prettyPrinted, .sortedKeys]`); this pins it so a future divergence
  /// on either surface fails the suite. Equivalent scopes: CLI `--root X` and MCP
  /// `ScopeSet(projectScopeURL: X, globalScopeURL: nil)` both resolve project-only.
  @Test
  func contractCLIAndMCPToolEmitByteIdenticalJSON() throws {
    let root = fixtureKitRootURL()
    let sessionId = "senior-swiftui-engineer_apply-style"
    let requestedSkillIds = ["codex-cli", "missing-skill"]

    var status: Int32 = 0
    let cliOutput = captureStdout {
      status = PersonaKitCLI().run(arguments: [
        "personakit",
        "contract",
        "--root",
        root.path,
        "--session",
        sessionId,
        "--check-skills",
        requestedSkillIds.joined(separator: ","),
      ])
    }
    #expect(status == 0)

    let scopes = ScopeSet(projectScopeURL: root, globalScopeURL: nil)
    let service = MCPToolService(scopes: scopes)
    let result = try service.callTool(
      name: "personakit_resolve_contract",
      arguments: [
        "sessionId": .string(sessionId),
        "requestedSkillIds": .array(requestedSkillIds.map { .string($0) }),
      ]
    )
    let mcpOutput = try #require(firstText(result))

    // Normalize only the trailing newline: CLI emits via `print` (adds one), the MCP
    // tool returns the raw encoded text. Everything else must match byte-for-byte.
    func trimmingTrailingNewline(_ value: String) -> String {
      value.hasSuffix("\n") ? String(value.dropLast()) : value
    }

    #expect(trimmingTrailingNewline(cliOutput) == trimmingTrailingNewline(mcpOutput))
  }
}

private func makeScopeOptions(
  rootPath: String? = nil,
  noProject: Bool = false,
  noGlobal: Bool = false
) -> ScopeOptions {
  var options = ScopeOptions()
  options.rootPath = rootPath
  options.noProject = noProject
  options.noGlobal = noGlobal
  return options
}

private func createKitRoot(_ root: URL) throws {
  try FileManager.default.createDirectory(
    at: root.appendingPathComponent("Packs"),
    withIntermediateDirectories: true
  )
}

private func writePersona(
  id: String,
  name: String,
  root: URL,
  defaultKitIds: [String] = []
) throws {
  let directory = root.appendingPathComponent("Packs/personas")
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  let kitIdsJSON = defaultKitIds.map { "\"\($0)\"" }.joined(separator: ", ")
  let json = """
    {
      "id": "\(id)",
      "version": "1.0",
      "name": "\(name)",
      "summary": "Summary",
      "responsibilities": [],
      "values": [],
      "nonGoals": [],
      "defaultKitIds": [\(kitIdsJSON)],
      "allowedSkillIds": [],
      "forbiddenSkillIds": []
    }
    """
  try Data(json.utf8).write(to: directory.appendingPathComponent("\(id).persona.json"))
}

private func writeKit(
  id: String,
  name: String,
  root: URL
) throws {
  let directory = root.appendingPathComponent("Packs/kits")
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  let json = """
    {
      "id": "\(id)",
      "version": "1.0",
      "name": "\(name)",
      "summary": "Summary",
      "skillIds": []
    }
    """
  try Data(json.utf8).write(to: directory.appendingPathComponent("\(id).kit.json"))
}

private func writeDirective(
  id: String,
  title: String,
  root: URL
) throws {
  let directory = root.appendingPathComponent("Packs/directives")
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  let json = """
    {
      "id": "\(id)",
      "version": "1.0",
      "title": "\(title)",
      "goal": "Goal",
      "steps": [],
      "acceptanceCriteria": [],
      "verification": [],
      "requiresSkillIds": []
    }
    """
  try Data(json.utf8).write(to: directory.appendingPathComponent("\(id).directive.json"))
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
