import Foundation

/// OpenCode projection of a host-neutral ``ChecksManifest``: the tool-name to action-class map,
/// the MCP trust rules, and the protected enforcement paths.
///
/// Pure value logic. The server plugin acts as the hook and `personakit hook-check --host opencode`
/// feeds it an ``OpenCodeToolCall``; nothing here touches the file system except reading symlinks
/// when comparing paths.
public enum OpenCodeEnforcement {
  /// Single source of truth mapping host-neutral action classes to OpenCode built-in tool ids.
  static let toolActionClasses: [(actionClass: String, tools: [String])] = [
    ("file-mutation", ["apply_patch", "edit", "write"]),
    ("command-execution", ["bash"]),
    ("network-egress", ["webfetch", "websearch"]),
  ]

  /// Built-in tools that cannot mutate files, run commands, or reach the network, sorted.
  ///
  /// OpenCode 1.19.5 has no `list` or `todoread`. An allowlisted id with no built-in behind it is a
  /// free name for a custom or plugin tool to skip enforcement, so this list holds only ids that exist.
  /// The MCP-resource built-ins (`list_mcp_resources`, `list_mcp_resource_templates`, `read_mcp_resource`)
  /// are deliberately absent, so they fail closed.
  public static let readOnlyTools: [String] = [
    "glob", "grep", "invalid", "lsp", "plan_exit", "question", "read", "skill", "task", "todowrite",
  ]

  /// Config file names OpenCode reads from every directory between its start directory and the worktree, sorted.
  public static let protectedFileNames: [String] = [
    "opencode.json", "opencode.jsonc", "tui.json", "tui.jsonc",
  ]

  /// Directory name OpenCode loads plugins, custom tools, and the frozen manifest from.
  public static let protectedDirectoryName = ".opencode"

  static func actionClass(forTool tool: String) -> String? {
    toolActionClasses.first { $0.tools.contains { isSameID($0, tool) } }?.actionClass
  }

  /// Whether `tool` is one of ``readOnlyTools``, compared by bytes.
  static func isReadOnlyTool(_ tool: String) -> Bool {
    readOnlyTools.contains { isSameID($0, tool) }
  }

  /// Byte equality, the way OpenCode compares ids. Swift `==` uses canonical equivalence, so the Kelvin sign
  /// (U+212A) equals `K`; in OpenCode they are different tools and servers.
  static func isSameID(_ lhs: String, _ rhs: String) -> Bool {
    lhs.utf8.elementsEqual(rhs.utf8)
  }

  /// Whether `id` starts with `prefix`, compared by bytes like ``isSameID(_:_:)``.
  static func hasIDPrefix(_ id: String, _ prefix: String) -> Bool {
    id.utf8.starts(with: prefix.utf8)
  }

  /// The global OpenCode config locations, read from the environment OpenCode hands its hooks.
  ///
  /// Sorted, deduplicated, and standardized. An entry ending in `/` protects the directory and
  /// everything under it; any other entry protects that exact file. Empty values count as unset.
  /// Covers the config directory, `$HOME/.opencode/` (whatever `XDG_CONFIG_HOME` says), the cache
  /// directory that holds installed plugins and LSP binaries, and the three config-pointing variables.
  public static func globalConfigPaths(environment: [String: String]) -> [String] {
    func value(_ key: String) -> String? {
      environment[key].flatMap { $0.isEmpty ? nil : $0 }
    }

    let home = value("HOME")
    var entries: [String] = []
    if let directory = value("OPENCODE_CONFIG_DIR") {
      entries.append(lexicalPath(directory) + "/")
    }
    for file in ["OPENCODE_CONFIG", "OPENCODE_TUI_CONFIG"].compactMap(value) {
      entries.append(lexicalPath(file))
    }
    if let configHome = value("XDG_CONFIG_HOME") {
      entries.append(lexicalPath(configHome + "/opencode") + "/")
    } else if let home {
      entries.append(lexicalPath(home + "/.config/opencode") + "/")
    }
    if let cacheHome = value("XDG_CACHE_HOME") {
      entries.append(lexicalPath(cacheHome + "/opencode") + "/")
    } else if let home {
      entries.append(lexicalPath(home + "/.cache/opencode") + "/")
    }
    if let home {
      entries.append(lexicalPath(home + "/.opencode") + "/")
    }
    return Array(Set(entries)).sorted()
  }

