import ArgumentParser
import ContextCore
import ContextWorkspaceCore
import CryptoKit
import Foundation
import Synchronization

/// Claude Code `PreToolUse` payload — only the fields the checker needs.
private struct PreToolUsePayload: Decodable {
  let toolName: String?
  let toolInput: ToolInput?
  let cwd: String?
  let permissionMode: String?

  enum CodingKeys: String, CodingKey {
    case toolName = "tool_name"
    case toolInput = "tool_input"
    case cwd
    case permissionMode = "permission_mode"
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    toolName = try container.decodeIfPresent(String.self, forKey: .toolName)
    toolInput = try? container.decodeIfPresent(ToolInput.self, forKey: .toolInput)
    cwd = try? container.decodeIfPresent(String.self, forKey: .cwd)
    permissionMode = try? container.decodeIfPresent(String.self, forKey: .permissionMode)
  }

  /// The fields of `tool_input` the checker reads. Any tool's input is accepted: a field that is not a string
  /// reads as absent, and a file edit with no path is denied by the evaluator. A subagent's `isolation` or
  /// `subagent_type` that is present but not a string reads as an unknown value, so the call is asked about.
  struct ToolInput: Decodable {
    let filePath: String?
    let notebookPath: String?
    let isolation: String?
    let subagentType: String?
    let server: String?

    enum CodingKeys: String, CodingKey {
      case filePath = "file_path"
      case notebookPath = "notebook_path"
      case isolation
      case subagentType = "subagent_type"
      case server
    }

    init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      func presentString(_ key: CodingKeys) -> String? {
        guard container.contains(key), (try? container.decodeNil(forKey: key)) != true else { return nil }
        return (try? container.decode(String.self, forKey: key)) ?? "(not a string)"
      }
      filePath = try? container.decodeIfPresent(String.self, forKey: .filePath)
      notebookPath = try? container.decodeIfPresent(String.self, forKey: .notebookPath)
      isolation = presentString(.isolation)
      subagentType = presentString(.subagentType)
      server = try? container.decodeIfPresent(String.self, forKey: .server)
    }
  }
}

/// Claude Code hook decision output (`hookSpecificOutput.permissionDecision`).
private struct HookDecisionOutput: Encodable {
  struct Inner: Encodable {
    let hookEventName = "PreToolUse"
    let permissionDecision: String
    let permissionDecisionReason: String
  }

  let hookSpecificOutput: Inner
}

/// OpenCode deny output: `{"decision":"deny","reason":"…"}`.
private struct OpenCodeDecisionOutput: Encodable {
  let decision = "deny"
  let reason: String
}

/// Lets exactly one of the checker and its watchdog write the hook's answer.
final class HookDecisionGate: Sendable {
  private let claimed = Mutex(false)

  /// Whether the caller is first; only the first caller may write.
  func claim() -> Bool {
    claimed.withLock { claimed in
      guard !claimed else { return false }
      claimed = true
      return true
    }
  }
}

/// Host whose tool-call payload `hook-check` reads.
enum HookCheckHost: String, CaseIterable, ExpressibleByArgument {
  case claude
  case opencode
}

