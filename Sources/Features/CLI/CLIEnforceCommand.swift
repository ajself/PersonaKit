import ArgumentParser
import ContextCore
import CryptoKit
import Foundation

/// Claude Code `PreToolUse` payload — only the fields the checker needs.
private struct PreToolUsePayload: Decodable {
  let toolName: String?

  enum CodingKeys: String, CodingKey {
    case toolName = "tool_name"
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

/// Host whose tool-call payload `hook-check` reads.
enum HookCheckHost: String, CaseIterable, ExpressibleByArgument {
  case claude
  case opencode
}

/// Runtime checker invoked by a Claude Code `PreToolUse` hook, or by the OpenCode server plugin.
///
/// Reads the tool call from stdin, consults a frozen checks manifest, and denies the call
/// when the tool performs a forbidden action class. Read-only toward the agent: it can only
/// deny, never authorize. Fail-closed — because the installed matcher only routes already
/// forbidden tools here, denying on any internal error is safe by construction.
struct HookCheckCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "hook-check",
    abstract: "Evaluate a Claude Code or OpenCode tool call against a frozen checks manifest.",
    discussion: """
      Not run by hand. For Claude Code (--host claude, the default), `personakit enforce \
      install` wires this into a project's .claude/settings.json as a PreToolUse hook. For \
      OpenCode (--host opencode), the opencode-personakit server plugin runs it with \
      --expect-sha256. Either way it reads the tool call on stdin and emits a deny decision \
      when the session's contract forbids the tool.
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

    let decision = Self.decide(manifestPath: manifestPath)

    guard decision.isDenied else {
      // Allow: exit 0 with no output lets Claude Code's normal permission flow proceed.
      return
    }

    let output = HookDecisionOutput(
      hookSpecificOutput: HookDecisionOutput.Inner(
        permissionDecision: "deny",
        permissionDecisionReason: decision.reason ?? "Denied by PersonaKit contract."
      )
    )

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]

    if let data = try? encoder.encode(output), let json = String(data: data, encoding: .utf8) {
      print(json)
    }
    // Deny is communicated by the JSON above with exit 0; do not fail the process.
  }

  private func runOpenCode() throws {
    let decision = Self.decideOpenCode(manifestPath: manifestPath, expectedSHA256: expectSHA256 ?? "")

    guard decision.isDenied else {
      return
    }

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let output = OpenCodeDecisionOutput(reason: decision.reason ?? "Denied by PersonaKit contract.")

    if let data = try? encoder.encode(output), let json = String(data: data, encoding: .utf8) {
      print(json)
    } else {
      // An encode failure must not read as an allow (no output).
      print(
        #"{"decision":"deny","reason":"PersonaKit enforcement could not encode its decision; "#
          + #"denying by fail-closed policy."}"#
      )
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
    func failClosed(_ message: String) -> ClaudeCodeHookCheckDecision {
      ClaudeCodeHookCheckDecision(isDenied: true, reason: "\(message); denying by fail-closed policy.")
    }

    let manifestURL = RootPathResolver().resolve(path: manifestPath)

    guard let data = try? Data(contentsOf: manifestURL) else {
      return failClosed(
        "PersonaKit enforcement manifest at \(manifestURL.path) is missing or changed since OpenCode started "
          + "(it could not be read); restart OpenCode to load the current contract"
      )
    }

    let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    guard digest == expectedSHA256.lowercased() else {
      return failClosed(
        "PersonaKit enforcement manifest at \(manifestURL.path) changed since OpenCode started "
          + "(its SHA-256 no longer matches); restart OpenCode to load the current contract"
      )
    }

    guard let manifest = try? JSONDecoder().decode(ChecksManifest.self, from: data) else {
      return failClosed("PersonaKit enforcement could not decode its manifest at \(manifestURL.path)")
    }

    let stdin: String
    do {
      stdin = try CLIEnvironment.current.interactiveIO.readStdinToEnd()
    } catch {
      return failClosed("PersonaKit enforcement could not read the tool call")
    }

    guard let call = try? JSONDecoder().decode(OpenCodeToolCall.self, from: Data(stdin.utf8)) else {
      return failClosed("PersonaKit enforcement could not parse the tool call")
    }

    var effectiveEnvironment = environment
    if environment["HOME"]?.isEmpty != false, let home = passwdHome(), !home.isEmpty {
      effectiveEnvironment["HOME"] = home
    }

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

  /// Pure decision: read manifest + stdin, evaluate, fail-closed on any error.
  static func decide(manifestPath: String) -> ClaudeCodeHookCheckDecision {
    let manifestURL = RootPathResolver().resolve(path: manifestPath)

    guard let data = try? Data(contentsOf: manifestURL),
      let manifest = try? JSONDecoder().decode(ChecksManifest.self, from: data)
    else {
      return ClaudeCodeHookCheckDecision(
        isDenied: true,
        reason: "PersonaKit enforcement could not read its manifest at \(manifestURL.path); denying by fail-closed policy."
      )
    }

    let stdin: String
    do {
      stdin = try CLIEnvironment.current.interactiveIO.readStdinToEnd()
    } catch {
      return ClaudeCodeHookCheckDecision(
        isDenied: true,
        reason: "PersonaKit enforcement could not read the tool call; denying by fail-closed policy."
      )
    }

    guard let payload = try? JSONDecoder().decode(PreToolUsePayload.self, from: Data(stdin.utf8)),
      let toolName = payload.toolName
    else {
      return ClaudeCodeHookCheckDecision(
        isDenied: true,
        reason: "PersonaKit enforcement could not parse the tool call; denying by fail-closed policy."
      )
    }

    return ClaudeCodeHookCheckEvaluator.evaluate(toolName: toolName, manifest: manifest)
  }
}

/// Parent command grouping enforcement export/install subcommands.
struct EnforceCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "enforce",
    abstract: "Project a session contract into host enforcement.",
    subcommands: [EnforceInstallCommand.self]
  )
}

/// Installs Claude Code enforcement for a session — the explicit, one-time, reviewed step.
///
/// Writes a frozen manifest and merges a `PreToolUse` hook into `.claude/settings.json`.
/// PersonaKit never writes host config on its own; this runs only when invoked, prints
/// exactly what it changes, and supports `--dry-run` to review before energizing.
struct EnforceInstallCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "install",
    abstract: "Install Claude Code PreToolUse enforcement for a session (explicit, idempotent)."
  )

  @OptionGroup
  var scope: ScopeOptions

  @OptionGroup
  var session: SessionSelection

  @Option(name: .customLong("project-dir"), help: "Project directory that owns .claude/ (defaults to CWD).")
  var projectDir: String?

  @Option(name: .customLong("executable"), help: "Path to the personakit binary the hook invokes.")
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
    if let mcpServer, !ClaudeCodeEnforcement.isValidMCPServerName(mcpServer) {
      throw ArgumentParser.ValidationError(
        "--mcp-server must be non-empty, contain only letters, digits, '-' or '_', and not contain '__'. "
          + "Use the server name as it appears in Claude Code tool names (mcp__<name>__…)."
      )
    }

    guard session.sessionId != nil else {
      throw ArgumentParser.ValidationError("enforce install requires --session <id>.")
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
    let claudeDir = projectRoot.appendingPathComponent(".claude")
    let frozenManifestURL =
      claudeDir
      .appendingPathComponent("personakit")
      .appendingPathComponent("\(sessionId).checks.json")
    let settingsURL = claudeDir.appendingPathComponent("settings.json")
    let executablePath = Self.resolveExecutablePath(override: executable)

    let artifacts = ClaudeCodeEnforcementRenderer.render(
      manifest: manifest,
      executablePath: executablePath,
      manifestPath: frozenManifestURL.path
    )

    guard let hookEntry = artifacts.hookEntry, let matcher = artifacts.matcher else {
      var stderrStream = StandardError()
      stderrStream.write(
        "No class-1 hook checks to install for session \(sessionId): "
          + "nothing Claude Code can deny at the hook layer.\n"
      )
      Self.reportDegradation(actionClasses: artifacts.degradedActionClasses, persona: manifest.personaId)
      return
    }

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let frozenManifestJSON = String(decoding: try encoder.encode(manifest), as: UTF8.self)

    let existingSettings = try? Data(contentsOf: settingsURL)
    let replacedExisting = ClaudeCodeSettingsMerger.containsPersonaKitEntry(in: existingSettings)
    let mergedSettings = try ClaudeCodeSettingsMerger.merge(
      existingSettings: existingSettings,
      hookEntry: hookEntry
    )
    let mergedSettingsJSON = String(decoding: mergedSettings, as: UTF8.self)

    if dryRun {
      print("# Dry run — nothing written.")
      print("# Frozen manifest → \(frozenManifestURL.path)")
      print(frozenManifestJSON)
      print("# Merged settings → \(settingsURL.path)")
      print(mergedSettingsJSON)
    } else {
      let writer = AtomicFileWriter()
      try writer.write(contents: frozenManifestJSON + "\n", to: frozenManifestURL)
      try writer.write(contents: mergedSettingsJSON + "\n", to: settingsURL)

      print("Installed Claude Code enforcement for session \(sessionId).")
      if replacedExisting {
        print("  (replaced a prior PersonaKit enforcement entry — one active contract per project)")
      }
      print("  matcher: \(matcher)")
      print("  frozen manifest: \(frozenManifestURL.path)")
      print("  settings: \(settingsURL.path)")
    }

    Self.reportDegradation(actionClasses: artifacts.degradedActionClasses, persona: manifest.personaId)
  }

  /// Surfaces forbidden capabilities that cannot reach the hook layer on Claude Code.
  private static func reportDegradation(actionClasses: [String], persona: String) {
    guard !actionClasses.isEmpty else {
      return
    }

    var stderrStream = StandardError()
    stderrStream.write(
      "Note: persona \(persona) forbids capabilities Claude Code cannot deny at the hook layer; "
        + "they degrade to review — \(actionClasses.joined(separator: ", ")).\n"
    )
  }

  /// Resolves the personakit binary reference to bake into the hook command.
  private static func resolveExecutablePath(override: String?) -> String {
    if let override, !override.isEmpty {
      return normalizedExecutable(override)
    }

    return normalizedExecutable(CommandLine.arguments.first ?? "personakit")
  }

  /// Resolves a path-like value to an absolute path, but leaves a bare command name (no path
  /// separator) untouched so the shell resolves it via PATH when the hook fires.
  ///
  /// Prepending the current directory to a bare name (as a plain path resolve would) bakes a
  /// nonexistent `<cwd>/personakit` into the hook, silently breaking enforcement at run time.
  private static func normalizedExecutable(_ value: String) -> String {
    guard value.contains("/") else {
      return value
    }

    return RootPathResolver().resolve(path: value).path
  }
}
