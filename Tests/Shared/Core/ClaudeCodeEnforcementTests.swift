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