  /// Replaces every character OpenCode rejects in an MCP key segment with `_`.
  ///
  /// OpenCode applies `[^A-Za-z0-9_-]` per UTF-16 code unit, so an astral character becomes two
  /// underscores.
  public static func sanitizeMCPName(_ name: String) -> String {
    String(
      name.utf16.map { unit -> Character in
        guard let byte = UInt8(exactly: unit), isMCPNameByte(byte) else { return "_" }
        return Character(Unicode.Scalar(byte))
      }
    )
  }

  private static func isMCPNameByte(_ byte: UInt8) -> Bool {
    (0x30...0x39).contains(byte) || (0x41...0x5A).contains(byte) || (0x61...0x7A).contains(byte)
      || byte == 0x5F || byte == 0x2D
  }

  /// The tool id OpenCode registers an MCP server's tool under.
  public static func mcpToolKey(server: String, tool: String) -> String {
    sanitizeMCPName(server) + "_" + sanitizeMCPName(tool)
  }

  /// Configured servers other than `serverName` that could also produce `tool`, sorted.
  ///
  /// OpenCode joins server and tool with `_`, so `a_b` plus tool `c` and `a` plus tool `b_c` share a key.
  static func collidingServers(for tool: String, serverName: String, configuredServers: [String]) -> [String] {
    configuredServers
      .filter { !isSameID($0, serverName) && hasIDPrefix(tool, sanitizeMCPName($0) + "_") }
      .sorted()
  }

  /// Whether `tool` has the shape of a PersonaKit MCP tool registered by `serverName`.
  static func isPersonaKitToolKey(_ tool: String, serverName: String) -> Bool {
    ClaudeCodeEnforcement.personaKitMCPToolNames.contains {
      isSameID(tool, mcpToolKey(server: serverName, tool: $0))
    }
  }

  /// Whether `tool` could be an MCP tool: some configured server's key prefix matches it.
  ///
  /// OpenCode lets an MCP tool replace a built-in with the same id (`plan` plus `exit` is `plan_exit`),
  /// so a name with a configured server's prefix is never trusted as the built-in.
  static func isPossiblyMCPTool(_ tool: String, configuredServers: [String]) -> Bool {
    configuredServers.contains { hasIDPrefix(tool, sanitizeMCPName($0) + "_") }
  }

  /// Whether `tool` is one of PersonaKit's own read-only MCP tools on the trusted server, and no
  /// other configured server could have produced the same key.
  public static func isTrustedPersonaKitMCPTool(
    _ tool: String,
    serverName: String,
    configuredServers: [String]
  ) -> Bool {
    guard configuredServers.contains(where: { isSameID($0, serverName) }),
      isPersonaKitToolKey(tool, serverName: serverName)
    else {
      return false
    }
    return collidingServers(for: tool, serverName: serverName, configuredServers: configuredServers).isEmpty
  }