/// Runtime checker invoked by a Claude Code `PreToolUse` hook, or by the OpenCode server plugin.
///
/// Reads the tool call from stdin, consults a frozen checks manifest, and denies the call
/// when the tool performs a forbidden action class. For Claude Code, which routes every tool here,
/// it asks the operator about a tool it cannot classify. Read-only toward the agent: it can only
/// deny or ask, never authorize. Fail-closed: any internal error denies the call, including an
/// allowed file edit.
struct HookCheckCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "hook-check",
    abstract: "Evaluate a Claude Code or OpenCode tool call against a frozen checks manifest.",
    discussion: """
      Not run by hand. For Claude Code (--host claude, the default), `personakit enforce \
      install` wires this into a project's .claude/settings.json as a PreToolUse hook. For \
      OpenCode (--host opencode), the opencode-personakit server plugin runs it with \
      --expect-sha256. Either way it reads the tool call on stdin and emits a deny decision \
      when the session's contract forbids the tool. For Claude Code it emits an ask decision \
      for a tool it cannot classify.
      """
  )

  @Option(name: .customLong("manifest"), help: "Path to the frozen checks manifest to enforce.")
  var manifestPath: String

  @Option(name: .customLong("host"), help: "Host that sends the tool call: claude (default) or opencode.")
  var host: HookCheckHost = .claude

  @Option(
    name: .customLong("expect-sha256"),
    help: "Required for --host opencode: lowercase hex SHA-256 the manifest must match, recorded when OpenCode started."
  )
  var expectSHA256: String?

  mutating func validate() throws {
    if host == .opencode, expectSHA256?.isEmpty != false {
      throw ArgumentParser.ValidationError("hook-check --host opencode requires --expect-sha256 <hex>.")
    }
  }

  func run() throws {
    if host == .opencode {
      try runOpenCode()
      return
    }

    // Claude Code lets the call through when the hook outlives its timeout, so a stuck check denies on its own.
    let gate = HookDecisionGate()
    Self.startWatchdog(after: .seconds(ClaudeCodeEnforcement.checkerDeadlineSeconds), gate: gate) {
      print(Self.claudeOutputJSON(for: Self.missedDeadlineDecision))
      fflush(stdout)
      Foundation.exit(0)
    }

    let decision = Self.decide(manifestPath: manifestPath)

    guard gate.claim() else {
      // The watchdog is writing its deny and will exit; returning first would exit with no output, an allow.
      while true { sleep(60) }
    }

    guard decision.permission != .allow else {
      // Allow: exit 0 with no output lets Claude Code's normal permission flow proceed.
      return
    }

    print(Self.claudeOutputJSON(for: decision))
    // Deny and ask are communicated by the JSON above with exit 0; do not fail the process.
  }

  /// The reason for a deny that carries none. Every deny reason starts with one of the mod's drift markers
  /// (`DENY_MARKERS` in `Integrations/ClaudeCode/hooks/lib/drift.ts`), so the mod records the call as a block.
  static let fallbackDenyReason = "Blocked by PersonaKit contract: the enforcement check denied this call."

  /// The decision the watchdog emits when the check misses its deadline.
  static let missedDeadlineDecision = ClaudeCodeHookCheckDecision(
    isDenied: true,
    reason: failClosedReason(
      "PersonaKit enforcement could not reach a decision in time",
      fix: "ask for the call again and, if it keeps timing out, check that the personakit binary the hook runs works"
    )
  )

  /// A deny that is not the contract's: what failed, the fix the user would make, and the same instruction to stop
  /// that a contract deny ends with. `problem` keeps the prefix the mod and the docs key off.
  static func failClosedReason(_ problem: String, fix: String) -> String {
    "\(problem); denying by fail-closed policy. To fix it, the user can \(fix). "
      + ClaudeCodeHookCheckEvaluator.noWorkaroundInstruction
  }

  /// The reason for an encode failure, which only a PersonaKit update can address. It holds nothing JSON must escape,
  /// so the fallback output can embed it as is.
  private static let encodeFailureReason = failClosedReason(
    "PersonaKit enforcement could not encode its decision",
    fix: "update personakit"
  )

  /// Claude Code's `hookSpecificOutput` JSON for a deny or ask.
  static func claudeOutputJSON(for decision: ClaudeCodeHookCheckDecision) -> String {
    let output = HookDecisionOutput(
      hookSpecificOutput: HookDecisionOutput.Inner(
        permissionDecision: decision.permission.rawValue,
        // The host shows the reason to the operator after decoding it, so JSON escaping alone would not help.
        permissionDecisionReason: TerminalText.sanitized(decision.reason ?? Self.fallbackDenyReason)
      )
    )

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]

    if let data = try? encoder.encode(output), let json = String(data: data, encoding: .utf8) {
      return json
    }
    // An encode failure must not read as an allow (no output).
    return #"{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","#
      + #""permissionDecisionReason":""# + encodeFailureReason + #""}}"#
  }

  /// Runs `fire` after `delay` unless the checker claimed `gate` first.
  static func startWatchdog(
    after delay: DispatchTimeInterval,
    gate: HookDecisionGate,
    fire: @escaping @Sendable () -> Void
  ) {
    DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
      if gate.claim() {
        fire()
      }
    }
  }

  private func runOpenCode() throws {
    let decision = Self.decideOpenCode(manifestPath: manifestPath, expectedSHA256: expectSHA256 ?? "")

    // OpenCode output can only deny, so anything but an allow is a deny.
    guard decision.permission != .allow else {
      return
    }

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let output = OpenCodeDecisionOutput(
      reason: TerminalText.sanitized(decision.reason ?? Self.fallbackDenyReason)
    )

    if let data = try? encoder.encode(output), let json = String(data: data, encoding: .utf8) {
      print(json)
    } else {
      // An encode failure must not read as an allow (no output).
      print(#"{"decision":"deny","reason":""# + Self.encodeFailureReason + #""}"#)
    }
    // Deny is communicated by the JSON above with exit 0; do not fail the process.
  }

  /// OpenCode decision: verify the manifest digest, read the manifest and the tool call, evaluate.
  /// Fail-closed at every step.
  ///
  /// `environment` is the one OpenCode handed the hook, so the global config locations match OpenCode's.
  /// When it has no `HOME` (unset or empty), `passwdHome` supplies the passwd entry's home, as OpenCode
  /// falls back to it.
  /// `executablePath` is this binary: it is protected like a config file, because an agent allowed to edit
  /// could otherwise replace the checker with a stub that allows everything. No payload field supplies it.
  static func decideOpenCode(
    manifestPath: String,
    expectedSHA256: String,
    environment: [String: String] = ProcessInfo.processInfo.environment,
    executablePath: String? = Bundle.main.executableURL?.path,
    passwdHome: () -> String? = HookCheckCommand.passwdHomeDirectory
  ) -> ClaudeCodeHookCheckDecision {
    func failClosed(_ message: String, fix: String) -> ClaudeCodeHookCheckDecision {
      ClaudeCodeHookCheckDecision(isDenied: true, reason: failClosedReason(message, fix: fix))
    }
    let restart = "restart OpenCode to load the current contract"
    let reinstallPlugin =
      "reinstall the plugin with `make opencode-install` from the PersonaKit release that matches personakit, "
      + "then restart OpenCode"

    let manifestURL = RootPathResolver().resolve(path: manifestPath)
    // The path is shown in the deny reason, so it cannot carry terminal control characters.
    let shownPath = OpenCodeEnforcement.strippingControlCharacters(manifestURL.path)

    guard let data = try? Data(contentsOf: manifestURL) else {
      return failClosed(
        "Blocked by PersonaKit contract: PersonaKit enforcement manifest at \(shownPath) "
          + "is missing or changed since OpenCode started (it could not be read)",
        fix: restart
      )
    }

    let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    guard digest == expectedSHA256.lowercased() else {
      return failClosed(
        "Blocked by PersonaKit contract: PersonaKit enforcement manifest at \(shownPath) "
          + "changed since OpenCode started (its SHA-256 no longer matches)",
        fix: restart
      )
    }

    guard let manifest = try? JSONDecoder().decode(ChecksManifest.self, from: data) else {
      return failClosed(
        "PersonaKit enforcement could not decode its manifest at \(shownPath)",
        fix: "run `personakit enforce install --host opencode --session <id>` again, then restart OpenCode"
      )
    }

    let stdin: String
    do {
      stdin = try CLIEnvironment.current.interactiveIO.readStdinToEnd()
    } catch {
      return failClosed("PersonaKit enforcement could not read the tool call", fix: "restart OpenCode")
    }

    guard let call = try? JSONDecoder().decode(OpenCodeToolCall.self, from: Data(stdin.utf8)) else {
      return failClosed("PersonaKit enforcement could not parse the tool call", fix: reinstallPlugin)
    }

    let effectiveEnvironment = withAccountHome(environment, passwdHome: passwdHome)
    var protectedPaths = OpenCodeEnforcement.globalConfigPaths(environment: effectiveEnvironment)
    if let executablePath, !executablePath.isEmpty {
      // The evaluator compares each entry as spelled and as physically resolved, so a symlinked
      // executable protects the file it points at too.
      protectedPaths.append(executablePath)
    }

    return OpenCodeHookCheckEvaluator.evaluate(call, manifest: manifest, globalConfigPaths: protectedPaths)
  }

  /// The current user's home directory from the passwd database, the fallback OpenCode uses without `HOME`.
  static func passwdHomeDirectory() -> String? {
    guard let entry = getpwuid(getuid()), let directory = entry.pointee.pw_dir else {
      return nil
    }
    return String(cString: directory)
  }

  /// `environment` with `HOME` from `passwdHome` when it is unset or empty, the home OpenCode falls back to.
  static func withAccountHome(_ environment: [String: String], passwdHome: () -> String?) -> [String: String] {
    var effective = environment
    if environment["HOME"]?.isEmpty != false, let home = passwdHome(), !home.isEmpty {
      effective["HOME"] = home
    }
    return effective
  }

  /// Pure decision: read manifest + stdin, evaluate, fail-closed on any error.
  ///
  /// `executablePath` is this binary, protected like the manifest so an agent allowed to edit cannot swap
  /// the checker for a stub. Without `HOME`, `passwdHome` supplies the home, which locates `~/.claude`
  /// (unless `CLAUDE_CONFIG_DIR` is set) and expands a `~` in a tool's path.
  static func decide(
    manifestPath: String,
    environment: [String: String] = ProcessInfo.processInfo.environment,
    executablePath: String? = Bundle.main.executableURL?.path,
    passwdHome: () -> String? = HookCheckCommand.passwdHomeDirectory
  ) -> ClaudeCodeHookCheckDecision {
    let manifestURL = RootPathResolver().resolve(path: manifestPath)

    guard let data = try? Data(contentsOf: manifestURL),
      let manifest = try? JSONDecoder().decode(ChecksManifest.self, from: data)
    else {
      return ClaudeCodeHookCheckDecision(
        isDenied: true,
        reason: failClosedReason(
          "PersonaKit enforcement could not read its manifest at \(manifestURL.path)",
          fix: "run `personakit enforce install --session <id>` again, or `personakit enforce uninstall` to remove "
            + "the hook"
        )
      )
    }

    let stdin: String
    do {
      stdin = try CLIEnvironment.current.interactiveIO.readStdinToEnd()
    } catch {
      return ClaudeCodeHookCheckDecision(
        isDenied: true,
        reason: failClosedReason(
          "PersonaKit enforcement could not read the tool call",
          fix: "restart Claude Code and, if it keeps happening, update personakit"
        )
      )
    }

    guard let payload = try? JSONDecoder().decode(PreToolUsePayload.self, from: Data(stdin.utf8)),
      let toolName = payload.toolName
    else {
      return ClaudeCodeHookCheckDecision(
        isDenied: true,
        reason: failClosedReason(
          "PersonaKit enforcement could not parse the tool call",
          fix: "update personakit so it reads this Claude Code version's tool calls"
        )
      )
    }

    func value(_ key: String) -> String? {
      environment[key].flatMap { $0.isEmpty ? nil : $0 }
    }
    let home = value("HOME") ?? passwdHome().flatMap { $0.isEmpty ? nil : $0 }
    let configDirectory = value("CLAUDE_CONFIG_DIR") ?? home.map { $0 + "/.claude" }

    let call = ClaudeCodeToolCall(
      toolName: toolName,
      paths: [payload.toolInput?.filePath, payload.toolInput?.notebookPath].compactMap { $0 },
      cwd: payload.cwd,
      isolation: payload.toolInput?.isolation,
      subagentType: payload.toolInput?.subagentType,
      mcpServer: payload.toolInput?.server,
      permissionMode: payload.permissionMode
    )
    return ClaudeCodeHookCheckEvaluator.evaluate(
      call,
      manifest: manifest,
      protectedPaths: ClaudeCodeEnforcement.protectedPaths(
        manifestPath: manifestURL.path,
        configDirectory: configDirectory,
        executablePath: executablePath
      ),
      homeDirectory: home
    )
  }
}

