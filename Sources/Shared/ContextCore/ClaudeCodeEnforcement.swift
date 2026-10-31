import Foundation

/// Host-specific projection of a host-neutral ``ChecksManifest`` into Claude Code
/// enforcement. The manifest and its `deniedActionClasses` stay host-neutral; everything
/// that knows Claude Code tool names or `settings.json` shape lives here, behind a clear
/// seam, so other hosts get their own renderer without touching the core.
///
/// The only executable surface this introduces is a declarative `PreToolUse` hook that
/// invokes the already-reviewed `personakit hook-check` subcommand — never a generated
/// per-project script.
public enum ClaudeCodeEnforcement {
  /// Subcommand the installed hook invokes.
  public static let hookCheckSubcommand = "hook-check"

  /// Substring that identifies a PersonaKit-owned hook entry across re-installs.
  ///
  /// Deliberately more specific than the bare subcommand: matching only `hook-check` would
  /// also strip an unrelated user hook whose command merely contains that text. Our command
  /// always contains `hook-check --manifest`, which a foreign hook realistically will not.
  public static let ownershipMarker = "hook-check --manifest"

  /// Single source of truth mapping host-neutral action classes to Claude Code tools.
  ///
  /// Used in both directions: the renderer turns denied action classes into a tool-name
  /// matcher; the checker turns an incoming tool name back into its action class. Ordered
  /// so generated matchers are deterministic.
  static let toolActionClasses: [(actionClass: String, tools: [String])] = [
    ("file-mutation", ["Edit", "Write", "NotebookEdit"]),
    ("command-execution", ["Bash"]),
    ("network-egress", ["WebFetch", "WebSearch"]),
  ]

  /// Canonical tool ordering for deterministic matcher rendering.
  static let toolOrder: [String] = toolActionClasses.flatMap(\.tools)

  /// Matcher pattern that routes external MCP tools to the checker.
  ///
  /// MCP tools are third-party and unclassifiable, so the fixed built-in matcher alone would
  /// let an un-enumerated `mcp__…__write`/`exec`/network tool slip past a read-only contract.
  /// When a mutation- or network-forbidding stance is in force, MCP tools are matched and
  /// denied fail-closed instead.
  static let mcpToolPattern = "mcp__.*"

  /// Action classes an unclassifiable MCP tool could plausibly perform. If any is forbidden,
  /// MCP tools are routed to the checker and denied, since PK cannot prove they are safe.
  static let mcpRelevantActionClasses: Set<String> = ["file-mutation", "command-execution", "network-egress"]

  /// Returns the action class a Claude Code tool belongs to, if any is mapped.
  static func actionClass(forTool tool: String) -> String? {
    toolActionClasses.first { $0.tools.contains(tool) }?.actionClass
  }

  /// Whether a tool edits files, so its path is checked against the enforcement files.
  static func isFileMutationTool(_ tool: String) -> Bool {
    actionClass(forTool: tool) == "file-mutation"
  }

  /// Whether a tool name is an external MCP tool (which PK cannot classify).
  static func isMCPTool(_ name: String) -> Bool {
    name.hasPrefix("mcp__")
  }

  /// The files an edit could disable enforcement through, sorted: the manifest's folder, the project
  /// settings beside it that install the hook, the user settings (which can set `disableAllHooks`), and the
  /// checker binary. An entry ending in `/` protects that directory and everything under it.
  ///
  /// `manifestPath` is absolute, laid out as `<project>/.claude/personakit/<id>.checks.json`.
  /// `configDirectory` is Claude Code's user config directory (`$CLAUDE_CONFIG_DIR`, else `~/.claude`).
  public static func protectedPaths(
    manifestPath: String,
    configDirectory: String?,
    executablePath: String?
  ) -> [String] {
    let manifestDirectory = (manifestPath as NSString).deletingLastPathComponent
    let settingsDirectory = (manifestDirectory as NSString).deletingLastPathComponent
    var entries = [
      manifestDirectory + "/",
      settingsDirectory + "/settings.json",
      settingsDirectory + "/settings.local.json",
    ]
    if let configDirectory, !configDirectory.isEmpty {
      entries.append(configDirectory + "/settings.json")
    }
    if let executablePath, !executablePath.isEmpty {
      entries.append(executablePath)
    }
    return Array(Set(entries)).sorted()
  }