  /// Whether editing `path` could change enforcement: an `.opencode` tree or OpenCode config file
  /// under `projectDirectory` (the worktree), or the global OpenCode config locations.
  ///
  /// A relative `path` resolves against `projectDirectory`. Paths are resolved physically, as the
  /// kernel does: each symlink (dangling ones too) is followed before any `..` applies. The path, the
  /// project directory, and each global entry are compared both as spelled and as resolved, component
  /// by component, with Unicode case folding, since macOS volumes are case-insensitive by default and
  /// APFS folds `ſ` to `s` and the Kelvin sign to `k`. Only components below the project directory
  /// count, so a `.opencode` ancestor of the project does not protect the whole project. A path that
  /// cannot be resolved (a symlink loop, or a filesystem error other than "does not exist") is
  /// protected.
  public static func isProtectedPath(
    _ path: String,
    projectDirectory: String,
    globalConfigPaths: [String]
  ) -> Bool {
    let absolutePath = path.hasPrefix("/") ? path : projectDirectory + "/" + path
    guard let pathForms = forms(absolutePath), let projectForms = forms(projectDirectory) else { return true }

    var globalEntries: [(isDirectory: Bool, forms: [[String]])] = []
    for entry in globalConfigPaths {
      guard let entryForms = forms(entry) else { return true }
      globalEntries.append((entry.hasSuffix("/"), entryForms))
    }

    let fileNames = Set(protectedFileNames.map(fold))
    let directoryName = fold(protectedDirectoryName)

    for pathForm in pathForms {
      for projectForm in projectForms where isUnder(pathForm, directory: projectForm) {
        let below = pathForm.dropFirst(projectForm.count)
        if below.contains(directoryName) { return true }
        if let last = below.last, fileNames.contains(last) { return true }
      }
      for entry in globalEntries {
        for entryForm in entry.forms {
          let matches = entry.isDirectory ? isUnder(pathForm, directory: entryForm) : pathForm == entryForm
          if matches { return true }
        }
      }
    }
    return false
  }

  /// Removes C0, C1, and DEL characters so a tool name or path cannot steer the terminal that shows a
  /// deny reason.
  public static func strippingControlCharacters(_ text: String) -> String {
    String(
      String.UnicodeScalarView(
        text.unicodeScalars.filter { $0.value >= 0x20 && !(0x7F...0x9F).contains($0.value) }
      )
    )
  }

  /// Case-folded components of `path` as spelled (made absolute, `.` and `..` applied lexically), then
  /// physically resolved; one element when both agree. `nil` when resolution cannot vouch for the path.
  private static func forms(_ path: String) -> [[String]]? {
    guard !path.utf8.contains(0) else { return nil }
    let spelled = lexicalComponents(path)
    guard let physical = physicalComponents(absolute(path)) else { return nil }
    let folded = [spelled, physical].map { $0.map(fold) }
    return folded[0] == folded[1] ? [folded[0]] : folded
  }

  /// Unicode case folding, so `ſ` matches `s` and the Kelvin sign matches `k` as on APFS.
  private static func fold(_ text: String) -> String {
    text.folding(options: .caseInsensitive, locale: nil)
  }

  private static func absolute(_ path: String) -> String {
    path.hasPrefix("/") ? path : FileManager.default.currentDirectoryPath + "/" + path
  }

  /// Splits on the `/` byte and drops `.` components. Splitting on `Character` would be wrong: `/`
  /// followed by a combining mark is a single `Character`.
  private static func pathComponents(_ path: String) -> [String] {
    path.utf8
      .split(separator: UInt8(ascii: "/"))
      .map { String(decoding: $0, as: UTF8.self) }
      .filter { $0 != "." }
  }

  /// Makes `path` absolute and applies `.` and `..` textually.
  private static func lexicalComponents(_ path: String) -> [String] {
    var resolved: [String] = []
    for component in pathComponents(absolute(path)) {
      if component == ".." {
        _ = resolved.popLast()
      } else {
        resolved.append(component)
      }
    }
    return resolved
  }

  private static func lexicalPath(_ path: String) -> String {
    "/" + lexicalComponents(path).joined(separator: "/")
  }

  private static let maxSymlinkHops = 40

