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

  /// Shell suffix that turns any checker failure into a block.
  ///
  /// Claude Code blocks a tool call only when the hook exits 2; any other non-zero exit, such as a
  /// missing binary (127) or a crash, lets the call through. The checker itself always exits 0, so
  /// a non-zero status means it never reached a decision, and the suffix exits 2 with a reason on
  /// stderr, which Claude Code shows the agent.
  static let failClosedSuffix =
    "|| { echo 'PersonaKit could not check this tool call, so it is blocked. "
    + "Tell the user that personakit hook-check failed.' >&2; exit 2; }"

  /// Single source of truth mapping host-neutral action classes to Claude Code tools.
  ///
  /// The checker turns an incoming tool name into its action class and denies it when the contract
  /// forbids that class. `Monitor` and `PowerShell` run shell commands, so they count as command
  /// execution alongside `Bash`.
  static let toolActionClasses: [(actionClass: String, tools: [String])] = [
    ("file-mutation", ["Edit", "Write", "NotebookEdit"]),
    ("command-execution", ["Bash", "Monitor", "PowerShell"]),
    ("network-egress", ["WebFetch", "WebSearch"]),
  ]

  /// Built-in tools that cannot mutate files, run commands, or reach the network, sorted.
  ///
  /// Any other built-in is one PersonaKit cannot classify, so the checker asks the operator rather
  /// than let it through or strand the agent. `Skill` is deliberately absent: a skill can run shell
  /// commands while it loads. `Agent` and `Task` are allowed only for a built-in local agent type with
  /// no `isolation` (see ``subagentTools``); their subagents' own tool calls reach the hook.
  public static let readOnlyTools: [String] = [
    "Agent", "AskUserQuestion", "EnterPlanMode", "ExitPlanMode", "Glob", "Grep", "ListAgents", "Read", "Task",
    "TaskCreate", "TaskGet", "TaskList", "TaskOutput", "TaskUpdate", "TodoWrite", "ToolSearch",
  ]

  /// Tools that start a subagent. With `isolation` set, the subagent runs in a new git worktree (a branch
  /// and a directory written outside the file tools) or a remote environment the local hook never sees.
  /// A custom agent type can carry its own `isolation`, so only built-in types count as read-only.
  static let subagentTools: Set<String> = ["Agent", "Task"]

  /// Claude Code's built-in agent types, which run locally with no `isolation` of their own.
  static let localSubagentTypes: Set<String> = [
    "Explore", "Plan", "claude-code-guide", "fork", "general-purpose", "statusline-setup",
  ]

  /// Built-ins that list or read MCP resources. Allowed only against PersonaKit's own trusted server,
  /// so an agent can re-ground; any other server's resources are asked about.
  static let mcpResourceTools: Set<String> = ["ListMcpResourcesTool", "ReadMcpResourceDirTool", "ReadMcpResourceTool"]

  /// Claude Code's `permission_mode` when it skips permission prompts, so an ask would go unanswered.
  static let bypassPermissionMode = "bypassPermissions"

  /// Matcher that routes every tool to the checker.
  ///
  /// A fixed list of tool names would let any tool missing from it, including one Claude Code adds
  /// later, slip past the contract unchecked.
  static let allToolsPattern = ".*"

  /// Action classes a tool PersonaKit cannot classify could plausibly perform. If any is forbidden,
  /// such a tool is put to the operator, since PK cannot prove it is safe.
  static let unclassifiedToolActionClasses: Set<String> = ["file-mutation", "command-execution", "network-egress"]

  /// Returns the action class a Claude Code tool belongs to, if any is mapped.
  static func actionClass(forTool tool: String) -> String? {
    toolActionClasses.first { $0.tools.contains(tool) }?.actionClass
  }

  /// Whether a tool edits files, so its path is checked against the enforcement files.
  static func isFileMutationTool(_ tool: String) -> Bool {
    actionClass(forTool: tool) == "file-mutation"
  }

  /// Whether a tool name is an external MCP tool.
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

/// A matcher-scoped group of hooks: `{ "matcher": ".*", "hooks": [ … ] }`.
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
  /// The tool-name matcher scoping which tools invoke the checker (every tool), if any.
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

    let mappedActionClasses = Set(
      ClaudeCodeEnforcement.toolActionClasses
        .filter { !$0.tools.isEmpty }
        .map(\.actionClass)
    )
    let degraded = deniedSet.subtracting(mappedActionClasses).sorted()

    guard !deniedSet.isDisjoint(with: ClaudeCodeEnforcement.unclassifiedToolActionClasses) else {
      return ClaudeCodeEnforcementArtifacts(
        matcher: nil,
        hookEntry: nil,
        degradedActionClasses: degraded
      )
    }

    // Every tool is routed: a forbidden class is denied, a file edit is checked against the enforcement files
    // even when edits are allowed, and a tool PersonaKit cannot classify is put to the operator.
    let matcher = ClaudeCodeEnforcement.allToolsPattern
    let command =
      "\(shellQuote(executablePath)) \(ClaudeCodeEnforcement.hookCheckSubcommand) --manifest \(shellQuote(manifestPath)) "
      + ClaudeCodeEnforcement.failClosedSuffix

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
  /// Claude Code's `permissionDecision` values. `ask` puts the call to the operator; where no one can
  /// answer (a headless run), Claude Code denies it.
  public enum Permission: String, Sendable {
    case allow
    case deny
    case ask
  }

  public let permission: Permission
  public let reason: String?

  public var isDenied: Bool {
    permission == .deny
  }

  public init(permission: Permission, reason: String?) {
    self.permission = permission
    self.reason = reason
  }

  public init(isDenied: Bool, reason: String?) {
    self.init(permission: isDenied ? .deny : .allow, reason: reason)
  }
}