  /// `path` made absolute the way Claude Code reads a tool's path: trimmed, then `~` and `~/…` against the
  /// home directory, a relative path against the session's working directory. `nil` when neither applies.
  static func absolutePath(_ rawPath: String, cwd: String?, homeDirectory: String?) -> String? {
    let path = rawPath.trimmingCharacters(in: .whitespacesAndNewlines)
    if path.hasPrefix("/") {
      return path
    }
    if path == "~" || path.hasPrefix("~/") {
      guard let homeDirectory, homeDirectory.hasPrefix("/") else { return nil }
      return homeDirectory + path.dropFirst()
    }
    guard let cwd, cwd.hasPrefix("/") else { return nil }
    return cwd + "/" + path
  }

  /// Server name PersonaKit's own MCP server is registered under by default.
  public static let defaultMCPServerName = "personakit"

  /// Tool names PersonaKit's own MCP server exposes, sorted.
  ///
  /// Every one is read-only grounding. Kept as a literal because ContextCore cannot import
  /// ContextMCP; a parity test against `MCPToolName` guards drift.
  public static let personaKitMCPToolNames: [String] = [
    "personakit_best_guidance",
    "personakit_compare_entities",
    "personakit_explain_entity",
    "personakit_export",
    "personakit_graph",
    "personakit_recommend_session",
    "personakit_resolve_contract",
    "personakit_resolve_grounding_skills",
    "personakit_resolve_session_ref",
    "personakit_trace_session",
    "personakit_validate",
  ]

  /// Whether a tool call is one of PersonaKit's own read-only MCP tools on the trusted server.
  ///
  /// Matches the full `mcp__<serverName>__<tool>` name exactly, so a same-named tool from any
  /// other server, or a near-miss tool name on the trusted server, is not trusted.
  public static func isTrustedPersonaKitMCPTool(_ toolName: String, serverName: String) -> Bool {
    personaKitMCPToolNames.contains { toolName == "mcp__\(serverName)__\($0)" }
  }

  /// Whether a name can be a host MCP server segment: tool names are `mcp__<server>__<tool>`,
  /// and Claude Code normalizes server names to `[A-Za-z0-9_-]`, so `__` would be ambiguous.
  public static func isValidMCPServerName(_ name: String) -> Bool {
    !name.contains("__") && name.range(of: "^[A-Za-z0-9_-]+$", options: .regularExpression) != nil
  }

  /// The server segment of an MCP tool named like one of PersonaKit's own tools, if any.
  ///
  /// Used only to explain a denial; it never grants trust, since any server can expose a
  /// tool by that name.
  static func serverNameOfPersonaKitNamedMCPTool(_ toolName: String) -> String? {
    guard isMCPTool(toolName) else { return nil }
    for name in personaKitMCPToolNames where toolName.hasSuffix("__\(name)") {
      let server = String(toolName.dropFirst("mcp__".count).dropLast("__\(name)".count))
      return isValidMCPServerName(server) ? server : nil
    }
    return nil
  }
}

/// Deterministic command hook entry: `{ "type": "command", "command": "…" }`.
public struct ClaudeCodeHookCommand: Codable, Equatable, Sendable {
  public let type: String
  public let command: String

  public init(command: String) {
    self.type = "command"
    self.command = command
  }
}

/// A matcher-scoped group of hooks: `{ "matcher": "Edit|Write|…", "hooks": [ … ] }`.
public struct ClaudeCodeHookMatcher: Codable, Equatable, Sendable {
  public let matcher: String
  public let hooks: [ClaudeCodeHookCommand]

  public init(matcher: String, hooks: [ClaudeCodeHookCommand]) {
    self.matcher = matcher
    self.hooks = hooks
  }
}

/// The rendered artifacts for one session's Claude Code enforcement.
///
/// Always returned so degradation is reported even when there is nothing to install:
/// `hookEntry` is `nil` when the manifest denies nothing Claude Code can enforce at the hook
/// layer, while `degradedActionClasses` still names what was forbidden but unreachable.
public struct ClaudeCodeEnforcementArtifacts: Equatable, Sendable {
  /// The tool-name matcher (regex-alternation) scoping which tools invoke the checker, if any.
  public let matcher: String?

  /// The `PreToolUse` entry to merge into `settings.json`, or `nil` when nothing is installable.
  public let hookEntry: ClaudeCodeHookMatcher?

  /// Action classes the persona forbids that Claude Code cannot deny at the hook layer —
  /// reported so degradation is never silent.
  public let degradedActionClasses: [String]

