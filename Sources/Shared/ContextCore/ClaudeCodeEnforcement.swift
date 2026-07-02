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

  /// Whether a tool name is an external MCP tool (which PK cannot classify).
  static func isMCPTool(_ name: String) -> Bool {
    name.hasPrefix("mcp__")
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

    let tools =
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
    var matcherPatterns = tools
    if deniesMcpRelevant {
      matcherPatterns.append(ClaudeCodeEnforcement.mcpToolPattern)
    }

    guard !matcherPatterns.isEmpty else {
      return ClaudeCodeEnforcementArtifacts(
        matcher: nil,
        hookEntry: nil,
        degradedActionClasses: degraded
      )
    }

    let matcher = matcherPatterns.joined(separator: "|")
    let command = "\(shellQuote(executablePath)) \(ClaudeCodeEnforcement.hookCheckSubcommand) --manifest \(shellQuote(manifestPath))"

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

/// Evaluates one incoming Claude Code tool call against a frozen manifest.
///
/// Host-specific only in the tool→action-class mapping; the deny decision itself lives in the
/// neutral core via ``ChecksManifest/hookCheck(denying:)``. Read-only toward the running
/// agent: it can only *deny*, never authorize.
public enum ClaudeCodeHookCheckEvaluator {
  public static func evaluate(toolName: String, manifest: ChecksManifest) -> ClaudeCodeHookCheckDecision {
    guard let actionClass = ClaudeCodeEnforcement.actionClass(forTool: toolName) else {
      // Not a known built-in tool. An external MCP tool is unclassifiable, so if the contract
      // forbids anything an MCP tool could do, fail closed rather than let it through.
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
    let reason =
      "Blocked by PersonaKit contract: tool '\(toolName)' is an MCP tool PersonaKit cannot "
      + "classify, and this session forbids \(capabilities). Denying by fail-closed policy; "
      + "explicitly allow this tool only if it is read-only-safe."

    return ClaudeCodeHookCheckDecision(isDenied: true, reason: reason)
  }
}