/// The fields of one Claude Code `PreToolUse` call the checker reads.
public struct ClaudeCodeToolCall: Equatable, Sendable {
  public let toolName: String
  /// `tool_input.file_path` and `tool_input.notebook_path`, whichever are strings, as sent.
  public let paths: [String]
  /// The session's working directory, which a relative path resolves against.
  public let cwd: String?
  /// `tool_input.isolation` of a subagent call (`worktree`, `remote`), as sent.
  public let isolation: String?
  /// `tool_input.subagent_type` of a subagent call, as sent.
  public let subagentType: String?
  /// `tool_input.server` of an MCP-resource call, as sent.
  public let mcpServer: String?
  /// The session's `permission_mode`, as sent.
  public let permissionMode: String?

  public init(
    toolName: String,
    paths: [String],
    cwd: String?,
    isolation: String? = nil,
    subagentType: String? = nil,
    mcpServer: String? = nil,
    permissionMode: String? = nil
  ) {
    self.toolName = toolName
    self.paths = paths
    self.cwd = cwd
    self.isolation = isolation
    self.subagentType = subagentType
    self.mcpServer = mcpServer
    self.permissionMode = permissionMode
  }
}

/// Evaluates one incoming Claude Code tool call against a frozen manifest.
///
/// Host-specific only in the tool→action-class mapping; the deny decision itself lives in the
/// neutral core via ``ChecksManifest/hookCheck(denying:)``. Read-only toward the running
/// agent: it can only *deny* or *ask* the operator, never authorize.
public enum ClaudeCodeHookCheckEvaluator {
  /// Appended to every denial so the agent stops instead of hunting for another route to the same action.
  static let noWorkaroundInstruction =
    "Do not retry it through another tool or a workaround; stop and tell the user what you need."

  /// Denies a file edit that targets one of `protectedPaths` (see
  /// ``ClaudeCodeEnforcement/protectedPaths(manifestPath:configDirectory:executablePath:)``), or that names
  /// no path it can resolve, before applying the contract to the tool. An ask becomes a deny when Claude
  /// Code is skipping permission prompts, since no one would answer it.
  public static func evaluate(
    _ call: ClaudeCodeToolCall,
    manifest: ChecksManifest,
    protectedPaths: [String],
    homeDirectory: String?
  ) -> ClaudeCodeHookCheckDecision {
    let decision = evaluateContract(
      call,
      manifest: manifest,
      protectedPaths: protectedPaths,
      homeDirectory: homeDirectory
    )
    guard decision.permission == .ask, call.permissionMode == ClaudeCodeEnforcement.bypassPermissionMode else {
      return decision
    }

    return ClaudeCodeHookCheckDecision(
      permission: .deny,
      reason: "Blocked by PersonaKit contract: this call needs the operator's approval, but Claude Code is "
        + "skipping permission prompts, so no one can give it. \(decision.reason ?? "")"
    )
  }