  /// Resolves `path` the way the kernel does: walks the components left to right and follows every
  /// symlink (dangling ones to their target, relative targets against the link's parent) before a
  /// following `..` applies.
  ///
  /// Each component is `lstat`ed. A component that does not exist (or has a file before it) is kept as
  /// spelled, but the walk goes on checking later components: OpenCode creates the missing directory
  /// before it writes, so a following `..` climbs back into existing directories whose links the kernel
  /// then follows. Any other error returns `nil`, as does exceeding
  /// `maxSymlinkHops` links (a loop). The kernel limits only a link target plus the remaining path to
  /// `PATH_MAX`, so a resolved string past `PATH_MAX` is not proof that a component is a plain directory.
  private static func physicalComponents(_ path: String) -> [String]? {
    var pending = Array(pathComponents(path).reversed())
    var resolved: [String] = []
    var hops = 0

    while let component = pending.popLast() {
      if component == ".." {
        _ = resolved.popLast()
        continue
      }
      let candidate = "/" + (resolved + [component]).joined(separator: "/")
      switch linkTarget(atPath: candidate) {
      case .failure:
        return nil
      case .missing, .notALink:
        resolved.append(component)
      case .link(let target):
        hops += 1
        if hops > maxSymlinkHops { return nil }
        if target.hasPrefix("/") { resolved = [] }
        pending.append(contentsOf: pathComponents(target).reversed())
      }
    }
    return resolved
  }

  private enum LinkTarget {
    case link(String)
    case notALink
    case missing
    case failure
  }

  private static func linkTarget(atPath path: String) -> LinkTarget {
    var info = stat()
    guard lstat(path, &info) == 0 else {
      return errno == ENOENT || errno == ENOTDIR ? .missing : .failure
    }
    guard (info.st_mode & S_IFMT) == S_IFLNK else { return .notALink }

    var buffer = [CChar](repeating: 0, count: 4096)
    let length = readlink(path, &buffer, buffer.count)
    guard length >= 0, length < buffer.count else { return .failure }
    return .link(String(decoding: buffer[..<length].map { UInt8(bitPattern: $0) }, as: UTF8.self))
  }

  /// Whether `directory` is a prefix of `path`, component by component. The root contains everything.
  private static func isUnder(_ path: [String], directory: [String]) -> Bool {
    path.count >= directory.count && path.prefix(directory.count).elementsEqual(directory)
  }
}

/// One OpenCode tool call, as the server plugin hands it to `personakit hook-check --host opencode`.
///
/// `paths` must be absolute: the server plugin resolves them against `directory`, the directory OpenCode
/// started in, and the evaluator denies a relative one. `worktree` is the root OpenCode stops its config
/// walk at, and the root the protected-path rule covers.
public struct OpenCodeToolCall: Decodable, Equatable, Sendable {
  public let tool: String
  public let paths: [String]
  public let mcpServers: [String]
  public let directory: String
  public let worktree: String
}

/// Evaluates one OpenCode tool call against a frozen manifest.
///
/// Read-only toward the running agent: it can only deny, never authorize.
public enum OpenCodeHookCheckEvaluator {
  public static func evaluate(
    _ call: OpenCodeToolCall,
    manifest: ChecksManifest,
    globalConfigPaths: [String]
  ) -> ClaudeCodeHookCheckDecision {
    guard call.directory.hasPrefix("/"), call.worktree.hasPrefix("/"), call.paths.allSatisfy({ $0.hasPrefix("/") })
    else {
      return deny(
        "Blocked by PersonaKit contract: tool call '\(OpenCodeEnforcement.strippingControlCharacters(call.tool))' "
          + "is malformed (the start directory, the worktree, or a path is empty or not absolute). "
          + "Denying by fail-closed policy."
      )
    }

    let serverName = manifest.mcpServerName ?? ClaudeCodeEnforcement.defaultMCPServerName

    // An MCP tool replaces a built-in with the same id, so a configured server's prefix wins over the map.
    if OpenCodeEnforcement.isPossiblyMCPTool(call.tool, configuredServers: call.mcpServers) {
      return evaluateTrustedOrUnclassified(call, serverName: serverName, manifest: manifest)
    }

    let actionClass = OpenCodeEnforcement.actionClass(forTool: call.tool)

    if actionClass == "file-mutation" {
      guard !call.paths.isEmpty else {
        return deny(
          "Blocked by PersonaKit contract: tool '\(call.tool)' modifies files but names no path, so "
            + "PersonaKit cannot check it against its enforcement files. Denying by fail-closed policy."
        )
      }
      if let protected = call.paths.first(where: {
        OpenCodeEnforcement.isProtectedPath(
          $0,
          projectDirectory: call.worktree,
          globalConfigPaths: globalConfigPaths
        )
      }) {
        return deny(
          "Blocked by PersonaKit contract: tool '\(call.tool)' would modify "
            + "'\(OpenCodeEnforcement.strippingControlCharacters(protected))', one of the PersonaKit enforcement files "
            + "or OpenCode config locations (`.opencode`, `opencode.json(c)`, `tui.json(c)`, the global OpenCode "
            + "config and cache). Changing them could disable or bypass enforcement."
        )
      }
    }

    if let actionClass {
      guard let denyingCheck = manifest.hookCheck(denying: actionClass) else { return allow }
      return deny(
        "Blocked by PersonaKit contract: \(denyingCheck.id) — \(denyingCheck.mandate) "
          + "(from \(denyingCheck.source.sourceType) '\(denyingCheck.source.sourceId)'). "
          + "Tool '\(call.tool)' performs \(actionClass), which this session forbids."
      )
    }

    if OpenCodeEnforcement.isReadOnlyTool(call.tool) { return allow }

    return evaluateTrustedOrUnclassified(call, serverName: serverName, manifest: manifest)
  }