  public init(
    matcher: String?,
    hookEntry: ClaudeCodeHookMatcher?,
    degradedActionClasses: [String]
  ) {
    self.matcher = matcher
    self.hookEntry = hookEntry
    self.degradedActionClasses = degradedActionClasses
  }

  /// Whether there is a hook entry to install.
  public var isInstallable: Bool {
    hookEntry != nil
  }
}

/// Renders a resolved manifest's class-1 hook checks into Claude Code enforcement artifacts.
public enum ClaudeCodeEnforcementRenderer {
  /// Builds the matcher + `PreToolUse` entry that invoke the checker against a frozen manifest.
  ///
  /// - Parameters:
  ///   - manifest: The derived checks manifest (host-neutral).
  ///   - executablePath: Absolute path to the `personakit` binary the hook invokes.
  ///   - manifestPath: Absolute path to the frozen manifest the checker reads.
  /// - Returns: The rendered artifacts. `hookEntry` is `nil` when the manifest denies nothing
  ///   Claude Code can enforce at the hook layer, but `degradedActionClasses` still reports
  ///   any forbidden capability that could not reach the hook.
  public static func render(
    manifest: ChecksManifest,
    executablePath: String,
    manifestPath: String
  ) -> ClaudeCodeEnforcementArtifacts {
    let deniedActionClasses = manifest.checks
      .filter { $0.maxClass == CheckClass.hook.rawValue }
      .compactMap { $0.rule.deniedActionClasses }
      .flatMap { $0 }

    let deniedSet = Set(deniedActionClasses)

    let deniedTools =
      ClaudeCodeEnforcement.toolOrder
      .filter { tool in
        guard let actionClass = ClaudeCodeEnforcement.actionClass(forTool: tool) else {
          return false
        }
        return deniedSet.contains(actionClass)
      }

    let mappedActionClasses = Set(
      ClaudeCodeEnforcement.toolActionClasses
        .filter { !$0.tools.isEmpty }
        .map(\.actionClass)
    )
    let degraded = deniedSet.subtracting(mappedActionClasses).sorted()

    // When the stance forbids something an MCP tool could do, also route MCP tools to the
    // checker so an unclassifiable third-party write/exec/network tool cannot bypass the deny.
    let deniesMcpRelevant = !deniedSet.isDisjoint(with: ClaudeCodeEnforcement.mcpRelevantActionClasses)

    guard !deniedTools.isEmpty || deniesMcpRelevant else {
      return ClaudeCodeEnforcementArtifacts(
        matcher: nil,
        hookEntry: nil,
        degradedActionClasses: degraded
      )
    }

    // The file tools are routed even when edits are allowed, so the checker can refuse edits to its own
    // manifest, the settings that install it, and its binary.
    var matcherPatterns = ClaudeCodeEnforcement.toolOrder.filter {
      deniedTools.contains($0) || ClaudeCodeEnforcement.isFileMutationTool($0)
    }
    if deniesMcpRelevant {
      matcherPatterns.append(ClaudeCodeEnforcement.mcpToolPattern)
    }

    let matcher = matcherPatterns.joined(separator: "|")
    let command =
      "\(shellQuote(executablePath)) \(ClaudeCodeEnforcement.hookCheckSubcommand) --manifest \(shellQuote(manifestPath))"

    return ClaudeCodeEnforcementArtifacts(
      matcher: matcher,
      hookEntry: ClaudeCodeHookMatcher(matcher: matcher, hooks: [ClaudeCodeHookCommand(command: command)]),
      degradedActionClasses: degraded
    )
  }

  /// POSIX single-quotes a value embedded in the shell-executed hook command.
  ///
  /// Always quotes — never conditionally. The command string is run through a shell by the
  /// host, so any value in it (including a manifest path whose session-id component is only
  /// screened for `/` and `\`) must be fully neutralized: single quotes make every other
  /// metacharacter (`;`, `$`, `` ` ``, `&`, `|`, newline, …) literal, and an embedded single
  /// quote is escaped as `'\''`.
  private static func shellQuote(_ value: String) -> String {
    "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
  }
}

/// Merges a PersonaKit `PreToolUse` entry into an existing (or empty) `settings.json`,
/// preserving all other content and staying idempotent across re-installs.
///
/// This is the one surface that writes into a host config directory, so it is a pure,
/// well-tested transform: file IO lives in the caller. Prior PersonaKit entries (identified
/// by ``ClaudeCodeEnforcement/ownershipMarker``) are removed before ours is appended, so a
/// re-install replaces rather than duplicates.
public enum ClaudeCodeSettingsMerger {
  public enum MergeError: Error, Equatable {
    case invalidExistingSettings
  }