  private static func evaluateContract(
    _ call: ClaudeCodeToolCall,
    manifest: ChecksManifest,
    protectedPaths: [String],
    homeDirectory: String?
  ) -> ClaudeCodeHookCheckDecision {
    if ClaudeCodeEnforcement.subagentTools.contains(call.toolName) {
      if let isolation = call.isolation, !isolation.isEmpty {
        let shown = OpenCodeEnforcement.strippingControlCharacters(isolation)
        return evaluateUnclassifiedTool(
          toolName: call.toolName,
          detail: " with isolation '\(shown)'",
          manifest: manifest
        )
      }
      if let type = call.subagentType, !type.isEmpty, !ClaudeCodeEnforcement.localSubagentTypes.contains(type) {
        let shown = OpenCodeEnforcement.strippingControlCharacters(type)
        return evaluateUnclassifiedTool(
          toolName: call.toolName,
          detail: " with agent type '\(shown)'",
          manifest: manifest
        )
      }
    }

    if ClaudeCodeEnforcement.mcpResourceTools.contains(call.toolName),
      call.mcpServer == (manifest.mcpServerName ?? ClaudeCodeEnforcement.defaultMCPServerName)
    {
      return ClaudeCodeHookCheckDecision(permission: .allow, reason: nil)
    }

    if ClaudeCodeEnforcement.isFileMutationTool(call.toolName) {
      let absolutePaths = call.paths.map {
        ClaudeCodeEnforcement.absolutePath($0, cwd: call.cwd, homeDirectory: homeDirectory)
      }
      guard !absolutePaths.isEmpty, !call.paths.contains(""), !absolutePaths.contains(nil) else {
        return ClaudeCodeHookCheckDecision(
          permission: .deny,
          reason: "Blocked by PersonaKit contract: tool '\(call.toolName)' modifies files but names no path "
            + "PersonaKit can resolve, so it cannot check it against its enforcement files. "
            + "Denying by fail-closed policy. " + noWorkaroundInstruction
        )
      }
      if let protected = absolutePaths.compactMap({ $0 }).first(where: {
        OpenCodeEnforcement.matchesProtectedEntry($0, entries: protectedPaths)
      }) {
        return ClaudeCodeHookCheckDecision(
          permission: .deny,
          reason: "Blocked by PersonaKit contract: tool '\(call.toolName)' would modify "
            + "'\(OpenCodeEnforcement.strippingControlCharacters(protected))', one of the PersonaKit enforcement "
            + "files (the manifest folder, `.claude/settings.json`, `.claude/settings.local.json`, the user "
            + "Claude Code settings, the personakit binary). Changing them could disable or bypass enforcement. "
            + noWorkaroundInstruction
        )
      }
    }

    return evaluate(toolName: call.toolName, manifest: manifest)
  }

  /// Applies the contract to the tool by name alone, without the path check.
  public static func evaluate(toolName: String, manifest: ChecksManifest) -> ClaudeCodeHookCheckDecision {
    guard let actionClass = ClaudeCodeEnforcement.actionClass(forTool: toolName) else {
      // Not a classified tool. Read-only built-ins and PersonaKit's own MCP tools from the trusted
      // server are allowed; anything else is put to the operator.
      if ClaudeCodeEnforcement.readOnlyTools.contains(toolName)
        || ClaudeCodeEnforcement.isTrustedPersonaKitMCPTool(
          toolName,
          serverName: manifest.mcpServerName ?? ClaudeCodeEnforcement.defaultMCPServerName
        )
      {
        return ClaudeCodeHookCheckDecision(permission: .allow, reason: nil)
      }
      return evaluateUnclassifiedTool(toolName: toolName, detail: "", manifest: manifest)
    }

    guard let denyingCheck = manifest.hookCheck(denying: actionClass) else {
      return ClaudeCodeHookCheckDecision(permission: .allow, reason: nil)
    }

    let reason =
      "Blocked by PersonaKit contract: \(denyingCheck.id) — \(denyingCheck.mandate) "
      + "(from \(denyingCheck.source.sourceType) '\(denyingCheck.source.sourceId)'). "
      + "Tool '\(toolName)' performs \(actionClass), which this session forbids. "
      + noWorkaroundInstruction

    return ClaudeCodeHookCheckDecision(permission: .deny, reason: reason)
  }

  /// Asks the operator about a call PersonaKit cannot classify (an unlisted built-in, a third-party MCP tool,
  /// another server's MCP resource, or a subagent that is not a built-in local one) when the contract forbids
  /// any action class such a call could perform; otherwise allows it.
  /// The reason is shown in the operator's prompt, and reaches the agent when a headless run refuses
  /// the call. `detail` qualifies the tool in that reason.
  private static func evaluateUnclassifiedTool(
    toolName: String,
    detail: String,
    manifest: ChecksManifest
  ) -> ClaudeCodeHookCheckDecision {
    let forbidden = ClaudeCodeEnforcement.unclassifiedToolActionClasses
      .sorted()
      .compactMap { manifest.hookCheck(denying: $0) }

    guard !forbidden.isEmpty else {
      return ClaudeCodeHookCheckDecision(permission: .allow, reason: nil)
    }

    let capabilities = forbidden.map(\.id).joined(separator: ", ")
    var reason =
      "PersonaKit contract needs approval: PersonaKit cannot classify tool "
      + "'\(OpenCodeEnforcement.strippingControlCharacters(toolName))'\(detail), and this session "
      + "forbids \(capabilities). Approve only if this call does none of that. If it is refused, the agent "
      + "should not work around it but tell the user what it needs."
    if let server = ClaudeCodeEnforcement.serverNameOfPersonaKitNamedMCPTool(toolName) {
      reason +=
        " If '\(server)' is PersonaKit's own MCP server (`claude mcp get \(server)` shows it runs "
        + "`personakit mcp`), ask the user to re-run "
        + "`personakit enforce install --mcp-server \(server)`; do not run it yourself."
    }

    return ClaudeCodeHookCheckDecision(permission: .ask, reason: reason)
  }
}