/// Parent command grouping the enforcement install and uninstall subcommands.
struct EnforceCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "enforce",
    abstract: "Project a session contract into host enforcement.",
    subcommands: [EnforceInstallCommand.self, EnforceUninstallCommand.self]
  )
}

/// Installs host enforcement for a session — the explicit, one-time, reviewed step.
///
/// For Claude Code, writes a frozen manifest and merges a `PreToolUse` hook into `.claude/settings.json`.
/// For OpenCode, writes only the frozen manifest: the `opencode-personakit` server plugin is the hook,
/// and PersonaKit never edits OpenCode config. On both hosts, other `*.checks.json` files in the manifest folder
/// are removed so the project keeps one manifest.
/// PersonaKit never writes host config on its own; this runs only when invoked, prints
/// exactly what it changes, and supports `--dry-run` to review before energizing.
struct EnforceInstallCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "install",
    abstract: "Install Claude Code or OpenCode enforcement for a session (explicit, idempotent)."
  )

  @OptionGroup
  var scope: ScopeOptions

  @OptionGroup
  var session: SessionSelection

  @Option(name: .customLong("host"), help: "Host to install enforcement for: claude (default) or opencode.")
  var host: HookCheckHost = .claude

  @Option(
    name: .customLong("project-dir"),
    help: "Project directory that owns .claude/ (.opencode/ with --host opencode; defaults to CWD)."
  )
  var projectDir: String?

  @Option(
    name: .customLong("executable"),
    help: "The personakit binary the hook invokes, as a path or a name looked up on PATH now (Claude Code only)."
  )
  var executable: String?

  @Option(
    name: .customLong("mcp-server"),
    help: """
      MCP server name PersonaKit is configured under, if not "personakit". \
      Recorded in the frozen manifest so hook-check trusts its own tools there.
      """
  )
  var mcpServer: String?

  @Flag(name: .customLong("dry-run"), help: "Print the artifacts that would be written without writing them.")
  var dryRun = false

  mutating func validate() throws {
    switch host {
    case .claude:
      if let mcpServer, !ClaudeCodeEnforcement.isValidMCPServerName(mcpServer) {
        throw ArgumentParser.ValidationError(
          "--mcp-server must be non-empty, contain only letters, digits, '-' or '_', and not contain '__'. "
            + "Use the server name as it appears in Claude Code tool names (mcp__<name>__…)."
        )
      }
    case .opencode:
      if executable != nil {
        throw ArgumentParser.ValidationError(
          "--executable applies to --host claude only; the OpenCode plugin runs its personakitPath option "
            + "(personakit on PATH by default)."
        )
      }
      if let mcpServer, !Self.isValidOpenCodeServerName(mcpServer) {
        throw ArgumentParser.ValidationError(
          "--mcp-server must be non-empty and contain only letters, digits, '.', '_' or '-'. "
            + "Use the server name as it appears in the OpenCode config's mcp section."
        )
      }
    }

    guard let sessionId = session.sessionId else {
      throw ArgumentParser.ValidationError("enforce install requires --session <id>.")
    }

    // The session id becomes a file name under .opencode/, so it must be a plain workspace id.
    if host == .opencode, !WorkspaceEntityIDPolicy.isValid(sessionId) {
      throw ArgumentParser.ValidationError(
        "--session must match ^[A-Za-z0-9_-][A-Za-z0-9._-]*$ with --host opencode."
      )
    }
  }

  func run() throws {
    guard let sessionId = session.sessionId else {
      throw ArgumentParser.ValidationError("enforce install requires --session <id>.")
    }

    let scopes = try CLIHelpers.resolveScopes(options: scope)
    let manifest: ChecksManifest

    do {
      let sessionFile = try SessionFileLoader.load(scopes: scopes, sessionId: sessionId)
      let result = try SessionContractResolver.resolve(scopes: scopes, session: sessionFile)
      manifest = ChecksManifestDeriver.derive(from: result).withMCPServerName(mcpServer)
    } catch let error as ResolverResolutionError {
      var stderrStream = StandardError()
      for resolutionError in error.errors {
        stderrStream.write(CLIHelpers.formatResolutionError(resolutionError) + "\n")
      }
      throw ExitCode.failure
    } catch let error as RegistryLoadError {
      var stderrStream = StandardError()
      for registryError in error.errors {
        stderrStream.write(CLIHelpers.formatRegistryError(registryError) + "\n")
      }
      throw ExitCode.failure
    }

    let projectRoot = RootPathResolver().resolve(path: projectDir)

    if host == .opencode {
      try installOpenCode(manifest: manifest, sessionId: sessionId, projectRoot: projectRoot)
      return
    }

    let claudeDir = projectRoot.appendingPathComponent(".claude")
    let frozenManifestURL =
      claudeDir
      .appendingPathComponent("personakit")
      .appendingPathComponent("\(sessionId).checks.json")
    let settingsURL = claudeDir.appendingPathComponent("settings.json")
    let executablePath = try Self.resolveExecutablePath(override: executable)
    if !Self.isExecutableFile(executablePath) {
      var stderrStream = StandardError()
      stderrStream.write(
        "Warning: \(executablePath) is not an executable file, so the hook will block every tool call "
          + "until it is.\n"
      )
    }

    let artifacts = ClaudeCodeEnforcementRenderer.render(
      manifest: manifest,
      executablePath: executablePath,
      manifestPath: frozenManifestURL.path
    )

    guard let hookEntry = artifacts.hookEntry, let matcher = artifacts.matcher else {
      var stderrStream = StandardError()
      stderrStream.write(Self.nothingToInstall(sessionId: sessionId, persona: manifest.personaId, host: "Claude Code"))
      if ClaudeCodeSettingsMerger.containsPersonaKitEntry(in: try? Data(contentsOf: settingsURL)) {
        stderrStream.write(
          "A PersonaKit hook from an earlier install is still in force in \(settingsURL.path). "
            + "Run `\(uninstallCommand(projectRoot: projectRoot))` to remove it.\n"
        )
      }
      Self.reportDegradation(
        actionClasses: artifacts.degradedActionClasses,
        persona: manifest.personaId,
        host: "Claude Code"
      )
      return
    }

    // A cloned repo can commit any of these as a link, which would put the hook and manifest outside the
    // project (a link to ~/.claude makes the contract global) or copy the target's settings into it.
    try Self.refuseSymbolicLinks(
      [claudeDir, frozenManifestURL.deletingLastPathComponent(), settingsURL],
      action: "install"
    )

    let manifestDirectory = frozenManifestURL.deletingLastPathComponent()
    let otherManifests = try Self.otherManifestEntryNames(in: manifestDirectory, keeping: frozenManifestURL)
    let frozenManifestJSON = try Self.frozenManifestJSON(manifest)

    let existingSettings = try Self.existingSettings(at: settingsURL, action: "install")
    let replacedExisting = ClaudeCodeSettingsMerger.containsPersonaKitEntry(in: existingSettings)
    let mergedSettings = try ClaudeCodeSettingsMerger.merge(
      existingSettings: existingSettings,
      hookEntry: hookEntry
    )
    let mergedSettingsJSON = String(decoding: mergedSettings, as: UTF8.self)

    if dryRun {
      print("# Dry run — nothing written.")
      print("# Frozen manifest → \(frozenManifestURL.path)")
      print(TerminalText.escapingJSON(frozenManifestJSON))
      print("# Merged settings → \(settingsURL.path)")
      print(TerminalText.escapingJSON(mergedSettingsJSON))
      for name in otherManifests {
        print(TerminalText.sanitized("# Would remove → \(manifestDirectory.appendingPathComponent(name).path)"))
      }
    } else {
      let writer = AtomicFileWriter()
      try writer.write(contents: frozenManifestJSON + "\n", to: frozenManifestURL)
      try writer.write(contents: mergedSettingsJSON + "\n", to: settingsURL)
      // Only after settings.json names the new manifest, so the file never names a removed one. A running
      // Claude Code still runs the old hook until it reloads, and that hook blocks every call meanwhile.
      let removed = try Self.removeOtherManifests(otherManifests, in: manifestDirectory, keeping: frozenManifestURL)

      print("Installed Claude Code enforcement for session \(sessionId).")
      if replacedExisting {
        print("  (replaced a prior PersonaKit enforcement entry — one active contract per project)")
      }
      for name in removed {
        print(TerminalText.sanitized("  (removed prior manifest \(name))"))
      }
      print("  matcher: \(matcher)")
      print("  frozen manifest: \(frozenManifestURL.path)")
      print("  settings: \(settingsURL.path)")
      print(Self.claudeCodeReloadNote)
    }

    Self.reportDegradation(
      actionClasses: artifacts.degradedActionClasses,
      persona: manifest.personaId,
      host: "Claude Code"
    )
    Self.reportShellReachableCapabilities(manifest: manifest, host: "Claude Code")
  }

  /// The `enforce uninstall` command that reverses this install, with the host and project folder it was given.
  private func uninstallCommand(projectRoot: URL) -> String {
    var command = "personakit enforce uninstall"
    if host == .opencode {
      command += " --host opencode"
    }
    if projectDir != nil {
      let path = projectRoot.path
      let isBare = path.range(of: "^[A-Za-z0-9._/@+-]+$", options: .regularExpression) != nil
      command += " --project-dir " + (isBare ? path : "'" + path.replacingOccurrences(of: "'", with: #"'\''"#) + "'")
    }
    return command
  }

  /// OpenCode accepts any `[A-Za-z0-9._-]` server name; it sanitizes the rest itself.
  private static func isValidOpenCodeServerName(_ name: String) -> Bool {
    name.range(of: "^[A-Za-z0-9._-]+$", options: .regularExpression) != nil
  }

  /// The frozen manifest text both hosts write. The OpenCode server plugin hashes these exact bytes at startup.
  private static func frozenManifestJSON(_ manifest: ChecksManifest) throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    return String(decoding: try encoder.encode(manifest), as: UTF8.self)
  }

  /// Installs OpenCode enforcement: the frozen manifest and nothing else.
  ///
  /// Never writes OpenCode config. Other `*.checks.json` files in the manifest directory are removed so
  /// the folder it writes to keeps one manifest. Refuses, before writing anything, when the plugin
  /// `make opencode-install` installs is missing or is not this CLI's version, when `.opencode` or
  /// `.opencode/personakit` is a symbolic link or the manifest folder holds a `*.checks.json` entry that is
  /// not a regular file.
  private func installOpenCode(manifest: ChecksManifest, sessionId: String, projectRoot: URL) throws {
    try Self.checkInstalledOpenCodePlugin(environment: ProcessInfo.processInfo.environment)

    let manifestDirectory =
      projectRoot
      .appendingPathComponent(OpenCodeEnforcement.protectedDirectoryName)
      .appendingPathComponent("personakit")

    let deniedClasses = Self.deniedHookClasses(in: manifest)
    // The classes OpenCode can block: its mapped tools, plus the ones the unclassified-tool rule routes.
    let blockableClasses: Set<String> = ["command-execution", "file-mutation", "network-egress"]
    let degradedClasses = deniedClasses.subtracting(blockableClasses).sorted()

    guard !deniedClasses.isDisjoint(with: blockableClasses) else {
      var stderrStream = StandardError()
      stderrStream.write(Self.nothingToInstall(sessionId: sessionId, persona: manifest.personaId, host: "OpenCode"))
      let existing = Self.manifestEntryNames(in: manifestDirectory)
      if !existing.isEmpty {
        stderrStream.write(
          "A manifest from an earlier install is still in force in \(manifestDirectory.path): "
            + "\(existing.joined(separator: ", ")). Run `\(uninstallCommand(projectRoot: projectRoot))` to remove it.\n"
        )
      }
      Self.reportDegradation(actionClasses: degradedClasses, persona: manifest.personaId, host: "OpenCode")
      return
    }

    try Self.refuseSymbolicLinks([manifestDirectory.deletingLastPathComponent(), manifestDirectory], action: "install")

    let frozenManifestURL = manifestDirectory.appendingPathComponent("\(sessionId).checks.json")
    let otherManifests = try Self.otherManifestEntryNames(in: manifestDirectory, keeping: frozenManifestURL)
    let frozenManifestJSON = try Self.frozenManifestJSON(manifest)

    if dryRun {
      print("# Dry run — nothing written.")
      print("# Frozen manifest → \(frozenManifestURL.path)")
      print(TerminalText.escapingJSON(frozenManifestJSON))
      for name in otherManifests {
        print(TerminalText.sanitized("# Would remove → \(manifestDirectory.appendingPathComponent(name).path)"))
      }
    } else {
      try AtomicFileWriter().write(contents: frozenManifestJSON + "\n", to: frozenManifestURL)
      let removed = try Self.removeOtherManifests(otherManifests, in: manifestDirectory, keeping: frozenManifestURL)

      print("Installed OpenCode enforcement for session \(sessionId).")
      for name in removed {
        print(TerminalText.sanitized("  (removed prior manifest \(name))"))
      }
      print("  frozen manifest: \(frozenManifestURL.path)")
      print("Restart OpenCode so the plugin loads this contract.")
    }

    Self.reportDegradation(actionClasses: degradedClasses, persona: manifest.personaId, host: "OpenCode")
    Self.reportShellReachableCapabilities(manifest: manifest, host: "OpenCode")

    if !Self.openCodeConfigListsPlugin(environment: ProcessInfo.processInfo.environment) {
      var stderrStream = StandardError()
      stderrStream.write(
        "Note: the machine-wide OpenCode config does not list the PersonaKit plugin, so this contract is not "
          + "enforced yet. Run `make opencode-install` from a PersonaKit checkout of tag v\(PersonaKitVersion.current); "
          + "`personakit` itself never edits OpenCode config.\n"
      )
    }
  }

  /// The `*.checks.json` entries in `directory` other than `manifestURL`, the ones install removes. Fails when any
  /// entry is not a regular file.
  private static func otherManifestEntryNames(in directory: URL, keeping manifestURL: URL) throws -> [String] {
    let entries = try regularManifestEntryNames(in: directory, action: "install")

    // An entry that is the same directory entry as the new manifest (a case variant on a case-insensitive
    // volume) is decided by identity, not by comparing names: the volume knows what folds together.
    let existingNewIdentity = fileIdentity(manifestURL.path)
    return entries.filter { name in
      name != manifestURL.lastPathComponent
        && (existingNewIdentity == nil
          || fileIdentity(directory.appendingPathComponent(name).path) != existingNewIdentity)
    }
  }

  /// Removes `names` from `directory`, never the file that is the new manifest, then confirms that exactly
  /// that manifest is left and that it is spelled `<id>.checks.json` on disk. Returns the names removed.
  private static func removeOtherManifests(
    _ names: [String],
    in directory: URL,
    keeping manifestURL: URL
  ) throws -> [String] {
    var removed: [String] = []
    let keptIdentity = fileIdentity(manifestURL.path)

    for name in names {
      let path = directory.appendingPathComponent(name).path
      guard let identity = fileIdentity(path) else {
        continue
      }
      // The write can replace a pre-listed entry (case-folding volumes); never unlink the new manifest.
      guard identity != keptIdentity, isRegularFile(path) else {
        continue
      }
      try FileManager.default.removeItem(atPath: path)
      removed.append(name)
    }

    let remaining = manifestEntryNames(in: directory)
    guard remaining.count == 1, fileIdentity(directory.appendingPathComponent(remaining[0]).path) == keptIdentity
    else {
      throw CLIError.failure(
        "Install did not leave exactly one manifest in \(directory.path) "
          + "(found: \(remaining.joined(separator: ", "))). Check the folder, then run install again."
      )
    }

    // A write that replaced a case variant keeps that entry's spelling; rename it to the session id's.
    // A case-only rename works on APFS, and rename(2) does not refuse the "existing" destination.
    let intendedName = manifestURL.lastPathComponent
    if remaining[0] != intendedName {
      let current = directory.appendingPathComponent(remaining[0]).path
      guard rename(current, directory.appendingPathComponent(intendedName).path) == 0,
        manifestEntryNames(in: directory) == [intendedName]
      else {
        throw CLIError.failure(
          "Install could not rename \(current) to \(intendedName). Check the folder, then run install again."
        )
      }
    }
    return removed
  }

  /// Fails, naming the first one, when any of `urls` is a symbolic link. `action` names the refused command.
  static func refuseSymbolicLinks(_ urls: [URL], action: String) throws {
    for url in urls where isSymbolicLink(url.path) {
      throw CLIError.failure(
        "Refusing to \(action): \(url.path) is a symbolic link. "
          + "Replace it with a real file or directory so enforcement files stay inside the project."
      )
    }
  }

  /// The project's settings, or nil when there are none. Any other read failure stops the install: merging into
  /// nothing would replace every other setting with only the PersonaKit hook. `action` names the refused command.
  static func existingSettings(at url: URL, action: String) throws -> Data? {
    do {
      return try Data(contentsOf: url)
    } catch CocoaError.fileReadNoSuchFile {
      return nil
    } catch {
      throw CLIError.failure(
        "Refusing to \(action): could not read \(url.path): \(error.localizedDescription) "
          + "Make it a readable file, then run \(action) again."
      )
    }
  }

  /// Names of the entries directly in `directory` that end in `.checks.json`, sorted. Does not recurse.
  static func manifestEntryNames(in directory: URL) -> [String] {
    ((try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? [])
      .filter { $0.hasSuffix(".checks.json") }
      .sorted()
  }

  /// ``manifestEntryNames(in:)``, failing when any of them is not a regular file. `action` names the refused
  /// command.
  static func regularManifestEntryNames(in directory: URL, action: String) throws -> [String] {
    let entries = manifestEntryNames(in: directory)
    let irregular = entries.filter { !isRegularFile(directory.appendingPathComponent($0).path) }
    guard irregular.isEmpty else {
      throw CLIError.failure(
        "Refusing to \(action): \(directory.path) holds entries that are not regular files: "
          + "\(irregular.joined(separator: ", ")). Remove or rename them, then run \(action) again."
      )
    }
    return entries
  }

  private static func fileType(_ path: String) -> FileAttributeType? {
    // attributesOfItem uses lstat, so a symbolic link reports as one rather than as its target.
    (try? FileManager.default.attributesOfItem(atPath: path))?[.type] as? FileAttributeType
  }

  static func isRegularFile(_ path: String) -> Bool {
    fileType(path) == .typeRegular
  }

  private static func isSymbolicLink(_ path: String) -> Bool {
    fileType(path) == .typeSymbolicLink
  }

  /// Device and inode of the entry itself (not a link target), or nil when it does not exist.
  private static func fileIdentity(_ path: String) -> [UInt64]? {
    var info = stat()
    guard lstat(path, &info) == 0 else {
      return nil
    }
    return [UInt64(info.st_dev), UInt64(info.st_ino)]
  }

  /// Refuses unless the plugin `make opencode-install` installs is present and is this CLI's version.
  ///
  /// Reads `version` from `package.json` in ``OpenCodeEnforcement/installedPluginDirectory(environment:)``.
  /// `environment` is the caller's; without `HOME`, `passwdHome` supplies the home.
  static func checkInstalledOpenCodePlugin(
    environment: [String: String],
    passwdHome: () -> String? = HookCheckCommand.passwdHomeDirectory
  ) throws {
    let cliVersion = PersonaKitVersion.current
    let remedy = "Run `make opencode-install` from a PersonaKit checkout of tag v\(cliVersion), then run install again."
    let environment = HookCheckCommand.withAccountHome(environment, passwdHome: passwdHome)
    guard let directory = OpenCodeEnforcement.installedPluginDirectory(environment: environment) else {
      throw CLIError.failure(
        "Refusing to install: cannot locate the OpenCode plugin because neither XDG_CACHE_HOME nor HOME is set. "
          + remedy
      )
    }

    let packageURL = URL(fileURLWithPath: directory).appendingPathComponent("package.json")
    let data: Data
    do {
      data = try Data(contentsOf: packageURL)
    } catch CocoaError.fileReadNoSuchFile {
      throw CLIError.failure("Refusing to install: the OpenCode plugin is not installed at \(directory). " + remedy)
    } catch {
      throw CLIError.failure(
        "Refusing to install: could not read \(packageURL.path): \(error.localizedDescription) " + remedy
      )
    }

    guard let package = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let version = package["version"] as? String
    else {
      throw CLIError.failure("Refusing to install: \(packageURL.path) has no readable \"version\". " + remedy)
    }
    guard version.utf8.elementsEqual(cliVersion.utf8) else {
      throw CLIError.failure(
        "Refusing to install: the OpenCode plugin at \(directory) does not match this CLI "
          + "(plugin \(version), CLI \(cliVersion)). " + remedy
      )
    }
  }

  /// Whether the machine-wide OpenCode config lists the plugin `make opencode-install` installs.
  ///
  /// Reads `config.json`, `opencode.json` and `opencode.jsonc` in `$XDG_CONFIG_HOME/opencode` (`~/.config/opencode`
  /// without it), the files OpenCode merges there and `opencode plugin -g` writes to, and parses each as JSONC. Only an entry that is exactly
  /// ``OpenCodeEnforcement/installedPluginSpec(environment:)``, compared by bytes, as a string or the first element of
  /// a `[spec, options]` pair, counts. A project config, `$OPENCODE_CONFIG`, `$OPENCODE_CONFIG_DIR` and
  /// `~/.opencode` do not count, and a file that cannot be read or parsed lists nothing. Never writes a file.
  /// `environment` is the caller's; without `HOME`, `passwdHome` supplies the home.
  static func openCodeConfigListsPlugin(
    environment: [String: String],
    passwdHome: () -> String? = HookCheckCommand.passwdHomeDirectory
  ) -> Bool {
    let environment = HookCheckCommand.withAccountHome(environment, passwdHome: passwdHome)
    func value(_ key: String) -> String? {
      environment[key].flatMap { $0.isEmpty ? nil : $0 }
    }

    guard let spec = OpenCodeEnforcement.installedPluginSpec(environment: environment) else {
      return false
    }
    let configDirectory: URL
    if let configHome = value("XDG_CONFIG_HOME") {
      configDirectory = URL(fileURLWithPath: configHome).appendingPathComponent("opencode")
    } else if let home = value("HOME") {
      configDirectory = URL(fileURLWithPath: home).appendingPathComponent(".config/opencode")
    } else {
      return false
    }

    return ["config.json", "opencode.json", "opencode.jsonc"].contains { name in
      guard let data = try? Data(contentsOf: configDirectory.appendingPathComponent(name)),
        let config = try? JSONSerialization.jsonObject(with: data, options: [.json5Allowed]) as? [String: Any],
        let plugins = config["plugin"] as? [Any]
      else {
        return false
      }
      return plugins.contains { entry in
        guard let listed = ((entry as? [Any])?.first ?? entry) as? String else {
          return false
        }
        return listed.utf8.elementsEqual(spec.utf8)
      }
    }
  }

  /// What Claude Code does with a hook written into a running project, printed after install and uninstall.
  /// Claude Code watches its settings files and applies hook changes to running sessions.
  static let claudeCodeReloadNote =
    "Claude Code applies the change within a few seconds, running sessions included; restart it if it does not."

  /// The capabilities enforcement blocks on both hosts, as an operator writes them in `forbiddenCapabilities`.
  private static let blockableCapabilities = [
    SkillCapability.editFiles, SkillCapability.runCommands, SkillCapability.networkAccess,
  ].map(\.rawValue)

  /// The capability each action class comes from, so notes name what the operator wrote.
  private static let capabilityByActionClass = [
    "file-mutation": SkillCapability.editFiles.rawValue,
    "command-execution": SkillCapability.runCommands.rawValue,
    "network-egress": SkillCapability.networkAccess.rawValue,
    "inspection": SkillCapability.readOnlyInspection.rawValue,
    "unattended-iteration": SkillCapability.autonomousLoop.rawValue,
  ]

  /// The line install prints when the contract forbids none of ``blockableCapabilities``, so there is nothing to write.
  private static func nothingToInstall(sessionId: String, persona: String, host: String) -> String {
    "Nothing to install for session \(sessionId): persona \(persona) forbids none of "
      + "\(blockableCapabilities.joined(separator: ", ")), the capabilities \(host) enforcement blocks.\n"
  }

  /// Surfaces forbidden capabilities that no tool on the host maps to, so enforcement cannot block them.
  private static func reportDegradation(actionClasses: [String], persona: String, host: String) {
    guard !actionClasses.isEmpty else {
      return
    }

    let capabilities = actionClasses.map { capabilityByActionClass[$0] ?? $0 }
    let them = capabilities.count == 1 ? "it" : "them"
    var stderrStream = StandardError()
    stderrStream.write(
      "Note: persona \(persona) forbids \(capabilities.joined(separator: ", ")), but no \(host) tool maps to \(them), "
        + "so enforcement cannot block \(them); the agent must still follow the contract.\n"
    )
  }

  /// The action classes the manifest's hook checks deny.
  private static func deniedHookClasses(in manifest: ChecksManifest) -> Set<String> {
    Set(
      manifest.checks
        .filter { $0.maxClass == CheckClass.hook.rawValue }
        .flatMap { $0.rule.deniedActionClasses ?? [] }
    )
  }

  /// Forbidden capabilities a shell command can still exercise because the contract does not forbid
  /// `run-commands`, sorted.
  ///
  /// The hook blocks tools by what they are for, so with commands allowed, `Bash` or `bash` can still edit
  /// files and reach the network. Those denials hold only against the dedicated tools. Named as capabilities,
  /// since that is what an operator writes in `forbiddenCapabilities`.
  static func shellReachableCapabilities(in manifest: ChecksManifest) -> [String] {
    let denied = deniedHookClasses(in: manifest)
    guard !denied.contains("command-execution") else {
      return []
    }
    let capabilityByClass = [
      "file-mutation": SkillCapability.editFiles.rawValue,
      "network-egress": SkillCapability.networkAccess.rawValue,
    ]
    return denied.compactMap { capabilityByClass[$0] }.sorted()
  }

  /// Warns when the contract forbids something a shell command can still do, so the install never reads as
  /// enforcing more than it does.
  private static func reportShellReachableCapabilities(manifest: ChecksManifest, host: String) {
    let capabilities = shellReachableCapabilities(in: manifest)
    guard !capabilities.isEmpty else {
      return
    }

    let runCommands = SkillCapability.runCommands.rawValue
    var stderrStream = StandardError()
    stderrStream.write(
      "Note: persona \(manifest.personaId) does not forbid \(runCommands), so \(host) blocks only the dedicated "
        + "tools for \(capabilities.joined(separator: ", ")); a shell command can still do them. "
        + "Forbid \(runCommands) too to enforce them.\n"
    )
  }

  /// Resolves the personakit binary to bake into the hook command, always as an absolute path.
  ///
  /// A bare name is looked up on `PATH` now, as the shell just did, not when the hook fires: Claude Code may
  /// run hooks with another `PATH`, where the name could find a different binary or none, and a missing
  /// binary is a failed check. The `PATH` entry is kept as spelled, so a symlink that package upgrades
  /// repoint keeps working. Without an override, the name this process was started by is used, falling back
  /// to this binary's own path when that name is not on `PATH`.
  static func resolveExecutablePath(
    override: String?,
    invokedAs: String? = CommandLine.arguments.first,
    environment: [String: String] = ProcessInfo.processInfo.environment,
    ownExecutable: String? = Bundle.main.executableURL?.path
  ) throws -> String {
    if let override, !override.isEmpty {
      if override.contains("/") {
        return RootPathResolver().resolve(path: override).path
      }
      guard let found = lookUpOnPath(override, environment: environment) else {
        throw ArgumentParser.ValidationError(
          "--executable \(override) is not an executable on PATH; pass the absolute path of the personakit binary."
        )
      }
      return found
    }

    if let invokedAs, !invokedAs.isEmpty {
      if invokedAs.contains("/") {
        return RootPathResolver().resolve(path: invokedAs).path
      }
      if let found = lookUpOnPath(invokedAs, environment: environment) {
        return found
      }
    }

    guard let ownExecutable, !ownExecutable.isEmpty else {
      throw ArgumentParser.ValidationError(
        "Could not find the personakit binary; pass its absolute path with --executable."
      )
    }
    return ownExecutable
  }

  /// The first executable file named `name` in an absolute `PATH` entry. Relative and empty entries are
  /// skipped, since they depend on the directory the hook happens to run in.
  private static func lookUpOnPath(_ name: String, environment: [String: String]) -> String? {
    let directories = (environment["PATH"] ?? "").split(separator: ":").map(String.init)
    for directory in directories where directory.hasPrefix("/") {
      let candidate = URL(fileURLWithPath: directory).appendingPathComponent(name).standardized.path
      if isExecutableFile(candidate) {
        return candidate
      }
    }
    return nil
  }

  /// Whether `path` is an executable file. A searchable directory passes `isExecutableFile(atPath:)` alone.
  private static func isExecutableFile(_ path: String) -> Bool {
    var isDirectory: ObjCBool = false
    return FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) && !isDirectory.boolValue
      && FileManager.default.isExecutableFile(atPath: path)
  }
}
