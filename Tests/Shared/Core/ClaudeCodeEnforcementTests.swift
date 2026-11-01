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
      ClaudeCodeHookCheckEvaluator.evaluate(
        toolName: "mcp__personakit__personakit_resolve_contract",
        manifest: readOnly
      ).permission == .allow
    )
    #expect(
      ClaudeCodeHookCheckEvaluator.evaluate(
        toolName: "mcp__personakit__personakit_export",
        manifest: readOnly
      ).permission == .allow
    )
  }

  @Test
  func evaluatorAsksForPersonaKitNamedToolsFromOtherServers() {
    let readOnly = manifest(forbiddenCapabilities: ["edit-files"])
    #expect(
      ClaudeCodeHookCheckEvaluator.evaluate(
        toolName: "mcp__evil__personakit_validate",
        manifest: readOnly
      ).permission == .ask
    )
    #expect(
      ClaudeCodeHookCheckEvaluator.evaluate(
        toolName: "mcp__personakit__personakit_export_all",
        manifest: readOnly
      ).permission == .ask
    )
    #expect(
      ClaudeCodeHookCheckEvaluator.evaluate(
        toolName: "mcp__personakit__xpersonakit_export",
        manifest: readOnly
      ).permission == .ask
    )
    #expect(
      ClaudeCodeHookCheckEvaluator.evaluate(
        toolName: "mcp__personakit__write_file",
        manifest: readOnly
      ).permission == .ask
    )
  }

  @Test
  func evaluatorTrustsOnlyTheRecordedServerName() {
    let custom = manifest(forbiddenCapabilities: ["edit-files"]).withMCPServerName("pk-local")
    #expect(
      ClaudeCodeHookCheckEvaluator.evaluate(
        toolName: "mcp__pk-local__personakit_export",
        manifest: custom
      ).permission == .allow
    )
    #expect(
      ClaudeCodeHookCheckEvaluator.evaluate(
        toolName: "mcp__personakit__personakit_export",
        manifest: custom
      ).permission == .ask
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
  func rendererRoutesEveryToolUnderReadOnlyStance() {
    let artifacts = ClaudeCodeEnforcementRenderer.render(
      manifest: manifest(forbiddenCapabilities: ["edit-files", "run-commands"]),
      executablePath: "/usr/local/bin/personakit",
      manifestPath: "/proj/.claude/personakit/s.checks.json"
    )

    // Every tool reaches the checker, so one it cannot classify is put to the operator instead of slipping past.
    #expect(artifacts.matcher == ".*")
    #expect(artifacts.isInstallable)
    // Command values are always single-quoted so no path metacharacter can reach the shell.
    #expect(
      artifacts.hookEntry?.hooks.first?.command
        == "'/usr/local/bin/personakit' hook-check --manifest '/proj/.claude/personakit/s.checks.json' "
        + ClaudeCodeEnforcement.failClosedSuffix
    )
    #expect(artifacts.degradedActionClasses.isEmpty)
    // An explicit timeout keeps the checker's own deadline well inside Claude Code's.
    #expect(artifacts.hookEntry?.hooks.first?.timeout == ClaudeCodeEnforcement.hookTimeoutSeconds)
    #expect(ClaudeCodeEnforcement.checkerDeadlineSeconds * 2 < ClaudeCodeEnforcement.hookTimeoutSeconds)
  }

  @Test
  func mergerWritesTheHookTimeout() throws {
    let merged = try ClaudeCodeSettingsMerger.merge(
      existingSettings: nil,
      hookEntry: ClaudeCodeHookMatcher(
        matcher: ".*",
        hooks: [ClaudeCodeHookCommand(command: "pk hook-check --manifest /m.json", timeout: 60)]
      )
    )
    let root = try #require(JSONSerialization.jsonObject(with: merged) as? [String: Any])
    let hooks = try #require(root["hooks"] as? [String: Any])
    let entry = try #require((hooks["PreToolUse"] as? [[String: Any]])?.first)
    let hook = try #require((entry["hooks"] as? [[String: Any]])?.first)

    #expect(hook["timeout"] as? Int == 60)
  }

  @Test
  func rendererRoutesFileToolsEvenWhenEditsAreAllowed() {
    let artifacts = ClaudeCodeEnforcementRenderer.render(
      manifest: manifest(forbiddenCapabilities: ["run-commands"]),
      executablePath: "personakit",
      manifestPath: "/proj/.claude/personakit/s.checks.json"
    )

    // Edits are allowed, but the checker still sees them so it can protect its own files.
    #expect(artifacts.matcher == ".*")
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
        == "'personakit' hook-check --manifest '/proj/.claude/personakit/evil;$(touch pwned).checks.json' "
        + ClaudeCodeEnforcement.failClosedSuffix
    )
  }

  /// Runs a rendered hook command the way Claude Code does, through `/bin/sh -c`.
  private func runHookShell(_ command: String) throws -> (status: Int32, stdout: String, stderr: String) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/sh")
    process.arguments = ["-c", command]
    let stdout = Pipe()
    let stderr = Pipe()
    process.standardInput = FileHandle.nullDevice
    process.standardOutput = stdout
    process.standardError = stderr
    try process.run()
    process.waitUntilExit()
    return (
      process.terminationStatus,
      String(decoding: stdout.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self),
      String(decoding: stderr.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
    )
  }

  /// Writes an executable stub script and returns its path.
  private func writeStub(_ body: String) throws -> String {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("pk-stub-\(UUID().uuidString)")
    try ("#!/bin/sh\n" + body + "\n").write(to: url, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
    return url.path
  }

  private func renderedCommand(executablePath: String) throws -> String {
    let artifacts = ClaudeCodeEnforcementRenderer.render(
      manifest: manifest(forbiddenCapabilities: ["run-commands"]),
      executablePath: executablePath,
      manifestPath: "/proj/.claude/personakit/s.checks.json"
    )
    return try #require(artifacts.hookEntry?.hooks.first?.command)
  }

  @Test
  func hookCommandExitsTwoWhenTheCheckerIsMissing() throws {
    // Claude Code lets a call through on any non-zero exit but 2, so a missing binary (127) must still block.
    let result = try runHookShell(renderedCommand(executablePath: "/nonexistent-\(UUID().uuidString)/personakit"))

    #expect(result.status == 2)
    #expect(result.stderr.contains("PersonaKit could not check this tool call, so it is blocked."))
  }

  @Test
  func hookCommandExitsTwoWhenTheCheckerFails() throws {
    let stub = try writeStub("echo partial; exit 1")
    defer { try? FileManager.default.removeItem(atPath: stub) }

    let result = try runHookShell(renderedCommand(executablePath: stub))

    #expect(result.status == 2)
    #expect(result.stderr.contains("personakit hook-check failed"))
  }

  @Test
  func hookCommandPassesTheCheckersDecisionThrough() throws {
    let stub = try writeStub(#"echo '{"decision":"from-checker"}'"#)
    defer { try? FileManager.default.removeItem(atPath: stub) }

    let result = try runHookShell(renderedCommand(executablePath: stub))

    #expect(result.status == 0)
    #expect(result.stdout == "{\"decision\":\"from-checker\"}\n")
    #expect(result.stderr.isEmpty)
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

    #expect(ClaudeCodeHookCheckEvaluator.evaluate(toolName: "Read", manifest: readOnly).permission == .allow)
    #expect(ClaudeCodeHookCheckEvaluator.evaluate(toolName: "Grep", manifest: readOnly).permission == .allow)

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
  func evaluatorAsksTheOperatorForUnclassifiedMCPToolUnderReadOnly() {
    let readOnly = manifest(forbiddenCapabilities: ["edit-files", "run-commands"])

    // An un-enumerated MCP write/exec tool cannot bypass a read-only contract: the operator decides.
    let decision = ClaudeCodeHookCheckEvaluator.evaluate(toolName: "mcp__fs__write_file", manifest: readOnly)
    #expect(decision.permission == .ask)
    #expect(decision.reason?.hasPrefix("PersonaKit contract needs approval:") == true)
    #expect(decision.reason?.contains("capability-deny.run-commands, capability-deny.edit-files") == true)
    #expect(decision.reason?.contains("explicitly allow") == false)
    #expect(decision.reason?.contains("--mcp-server") == false)
  }

  @Test
  func evaluatorAskForPersonaKitNamedToolHintsAtServerName() {
    let readOnly = manifest(forbiddenCapabilities: ["edit-files"])

    let decision = ClaudeCodeHookCheckEvaluator.evaluate(
      toolName: "mcp__pk-local__personakit_export",
      manifest: readOnly
    )
    #expect(decision.permission == .ask)
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
    #expect(decision.permission == .ask)
    #expect(decision.reason?.contains("--mcp-server") == false)
  }

  @Test
  func evaluatorAllowsMCPToolWhenNoMCPRelevantCapabilityIsForbidden() {
    // autonomous-loop is not something an MCP file/exec/network tool is denied for.
    let looseManifest = manifest(forbiddenCapabilities: ["autonomous-loop"])
    #expect(
      ClaudeCodeHookCheckEvaluator.evaluate(toolName: "mcp__fs__write_file", manifest: looseManifest).permission
        == .allow
    )

    // With no forbidden capabilities at all, MCP tools are allowed.
    let openManifest = manifest(forbiddenCapabilities: [])
    #expect(
      ClaudeCodeHookCheckEvaluator.evaluate(toolName: "mcp__fs__write_file", manifest: openManifest).permission
        == .allow
    )
  }

  @Test
  func evaluatorDeniesMonitorAndPowerShellWhenCommandsAreForbidden() {
    let noCommands = manifest(forbiddenCapabilities: ["run-commands"])
    // Monitor and PowerShell run shell commands, so they are command execution like Bash.
    #expect(ClaudeCodeHookCheckEvaluator.evaluate(toolName: "Monitor", manifest: noCommands).permission == .deny)
    #expect(ClaudeCodeHookCheckEvaluator.evaluate(toolName: "PowerShell", manifest: noCommands).permission == .deny)

    let editOnly = manifest(forbiddenCapabilities: ["edit-files"])
    #expect(ClaudeCodeHookCheckEvaluator.evaluate(toolName: "Monitor", manifest: editOnly).permission == .allow)
  }

  @Test(arguments: ClaudeCodeEnforcement.readOnlyTools)
  func evaluatorAllowsReadOnlyBuiltInsUnderReadOnly(toolName: String) {
    let readOnly = manifest(forbiddenCapabilities: ["edit-files", "run-commands", "network-access"])
    #expect(ClaudeCodeHookCheckEvaluator.evaluate(toolName: toolName, manifest: readOnly).permission == .allow)
  }

  @Test(arguments: ["Artifact", "CronCreate", "EnterWorktree", "RemoteTrigger", "Skill", "SomeFutureTool", "read"])
  func evaluatorAsksTheOperatorForBuiltInsItCannotClassify(toolName: String) {
    let readOnly = manifest(forbiddenCapabilities: ["edit-files", "run-commands"])
    let decision = ClaudeCodeHookCheckEvaluator.evaluate(toolName: toolName, manifest: readOnly)
    #expect(decision.permission == .ask)
    #expect(decision.reason?.contains("cannot classify tool '\(toolName)'") == true)

    // Nothing an unclassified tool could do is forbidden, so there is nothing to ask about.
    let loose = manifest(forbiddenCapabilities: ["autonomous-loop"])
    #expect(ClaudeCodeHookCheckEvaluator.evaluate(toolName: toolName, manifest: loose).permission == .allow)
  }

  @Test
  func denialTellsTheAgentNotToWorkAround() {
    let readOnly = manifest(forbiddenCapabilities: ["run-commands"])
    let reason = ClaudeCodeHookCheckEvaluator.evaluate(toolName: "Bash", manifest: readOnly).reason
    #expect(reason?.contains("Do not retry it through another tool or a workaround") == true)
  }

  @Test
  func readOnlyToolsAreSortedAndNeverClassified() {
    #expect(ClaudeCodeEnforcement.readOnlyTools == ClaudeCodeEnforcement.readOnlyTools.sorted())
    #expect(ClaudeCodeEnforcement.readOnlyTools.allSatisfy { ClaudeCodeEnforcement.actionClass(forTool: $0) == nil })
  }

  private func evaluateCall(
    _ call: ClaudeCodeToolCall,
    forbidding capabilities: [String] = ["edit-files", "run-commands"]
  ) -> ClaudeCodeHookCheckDecision {
    ClaudeCodeHookCheckEvaluator.evaluate(
      call,
      manifest: manifest(forbiddenCapabilities: capabilities),
      protectedPaths: ["/proj/.claude/personakit/"],
      homeDirectory: "/home/u"
    )
  }

  @Test(arguments: ["Agent", "Task"])
  func evaluatorAsksAboutSubagentsWithIsolation(toolName: String) {
    // A local subagent's tool calls reach the hook; a worktree writes a branch and a remote one escapes the hook.
    #expect(evaluateCall(ClaudeCodeToolCall(toolName: toolName, paths: [], cwd: "/proj")).permission == .allow)
    #expect(
      evaluateCall(ClaudeCodeToolCall(toolName: toolName, paths: [], cwd: "/proj", isolation: "")).permission == .allow
    )
    for isolation in ["worktree", "remote"] {
      let decision = evaluateCall(ClaudeCodeToolCall(toolName: toolName, paths: [], cwd: "/proj", isolation: isolation))
      #expect(decision.permission == .ask)
      #expect(decision.reason?.contains("tool '\(toolName)' with isolation '\(isolation)'") == true)
    }
  }

  @Test(arguments: ["Agent", "Task"])
  func evaluatorAsksAboutSubagentsThatAreNotBuiltInLocalTypes(toolName: String) {
    for type in ClaudeCodeEnforcement.localSubagentTypes.sorted() {
      #expect(
        evaluateCall(ClaudeCodeToolCall(toolName: toolName, paths: [], cwd: nil, subagentType: type)).permission
          == .allow,
        "\(type)"
      )
    }
    // A custom or plugin agent can carry its own isolation, so it goes to the operator.
    for type in ["cloud-worker", "claude-security:explore", "explore", "(not a string)"] {
      let decision = evaluateCall(ClaudeCodeToolCall(toolName: toolName, paths: [], cwd: nil, subagentType: type))
      #expect(decision.permission == .ask, "\(type)")
      #expect(decision.reason?.contains("with agent type '\(type)'") == true)
    }
    // Isolation is asked about even on a built-in type, and denied when prompts are bypassed.
    #expect(
      evaluateCall(
        ClaudeCodeToolCall(toolName: toolName, paths: [], cwd: nil, isolation: "Worktree", subagentType: "Explore")
      ).permission == .ask
    )
    #expect(
      evaluateCall(
        ClaudeCodeToolCall(
          toolName: toolName,
          paths: [],
          cwd: nil,
          isolation: "remote",
          permissionMode: "bypassPermissions"
        )
      ).permission == .deny
    )
  }

  @Test
  func evaluatorAllowsMCPResourcesFromACustomTrustedServerName() {
    let custom = manifest(forbiddenCapabilities: ["edit-files"]).withMCPServerName("pk-local")
    func decide(_ server: String) -> ClaudeCodeHookCheckDecision.Permission {
      ClaudeCodeHookCheckEvaluator.evaluate(
        ClaudeCodeToolCall(toolName: "ReadMcpResourceTool", paths: [], cwd: nil, mcpServer: server),
        manifest: custom,
        protectedPaths: [],
        homeDirectory: nil
      ).permission
    }
    #expect(decide("pk-local") == .allow)
    #expect(decide("personakit") == .ask)
    #expect(decide(" pk-local") == .ask)
  }

  @Test(arguments: ["ListMcpResourcesTool", "ReadMcpResourceDirTool", "ReadMcpResourceTool"])
  func evaluatorAllowsMCPResourcesOnlyFromTheTrustedServer(toolName: String) {
    #expect(
      evaluateCall(ClaudeCodeToolCall(toolName: toolName, paths: [], cwd: nil, mcpServer: "personakit")).permission
        == .allow
    )
    #expect(
      evaluateCall(ClaudeCodeToolCall(toolName: toolName, paths: [], cwd: nil, mcpServer: "other")).permission == .ask
    )
    #expect(evaluateCall(ClaudeCodeToolCall(toolName: toolName, paths: [], cwd: nil)).permission == .ask)
  }

  @Test
  func evaluatorDeniesInsteadOfAskingWhenPromptsAreBypassed() {
    let bypassed = evaluateCall(
      ClaudeCodeToolCall(toolName: "CronCreate", paths: [], cwd: nil, permissionMode: "bypassPermissions")
    )
    #expect(bypassed.permission == .deny)
    #expect(bypassed.reason?.contains("skipping permission prompts") == true)
    #expect(bypassed.reason?.contains("cannot classify tool 'CronCreate'") == true)

    // Every other mode keeps the ask; Claude Code refuses it wherever no one can answer.
    for mode in ["default", "acceptEdits", "auto", "dontAsk", "plan"] {
      let decision = evaluateCall(ClaudeCodeToolCall(toolName: "CronCreate", paths: [], cwd: nil, permissionMode: mode))
      #expect(decision.permission == .ask, "\(mode)")
    }
    // An allow stays an allow.
    #expect(
      evaluateCall(ClaudeCodeToolCall(toolName: "Read", paths: [], cwd: nil, permissionMode: "bypassPermissions"))
        .permission == .allow
    )
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

  private static let personaKitEntry = ClaudeCodeHookMatcher(
    matcher: ".*",
    hooks: [ClaudeCodeHookCommand(command: "pk hook-check --manifest /m.json", timeout: 60)]
  )

  @Test
  func removalRestoresSettingsInstallMergedInto() throws {
    let existing = try JSONSerialization.data(
      withJSONObject: [
        "model": "opus",
        "hooks": [
          "PreToolUse": [["matcher": "WebFetch", "hooks": [["type": "command", "command": "other-tool"]]]],
          "PostToolUse": [["matcher": "Edit", "hooks": [] as [Any]]],
        ],
      ],
      options: [.prettyPrinted, .sortedKeys]
    )

    let merged = try ClaudeCodeSettingsMerger.merge(existingSettings: existing, hookEntry: Self.personaKitEntry)

    #expect(try ClaudeCodeSettingsMerger.removingPersonaKitEntries(from: merged) == .write(existing))
  }

  @Test
  func removalDeletesSettingsThatHeldOnlyTheHook() throws {
    let merged = try ClaudeCodeSettingsMerger.merge(existingSettings: nil, hookEntry: Self.personaKitEntry)

    #expect(try ClaudeCodeSettingsMerger.removingPersonaKitEntries(from: merged) == .deleteFile)
  }

  @Test
  func removalKeepsOtherHooksSharingAPersonaKitGroup() throws {
    let existing = Data(
      """
      {"hooks":{"PreToolUse":[{"matcher":".*","hooks":[{"type":"command","command":"pk hook-check --manifest /m.json"},\
      {"type":"command","command":"audit-log"}]}]}}
      """.utf8
    )

    let removal = try ClaudeCodeSettingsMerger.removingPersonaKitEntries(from: existing)

    guard case .write(let data) = removal else {
      Issue.record("Expected settings to write, got \(removal)")
      return
    }
    let root = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    let preToolUse = try #require((root["hooks"] as? [String: Any])?["PreToolUse"] as? [[String: Any]])
    let commands = preToolUse.flatMap { ($0["hooks"] as? [[String: Any]]) ?? [] }.compactMap { $0["command"] }
    #expect(commands as? [String] == ["audit-log"])
    #expect(preToolUse.first?["matcher"] as? String == ".*")
  }

  @Test
  func removalLeavesSettingsWithoutAPersonaKitHookAlone() throws {
    let foreign = Data(
      """
      {"hooks":{"PreToolUse":[{"matcher":"Bash","hooks":[{"type":"command","command":"run-hook-check-lint"}]}]}}
      """.utf8
    )

    #expect(try ClaudeCodeSettingsMerger.removingPersonaKitEntries(from: foreign) == .nothingToRemove)
    #expect(
      try ClaudeCodeSettingsMerger.removingPersonaKitEntries(from: Data(#"{"hooks":7}"#.utf8)) == .nothingToRemove
    )
    #expect(try ClaudeCodeSettingsMerger.removingPersonaKitEntries(from: Data()) == .nothingToRemove)
    #expect(try ClaudeCodeSettingsMerger.removingPersonaKitEntries(from: nil) == .nothingToRemove)
  }

  @Test(arguments: ["not json", "[1, 2]"])
  func removalRejectsSettingsThatAreNotAJSONObject(text: String) {
    #expect(throws: ClaudeCodeSettingsMerger.MergeError.invalidExistingSettings) {
      try ClaudeCodeSettingsMerger.removingPersonaKitEntries(from: Data(text.utf8))
    }
  }
}