  private static let allow = ClaudeCodeHookCheckDecision(isDenied: false, reason: nil)

  private static func deny(_ reason: String) -> ClaudeCodeHookCheckDecision {
    ClaudeCodeHookCheckDecision(isDenied: true, reason: reason)
  }

  private static func evaluateTrustedOrUnclassified(
    _ call: OpenCodeToolCall,
    serverName: String,
    manifest: ChecksManifest
  ) -> ClaudeCodeHookCheckDecision {
    if OpenCodeEnforcement.isTrustedPersonaKitMCPTool(
      call.tool,
      serverName: serverName,
      configuredServers: call.mcpServers
    ) {
      return allow
    }
    return evaluateUnclassifiedTool(call, serverName: serverName, manifest: manifest)
  }

  /// Denies a tool PersonaKit cannot classify (an MCP tool, another plugin's tool, a custom tool) when
  /// the contract forbids any action class such a tool could perform; otherwise allows it.
  private static func evaluateUnclassifiedTool(
    _ call: OpenCodeToolCall,
    serverName: String,
    manifest: ChecksManifest
  ) -> ClaudeCodeHookCheckDecision {
    let forbidden = ClaudeCodeEnforcement.mcpRelevantActionClasses
      .sorted()
      .compactMap { manifest.hookCheck(denying: $0) }

    guard !forbidden.isEmpty else { return allow }

    let capabilities = forbidden.map(\.id).joined(separator: ", ")
    var reason =
      "Blocked by PersonaKit contract: tool '\(OpenCodeEnforcement.strippingControlCharacters(call.tool))' is a "
      + "tool PersonaKit cannot classify, and this session forbids \(capabilities). Denying by fail-closed "
      + "policy; explicitly allow this tool only if it is read-only-safe."

    let colliding = OpenCodeEnforcement.collidingServers(
      for: call.tool,
      serverName: serverName,
      configuredServers: call.mcpServers
    )
    if call.mcpServers.contains(where: { OpenCodeEnforcement.isSameID($0, serverName) }), !colliding.isEmpty,
      OpenCodeEnforcement.isPersonaKitToolKey(call.tool, serverName: serverName)
    {
      let names = colliding.map { "'\(OpenCodeEnforcement.strippingControlCharacters($0))'" }
        .joined(separator: ", ")
      reason +=
        " This key looks like a PersonaKit tool on '\(serverName)' but could also come from MCP server "
        + "\(names), so trust is withdrawn. Rename or remove the colliding server to restore it."
    }

    return deny(reason)
  }
}
