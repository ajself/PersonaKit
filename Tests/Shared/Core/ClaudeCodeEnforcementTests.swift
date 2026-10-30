import Foundation
import Testing

@testable import ContextCore

struct ClaudeCodeEnforcementTests {
  private func manifest(forbiddenCapabilities: [String]) -> ChecksManifest {
    ChecksManifestDeriver.derive(
      sessionId: "s",
      persona: Persona(
        id: "read-only-auditor",
        version: "1.0",
        name: "Read-Only Auditor",
        summary: "s",
        responsibilities: [],
        values: [],
        nonGoals: [],
        defaultKitIds: [],
        allowedSkillIds: [],
        forbiddenSkillIds: [],
        forbiddenCapabilities: forbiddenCapabilities
      ),
      directive: nil
    )
  }

  @Test
  func evaluatorAllowsPersonaKitToolsFromTrustedServer() {
    let readOnly = manifest(forbiddenCapabilities: ["edit-files"])
    #expect(
      !ClaudeCodeHookCheckEvaluator.evaluate(
        toolName: "mcp__personakit__personakit_resolve_contract",
        manifest: readOnly
      ).isDenied
    )
    #expect(
      !ClaudeCodeHookCheckEvaluator.evaluate(
        toolName: "mcp__personakit__personakit_export",
        manifest: readOnly
      ).isDenied
    )
  }

  @Test
  func evaluatorDeniesPersonaKitNamedToolsFromOtherServers() {
    let readOnly = manifest(forbiddenCapabilities: ["edit-files"])
    #expect(
      ClaudeCodeHookCheckEvaluator.evaluate(
        toolName: "mcp__evil__personakit_validate",
        manifest: readOnly
      ).isDenied
    )
    #expect(
      ClaudeCodeHookCheckEvaluator.evaluate(
        toolName: "mcp__personakit__personakit_export_all",
        manifest: readOnly
      ).isDenied
    )
    #expect(
      ClaudeCodeHookCheckEvaluator.evaluate(
        toolName: "mcp__personakit__xpersonakit_export",
        manifest: readOnly
      ).isDenied
    )
    #expect(
      ClaudeCodeHookCheckEvaluator.evaluate(
        toolName: "mcp__personakit__write_file",
        manifest: readOnly
      ).isDenied
    )
  }

  @Test
  func evaluatorTrustsOnlyTheRecordedServerName() {
    let custom = manifest(forbiddenCapabilities: ["edit-files"]).withMCPServerName("pk-local")
    #expect(
      !ClaudeCodeHookCheckEvaluator.evaluate(
        toolName: "mcp__pk-local__personakit_export",
        manifest: custom
      ).isDenied
    )
    #expect(
      ClaudeCodeHookCheckEvaluator.evaluate(
        toolName: "mcp__personakit__personakit_export",
        manifest: custom
      ).isDenied
    )
  }

  @Test
  func manifestWithoutServerNameDecodesAndOmitsKey() throws {
    let original = manifest(forbiddenCapabilities: ["edit-files"])
    let data = try JSONEncoder().encode(original)
    #expect(!String(decoding: data, as: UTF8.self).contains("mcpServerName"))
    let decoded = try JSONDecoder().decode(ChecksManifest.self, from: data)
    #expect(decoded.mcpServerName == nil)
  }

  @Test
  func rendererMapsReadOnlyStanceToFileBashAndMCPMatcher() {
    let artifacts = ClaudeCodeEnforcementRenderer.render(
      manifest: manifest(forbiddenCapabilities: ["edit-files", "run-commands"]),
      executablePath: "/usr/local/bin/personakit",
      manifestPath: "/proj/.claude/personakit/s.checks.json"
    )

    // command-execution → Bash is the shell-bypass closure; mcp__.* closes the MCP bypass.
    #expect(artifacts.matcher == "Edit|Write|NotebookEdit|Bash|mcp__.*")
    #expect(artifacts.isInstallable)
    // Command values are always single-quoted so no path metacharacter can reach the shell.
    #expect(
      artifacts.hookEntry?.hooks.first?.command
        == "'/usr/local/bin/personakit' hook-check --manifest '/proj/.claude/personakit/s.checks.json'"
    )
    #expect(artifacts.degradedActionClasses.isEmpty)
  }

  @Test
  func rendererRoutesFileToolsEvenWhenEditsAreAllowed() {
    let artifacts = ClaudeCodeEnforcementRenderer.render(
      manifest: manifest(forbiddenCapabilities: ["run-commands"]),
      executablePath: "personakit",
      manifestPath: "/proj/.claude/personakit/s.checks.json"
    )

    // Edits are allowed, but the checker still sees them so it can protect its own files.
    #expect(artifacts.matcher == "Edit|Write|NotebookEdit|Bash|mcp__.*")
  }

  @Test
  func protectedPathsCoverManifestFolderSettingsConfigAndBinary() {
    #expect(
      ClaudeCodeEnforcement.protectedPaths(
        manifestPath: "/proj/.claude/personakit/s.checks.json",
        configDirectory: "/home/u/.claude",
        executablePath: "/opt/bin/personakit"
      ) == [
        "/home/u/.claude/settings.json",
        "/opt/bin/personakit",
        "/proj/.claude/personakit/",
        "/proj/.claude/settings.json",
        "/proj/.claude/settings.local.json",
      ]
    )
  }

  private func evaluate(
    _ tool: String,
    paths: [String],
    cwd: String? = "/proj",
    forbidding capabilities: [String] = ["run-commands"],
    in project: (root: String, protected: [String])
  ) -> ClaudeCodeHookCheckDecision {
    ClaudeCodeHookCheckEvaluator.evaluate(
      ClaudeCodeToolCall(toolName: tool, paths: paths, cwd: cwd),
      manifest: manifest(forbiddenCapabilities: capabilities),
      protectedPaths: project.protected,
      homeDirectory: project.root + "/home"
    )
  }

  /// A real project folder, so physical resolution sees actual files and links.
  private func makeProject() throws -> (root: String, protected: [String]) {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("pk-claude-\(UUID().uuidString)").resolvingSymlinksInPath().path
    try FileManager.default.createDirectory(atPath: root + "/.claude/personakit", withIntermediateDirectories: true)
    try Data("{}".utf8).write(to: URL(fileURLWithPath: root + "/.claude/personakit/s.checks.json"))
    let protected = ClaudeCodeEnforcement.protectedPaths(
      manifestPath: root + "/.claude/personakit/s.checks.json",
      configDirectory: root + "/home/.claude",
      executablePath: root + "/bin/personakit"
    )
    return (root, protected)
  }

  @Test
  func evaluatorDeniesEditsToEnforcementFilesWhenEditsAreAllowed() throws {
    let project = try makeProject()
    let root = project.root

    for path in [
      root + "/.claude/personakit/s.checks.json",
      root + "/.claude/personakit/other.checks.json",
      root + "/.claude/settings.json",
      root + "/.claude/settings.local.json",
      root + "/.CLAUDE/PersonaKit/s.checks.json",
      root + "/src/../.claude/settings.json",
      root + "/home/.claude/settings.json",
      root + "/bin/personakit",
    ] {
      let decision = evaluate("Write", paths: [path], in: project)
      #expect(decision.isDenied, "\(path)")
      #expect(decision.reason?.contains("enforcement files") == true, "\(path)")
    }

    #expect(!evaluate("Edit", paths: [root + "/src/a.swift"], in: project).isDenied)
    #expect(!evaluate("Write", paths: [root + "/.claude/commands/x.md"], in: project).isDenied)
  }

  @Test
  func evaluatorFollowsSymlinksToEnforcementFiles() throws {
    let project = try makeProject()
    let root = project.root
    try FileManager.default.createSymbolicLink(
      atPath: root + "/link.json",
      withDestinationPath: root + "/.claude/personakit/s.checks.json"
    )

    #expect(evaluate("Edit", paths: [root + "/link.json"], in: project).isDenied)
  }

  @Test
  func evaluatorResolvesRelativeAndTildePaths() throws {
    let project = try makeProject()
    let root = project.root

    #expect(evaluate("Edit", paths: [".claude/settings.json"], cwd: root, in: project).isDenied)
    #expect(evaluate("Write", paths: ["~/.claude/settings.json"], in: project).isDenied)
    // Claude Code trims a tool's path before writing.
    #expect(evaluate("Write", paths: [" \(root)/.claude/settings.json\n"], in: project).isDenied)
    #expect(!evaluate("Edit", paths: ["src/a.swift"], cwd: root, in: project).isDenied)
    // A relative path with no working directory cannot be checked.
    #expect(evaluate("Edit", paths: ["src/a.swift"], cwd: nil, in: project).isDenied)
  }

  @Test
  func evaluatorDeniesFileEditsThatNameNoPath() throws {
    let project = try makeProject()

    #expect(evaluate("Edit", paths: [], in: project).reason?.contains("names no path") == true)
    #expect(evaluate("NotebookEdit", paths: [""], in: project).isDenied)
    // Tools that are not file edits need no path.
    #expect(!evaluate("Read", paths: [], in: project).isDenied)
  }

  @Test
  func evaluatorChecksEveryPathAndStillAppliesTheContract() throws {
    let project = try makeProject()
    let root = project.root

    #expect(
      evaluate("NotebookEdit", paths: [root + "/a.ipynb", root + "/.claude/settings.json"], in: project)
        .isDenied
    )
    let readOnly = evaluate(
      "Edit",
      paths: [root + "/src/a.swift"],
      forbidding: ["edit-files"],
      in: project
    )
    #expect(readOnly.reason?.contains("performs file-mutation") == true)
    #expect(evaluate("Bash", paths: [], in: project).isDenied)
  }

  @Test
  func rendererShellQuotesPathsContainingMetacharacters() {
    let artifacts = ClaudeCodeEnforcementRenderer.render(
      manifest: manifest(forbiddenCapabilities: ["edit-files"]),
      executablePath: "personakit",
      manifestPath: "/proj/.claude/personakit/evil;$(touch pwned).checks.json"
    )

    // The `;$(…)` path component is fully contained inside single quotes — no injection.
    #expect(
      artifacts.hookEntry?.hooks.first?.command
        == "'personakit' hook-check --manifest '/proj/.claude/personakit/evil;$(touch pwned).checks.json'"
    )
  }

  @Test
  func rendererReportsDegradationEvenWhenNothingIsInstallable() {
    // autonomous-loop maps to no Claude Code tool: not installable, but must be reported.
    let artifacts = ClaudeCodeEnforcementRenderer.render(
      manifest: manifest(forbiddenCapabilities: ["autonomous-loop"]),
      executablePath: "personakit",
      manifestPath: "/m.json"
    )

    #expect(!artifacts.isInstallable)
    #expect(artifacts.hookEntry == nil)
    #expect(artifacts.degradedActionClasses == ["unattended-iteration"])
  }

  @Test
  func evaluatorDeniesForbiddenToolsIncludingBashAndAllowsReads() {
    let readOnly = manifest(forbiddenCapabilities: ["edit-files", "run-commands"])

    #expect(ClaudeCodeHookCheckEvaluator.evaluate(toolName: "Edit", manifest: readOnly).isDenied)
    #expect(ClaudeCodeHookCheckEvaluator.evaluate(toolName: "Write", manifest: readOnly).isDenied)
    #expect(ClaudeCodeHookCheckEvaluator.evaluate(toolName: "NotebookEdit", manifest: readOnly).isDenied)
    // The bypass test: Bash is denied because run-commands is forbidden.
    #expect(ClaudeCodeHookCheckEvaluator.evaluate(toolName: "Bash", manifest: readOnly).isDenied)

    #expect(!ClaudeCodeHookCheckEvaluator.evaluate(toolName: "Read", manifest: readOnly).isDenied)
    #expect(!ClaudeCodeHookCheckEvaluator.evaluate(toolName: "Grep", manifest: readOnly).isDenied)

    let bashReason = ClaudeCodeHookCheckEvaluator.evaluate(toolName: "Bash", manifest: readOnly).reason
    #expect(bashReason?.contains("capability-deny.run-commands") == true)
  }

  @Test
  func evaluatorAllowsBashWhenOnlyEditIsForbidden() {
    let editOnly = manifest(forbiddenCapabilities: ["edit-files"])

    #expect(ClaudeCodeHookCheckEvaluator.evaluate(toolName: "Edit", manifest: editOnly).isDenied)
    #expect(!ClaudeCodeHookCheckEvaluator.evaluate(toolName: "Bash", manifest: editOnly).isDenied)
  }

  @Test
  func evaluatorFailsClosedOnUnclassifiedMCPToolUnderReadOnly() {
    let readOnly = manifest(forbiddenCapabilities: ["edit-files", "run-commands"])

    // An un-enumerated MCP write/exec tool cannot bypass a read-only contract.
    let decision = ClaudeCodeHookCheckEvaluator.evaluate(toolName: "mcp__fs__write_file", manifest: readOnly)
    #expect(decision.isDenied)
    #expect(decision.reason?.contains("fail-closed") == true)
    #expect(decision.reason?.contains("--mcp-server") == false)
  }

  @Test
  func evaluatorDenialOfPersonaKitNamedToolHintsAtServerName() {
    let readOnly = manifest(forbiddenCapabilities: ["edit-files"])

    let decision = ClaudeCodeHookCheckEvaluator.evaluate(
      toolName: "mcp__pk-local__personakit_export",
      manifest: readOnly
    )
    #expect(decision.isDenied)
    #expect(decision.reason?.contains("`personakit enforce install --mcp-server pk-local`") == true)
    #expect(decision.reason?.contains("do not run it yourself") == true)
    #expect(decision.reason?.contains("`claude mcp get pk-local` shows it runs `personakit mcp`") == true)
  }

  @Test(arguments: [
    "mcp__a__b__personakit_export",
    "mcp____personakit_export",
    "mcp__personakit_export",
    "mcp__a b`x__personakit_export",
  ])
  func evaluatorOmitsHintWhenServerSegmentIsNotAValidServerName(toolName: String) {
    let decision = ClaudeCodeHookCheckEvaluator.evaluate(
      toolName: toolName,
      manifest: manifest(forbiddenCapabilities: ["edit-files"])
    )
    #expect(decision.isDenied)
    #expect(decision.reason?.contains("--mcp-server") == false)
  }

  @Test
  func evaluatorAllowsMCPToolWhenNoMCPRelevantCapabilityIsForbidden() {
    // autonomous-loop is not something an MCP file/exec/network tool is denied for.
    let looseManifest = manifest(forbiddenCapabilities: ["autonomous-loop"])
    #expect(!ClaudeCodeHookCheckEvaluator.evaluate(toolName: "mcp__fs__write_file", manifest: looseManifest).isDenied)

    // With no forbidden capabilities at all, MCP tools are allowed.
    let openManifest = manifest(forbiddenCapabilities: [])
    #expect(!ClaudeCodeHookCheckEvaluator.evaluate(toolName: "mcp__fs__write_file", manifest: openManifest).isDenied)
  }

  @Test
  func mergerCreatesHooksBlockFromEmptySettings() throws {
    let entry = ClaudeCodeHookMatcher(
      matcher: "Edit|Bash",
      hooks: [ClaudeCodeHookCommand(command: "pk hook-check --manifest /m.json")]
    )

    let data = try ClaudeCodeSettingsMerger.merge(existingSettings: nil, hookEntry: entry)
    let root = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    let hooks = try #require(root["hooks"] as? [String: Any])
    let preToolUse = try #require(hooks["PreToolUse"] as? [[String: Any]])

    #expect(preToolUse.count == 1)
    #expect(preToolUse[0]["matcher"] as? String == "Edit|Bash")
  }

  @Test
  func mergerPreservesUnrelatedContentAndIsIdempotent() throws {
    let existing = Data(
      """
      {"model":"opus","hooks":{"PreToolUse":[{"matcher":"WebFetch","hooks":[{"type":"command","command":"other-tool"}]}],"PostToolUse":[{"matcher":"Edit","hooks":[]}]}}
      """.utf8
    )
    let entry = ClaudeCodeHookMatcher(
      matcher: "Edit|Bash",
      hooks: [ClaudeCodeHookCommand(command: "pk hook-check --manifest /m.json")]
    )

    let once = try ClaudeCodeSettingsMerger.merge(existingSettings: existing, hookEntry: entry)
    let twice = try ClaudeCodeSettingsMerger.merge(existingSettings: once, hookEntry: entry)

    // Deterministic, idempotent bytes: a re-install replaces rather than duplicates.
    #expect(once == twice)

    let root = try #require(try JSONSerialization.jsonObject(with: twice) as? [String: Any])
    #expect(root["model"] as? String == "opus")

    let hooks = try #require(root["hooks"] as? [String: Any])
    #expect(hooks["PostToolUse"] != nil)

    let preToolUse = try #require(hooks["PreToolUse"] as? [[String: Any]])
    #expect(preToolUse.count == 2)

    let personaKitEntries = preToolUse.filter { entry in
      guard let entryHooks = entry["hooks"] as? [[String: Any]] else {
        return false
      }
      return entryHooks.contains { ($0["command"] as? String)?.contains("hook-check --manifest") == true }
    }
    #expect(personaKitEntries.count == 1)
  }

  @Test
  func mergerPreservesUnrelatedHookThatMerelyContainsHookCheckSubstring() throws {
    // A foreign hook whose command contains "hook-check" but not our full ownership marker
    // must survive a PersonaKit install.
    let existing = Data(
      """
      {"hooks":{"PreToolUse":[{"matcher":"Bash","hooks":[{"type":"command","command":"run-hook-check-lint"}]}]}}
      """.utf8
    )
    let entry = ClaudeCodeHookMatcher(
      matcher: "Edit",
      hooks: [ClaudeCodeHookCommand(command: "pk hook-check --manifest /m.json")]
    )

    let merged = try ClaudeCodeSettingsMerger.merge(existingSettings: existing, hookEntry: entry)
    let root = try #require(try JSONSerialization.jsonObject(with: merged) as? [String: Any])
    let hooks = try #require(root["hooks"] as? [String: Any])
    let preToolUse = try #require(hooks["PreToolUse"] as? [[String: Any]])

    // The unrelated hook is kept; our entry is added → two entries, not one.
    #expect(preToolUse.count == 2)
    let commands = preToolUse.flatMap { ($0["hooks"] as? [[String: Any]]) ?? [] }
      .compactMap { $0["command"] as? String }
    #expect(commands.contains("run-hook-check-lint"))
  }

  @Test
  func containsPersonaKitEntryDetectsOwnershipMarkerOnly() throws {
    let ours = Data(
      """
      {"hooks":{"PreToolUse":[{"matcher":"Edit","hooks":[{"type":"command","command":"pk hook-check --manifest /m.json"}]}]}}
      """.utf8
    )
    let foreign = Data(
      """
      {"hooks":{"PreToolUse":[{"matcher":"Bash","hooks":[{"type":"command","command":"run-hook-check-lint"}]}]}}
      """.utf8
    )

    #expect(ClaudeCodeSettingsMerger.containsPersonaKitEntry(in: ours))
    #expect(!ClaudeCodeSettingsMerger.containsPersonaKitEntry(in: foreign))
    #expect(!ClaudeCodeSettingsMerger.containsPersonaKitEntry(in: nil))
  }
}