  /// Returns the merged `settings.json` bytes with our hook entry installed.
  public static func merge(
    existingSettings: Data?,
    hookEntry: ClaudeCodeHookMatcher
  ) throws -> Data {
    var root: [String: Any] = [:]

    if let existingSettings, !existingSettings.isEmpty {
      guard let parsed = try? JSONSerialization.jsonObject(with: existingSettings),
        let dictionary = parsed as? [String: Any]
      else {
        throw MergeError.invalidExistingSettings
      }
      root = dictionary
    }

    var hooks = (root["hooks"] as? [String: Any]) ?? [:]
    var preToolUse = (hooks["PreToolUse"] as? [Any]) ?? []

    // Drop any prior PersonaKit-owned entries so re-install replaces, never duplicates.
    preToolUse = preToolUse.filter { !isPersonaKitEntry($0) }

    preToolUse.append([
      "matcher": hookEntry.matcher,
      "hooks": hookEntry.hooks.map { ["type": $0.type, "command": $0.command] },
    ])

    hooks["PreToolUse"] = preToolUse
    root["hooks"] = hooks

    return try JSONSerialization.data(
      withJSONObject: root,
      options: [.prettyPrinted, .sortedKeys]
    )
  }

  /// Whether the given `settings.json` bytes already contain a PersonaKit-owned hook entry,
  /// so the caller can report a replacement rather than a silent clobber.
  public static func containsPersonaKitEntry(in settings: Data?) -> Bool {
    guard let settings, !settings.isEmpty,
      let root = try? JSONSerialization.jsonObject(with: settings) as? [String: Any],
      let hooks = root["hooks"] as? [String: Any],
      let preToolUse = hooks["PreToolUse"] as? [Any]
    else {
      return false
    }

    return preToolUse.contains { isPersonaKitEntry($0) }
  }

  /// Whether a `PreToolUse` entry is one PersonaKit installed (by its command's ownership marker).
  private static func isPersonaKitEntry(_ entry: Any) -> Bool {
    guard let entry = entry as? [String: Any],
      let entryHooks = entry["hooks"] as? [Any]
    else {
      return false
    }

    return entryHooks.contains { hook in
      guard let hook = hook as? [String: Any],
        let command = hook["command"] as? String
      else {
        return false
      }
      return command.contains(ClaudeCodeEnforcement.ownershipMarker)
    }
  }
}

/// Decision returned by the Claude Code checker for a single tool call.
public struct ClaudeCodeHookCheckDecision: Equatable, Sendable {
  public let isDenied: Bool
  public let reason: String?

  public init(isDenied: Bool, reason: String?) {
    self.isDenied = isDenied
    self.reason = reason
  }
}

/// The fields of one Claude Code `PreToolUse` call the checker reads.
public struct ClaudeCodeToolCall: Equatable, Sendable {
  public let toolName: String
  /// `tool_input.file_path` and `tool_input.notebook_path`, whichever are strings, as sent.
  public let paths: [String]
  /// The session's working directory, which a relative path resolves against.
  public let cwd: String?

  public init(toolName: String, paths: [String], cwd: String?) {
    self.toolName = toolName
    self.paths = paths
    self.cwd = cwd
  }
}

/// Evaluates one incoming Claude Code tool call against a frozen manifest.
///
/// Host-specific only in the tool→action-class mapping; the deny decision itself lives in the
/// neutral core via ``ChecksManifest/hookCheck(denying:)``. Read-only toward the running
/// agent: it can only *deny*, never authorize.
public enum ClaudeCodeHookCheckEvaluator {
  /// Denies a file edit that targets one of `protectedPaths` (see
  /// ``ClaudeCodeEnforcement/protectedPaths(manifestPath:configDirectory:executablePath:)``), or that names
  /// no path it can resolve, before applying the contract to the tool.
  public static func evaluate(
    _ call: ClaudeCodeToolCall,
    manifest: ChecksManifest,
    protectedPaths: [String],
    homeDirectory: String?
  ) -> ClaudeCodeHookCheckDecision {
    if ClaudeCodeEnforcement.isFileMutationTool(call.toolName) {
      let absolutePaths = call.paths.map {
        ClaudeCodeEnforcement.absolutePath($0, cwd: call.cwd, homeDirectory: homeDirectory)
      }
      guard !absolutePaths.isEmpty, !call.paths.contains(""), !absolutePaths.contains(nil) else {
        return ClaudeCodeHookCheckDecision(
          isDenied: true,
          reason: "Blocked by PersonaKit contract: tool '\(call.toolName)' modifies files but names no path "
            + "PersonaKit can resolve, so it cannot check it against its enforcement files. "
            + "Denying by fail-closed policy."
        )
      }
      if let protected = absolutePaths.compactMap({ $0 }).first(where: {
        OpenCodeEnforcement.matchesProtectedEntry($0, entries: protectedPaths)
      }) {
        return ClaudeCodeHookCheckDecision(
          isDenied: true,
          reason: "Blocked by PersonaKit contract: tool '\(call.toolName)' would modify "
            + "'\(OpenCodeEnforcement.strippingControlCharacters(protected))', one of the PersonaKit enforcement "
            + "files (the manifest folder, `.claude/settings.json`, `.claude/settings.local.json`, the user "
            + "Claude Code settings, the personakit binary). Changing them could disable or bypass enforcement."
        )
      }
    }

    return evaluate(toolName: call.toolName, manifest: manifest)
  }

  /// Applies the contract to the tool by name alone, without the path check.
  public static func evaluate(toolName: String, manifest: ChecksManifest) -> ClaudeCodeHookCheckDecision {
    guard let actionClass = ClaudeCodeEnforcement.actionClass(forTool: toolName) else {
      // Not a known built-in tool. PersonaKit's own read-only MCP tools from the trusted server
      // are allowed; any other MCP tool is unclassifiable, so if the contract forbids anything
      // an MCP tool could do, fail closed rather than let it through.
      if ClaudeCodeEnforcement.isTrustedPersonaKitMCPTool(
        toolName,
        serverName: manifest.mcpServerName ?? ClaudeCodeEnforcement.defaultMCPServerName
      ) {
        return ClaudeCodeHookCheckDecision(isDenied: false, reason: nil)
      }
      if ClaudeCodeEnforcement.isMCPTool(toolName) {
        return evaluateUnclassifiedMCPTool(toolName: toolName, manifest: manifest)
      }
      return ClaudeCodeHookCheckDecision(isDenied: false, reason: nil)
    }

    guard let denyingCheck = manifest.hookCheck(denying: actionClass) else {
      return ClaudeCodeHookCheckDecision(isDenied: false, reason: nil)
    }

    let reason =
      "Blocked by PersonaKit contract: \(denyingCheck.id) — \(denyingCheck.mandate) "
      + "(from \(denyingCheck.source.sourceType) '\(denyingCheck.source.sourceId)'). "
      + "Tool '\(toolName)' performs \(actionClass), which this session forbids."

    return ClaudeCodeHookCheckDecision(isDenied: true, reason: reason)
  }

  /// Denies an unclassifiable MCP tool when the contract forbids any action class such a tool
  /// could perform (file mutation, command execution, network egress); otherwise allows it.
  /// Trusted PersonaKit tools are allowed before reaching here.
  private static func evaluateUnclassifiedMCPTool(
    toolName: String,
    manifest: ChecksManifest
  ) -> ClaudeCodeHookCheckDecision {
    let forbidden = ClaudeCodeEnforcement.mcpRelevantActionClasses
      .sorted()
      .compactMap { manifest.hookCheck(denying: $0) }

    guard !forbidden.isEmpty else {
      return ClaudeCodeHookCheckDecision(isDenied: false, reason: nil)
    }

    let capabilities = forbidden.map(\.id).joined(separator: ", ")
    var reason =
      "Blocked by PersonaKit contract: tool '\(toolName)' is an MCP tool PersonaKit cannot "
      + "classify, and this session forbids \(capabilities). Denying by fail-closed policy; "
      + "explicitly allow this tool only if it is read-only-safe."
    if let server = ClaudeCodeEnforcement.serverNameOfPersonaKitNamedMCPTool(toolName) {
      reason +=
        " If '\(server)' is PersonaKit's own MCP server (`claude mcp get \(server)` shows it runs "
        + "`personakit mcp`), ask the user to re-run "
        + "`personakit enforce install --mcp-server \(server)`; do not run it yourself."
    }

    return ClaudeCodeHookCheckDecision(isDenied: true, reason: reason)
  }
}
