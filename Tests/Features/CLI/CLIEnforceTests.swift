import CryptoKit
import Foundation
import Testing

@testable import ContextCLI
@testable import ContextCore
@testable import ContextMCP

struct CLIEnforceTests {
  /// Derives the read-only fixture's manifest and writes it to a fresh temp file.
  private func writeReadOnlyManifest() throws -> URL {
    let scopes = ScopeSet(projectScopeURL: readOnlyFixtureRootURL(), globalScopeURL: nil)
    let session = try SessionFileLoader.load(scopes: scopes, sessionId: "read-only-auditor_audit-pass")
    let result = try SessionContractResolver.resolve(scopes: scopes, session: session)
    let manifest = ChecksManifestDeriver.derive(from: result)

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("pk-enforce-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let url = directory.appendingPathComponent("manifest.checks.json")
    try encoder.encode(manifest).write(to: url)
    return url
  }

  /// Runs `hook-check` and returns stdout. The Claude host (default) gets a synthetic PreToolUse payload;
  /// pass `stdin` to override it (the OpenCode host needs its own payload).
  private func runHookCheck(
    manifest: URL,
    toolName: String = "",
    host: String? = nil,
    expectSHA256: String? = nil,
    stdin: String? = nil
  ) -> String {
    runHookCheckWithStatus(
      manifest: manifest,
      toolName: toolName,
      host: host,
      expectSHA256: expectSHA256,
      stdin: stdin
    ).stdout
  }

  private func runHookCheckWithStatus(
    manifest: URL,
    toolName: String = "",
    host: String? = nil,
    expectSHA256: String? = nil,
    stdin: String? = nil
  ) -> (status: Int32, stdout: String, stderr: String) {
    let payload = stdin ?? "{\"tool_name\":\"\(toolName)\",\"tool_input\":{}}"
    let cli = PersonaKitCLI(
      interactiveIO: CLIInteractiveIO(
        isInteractive: { false },
        readLine: { nil },
        readStdinToEnd: { payload }
      )
    )

    var arguments = ["personakit", "hook-check", "--manifest", manifest.path]
    if let host {
      arguments += ["--host", host]
    }
    if let expectSHA256 {
      arguments += ["--expect-sha256", expectSHA256]
    }

    var status: Int32 = 0
    var stdout = ""
    let stderr = captureStderr {
      stdout = captureStdout {
        status = cli.run(arguments: arguments)
      }
    }
    return (status, stdout, stderr)
  }

  private func sha256Hex(of url: URL) throws -> String {
    SHA256.hash(data: try Data(contentsOf: url)).map { String(format: "%02x", $0) }.joined()
  }

  private func openCodePayload(
    tool: String,
    paths: [String] = [],
    directory: String = "/tmp/pk-project",
    worktree: String? = nil
  ) throws -> String {
    let object: [String: Any] = [
      "tool": tool,
      "paths": paths,
      "mcpServers": ["personakit"],
      "directory": directory,
      "worktree": worktree ?? directory,
    ]
    return String(decoding: try JSONSerialization.data(withJSONObject: object), as: UTF8.self)
  }

  /// A manifest whose persona forbids only network access, so file-mutation is denied by nothing
  /// but the protected-path rule.
  private func writeNetworkOnlyManifest() throws -> URL {
    let manifest = ChecksManifestDeriver.derive(
      sessionId: "s",
      persona: Persona(
        id: "no-network",
        version: "1.0",
        name: "No Network",
        summary: "s",
        responsibilities: [],
        values: [],
        nonGoals: [],
        defaultKitIds: [],
        allowedSkillIds: [],
        forbiddenSkillIds: [],
        forbiddenCapabilities: ["network-access"]
      ),
      directive: nil
    )
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("pk-enforce-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let url = directory.appendingPathComponent("manifest.checks.json")
    try JSONEncoder().encode(manifest).write(to: url)
    return url
  }

  /// Calls the OpenCode decision directly, with stdin supplied and the environment and executable injected.
  private func decideOpenCode(
    manifest: URL,
    stdin: String,
    environment: [String: String],
    executablePath: String?,
    passwdHome: String? = nil
  ) throws -> ClaudeCodeHookCheckDecision {
    let context = CLIContext(
      scopeRootResolver: ScopeRootResolver(),
      mcpServerRunner: MCPServerRunner(),
      interactiveIO: CLIInteractiveIO(
        isInteractive: { false },
        readLine: { nil },
        readStdinToEnd: { stdin }
      )
    )
    let sha = try sha256Hex(of: manifest)
    return CLIEnvironment.withContext(context) {
      HookCheckCommand.decideOpenCode(
        manifestPath: manifest.path,
        expectedSHA256: sha,
        environment: environment,
        executablePath: executablePath,
        passwdHome: { passwdHome }
      )
    }
  }

  @Test
  func hookCheckDeniesEditAndBashAsksForUnknownToolsAndAllowsRead() throws {
    let manifest = try writeReadOnlyManifest()

    #expect(runHookCheck(manifest: manifest, toolName: "Edit").contains("\"permissionDecision\":\"deny\""))
    // The bypass proof: a shell write goes through Bash, which read-only forbids.
    #expect(runHookCheck(manifest: manifest, toolName: "Bash").contains("\"permissionDecision\":\"deny\""))
    // Monitor runs shell commands too.
    #expect(runHookCheck(manifest: manifest, toolName: "Monitor").contains("\"permissionDecision\":\"deny\""))
    // A tool PersonaKit cannot classify goes to the operator.
    #expect(runHookCheck(manifest: manifest, toolName: "Artifact").contains("\"permissionDecision\":\"ask\""))
    // Allow is an empty stdout + exit 0.
    #expect(runHookCheck(manifest: manifest, toolName: "Read").isEmpty)
  }

  @Test
  func hookCheckFailsClosedOnUnreadableManifest() {
    let cli = PersonaKitCLI(
      interactiveIO: CLIInteractiveIO(
        isInteractive: { false },
        readLine: { nil },
        readStdinToEnd: { "{\"tool_name\":\"Edit\"}" }
      )
    )

    let output = captureStdout {
      _ = cli.run(arguments: ["personakit", "hook-check", "--manifest", "/no/such/manifest.json"])
    }

    #expect(output.contains("\"permissionDecision\":\"deny\""))
    #expect(output.contains("fail-closed"))
    #expect(output.contains("To fix it, the user can run `personakit enforce install"))
    #expect(output.contains("stop and tell the user"))
  }

  /// Calls the Claude Code decision directly, with stdin supplied and the environment and executable injected.
  private func decideClaude(
    manifest: URL,
    readStdin: @escaping @Sendable () throws -> String,
    environment: [String: String] = [:],
    executablePath: String? = nil
  ) -> ClaudeCodeHookCheckDecision {
    let context = CLIContext(
      scopeRootResolver: ScopeRootResolver(),
      mcpServerRunner: MCPServerRunner(),
      interactiveIO: CLIInteractiveIO(isInteractive: { false }, readLine: { nil }, readStdinToEnd: readStdin)
    )
    return CLIEnvironment.withContext(context) {
      HookCheckCommand.decide(
        manifestPath: manifest.path,
        environment: environment,
        executablePath: executablePath,
        passwdHome: { nil }
      )
    }
  }

  private func claudePayload(
    tool: String,
    input: [String: Any],
    cwd: String,
    permissionMode: String? = nil
  ) throws -> String {
    var object: [String: Any] = ["tool_name": tool, "tool_input": input, "cwd": cwd]
    if let permissionMode {
      object["permission_mode"] = permissionMode
    }
    return String(decoding: try JSONSerialization.data(withJSONObject: object), as: UTF8.self)
  }

  @Test
  func claudeHostReadsIsolationServerAndPermissionModeFromThePayload() throws {
    let manifest = try writeReadOnlyManifest()

    func decide(_ tool: String, _ input: [String: Any], mode: String? = nil) throws -> ClaudeCodeHookCheckDecision {
      let payload = try claudePayload(tool: tool, input: input, cwd: "/", permissionMode: mode)
      return decideClaude(manifest: manifest, readStdin: { payload })
    }

    #expect(try decide("Agent", ["prompt": "x"]).permission == .allow)
    #expect(try decide("Agent", ["prompt": "x", "isolation": "worktree"]).permission == .ask)
    #expect(try decide("Agent", ["prompt": "x", "isolation": true]).permission == .ask)
    #expect(try decide("Agent", ["prompt": "x", "subagent_type": "Explore"]).permission == .allow)
    #expect(try decide("Agent", ["prompt": "x", "subagent_type": "cloud-worker"]).permission == .ask)
    #expect(try decide("Agent", ["prompt": "x", "subagent_type": ["Explore"]]).permission == .ask)
    #expect(try decide("ReadMcpResourceTool", ["server": "personakit", "uri": "pk://x"]).permission == .allow)
    #expect(try decide("ReadMcpResourceTool", ["server": "other", "uri": "x"]).permission == .ask)
    #expect(try decide("CronCreate", [:], mode: "default").permission == .ask)
    #expect(try decide("CronCreate", [:], mode: "bypassPermissions").permission == .deny)
  }

  @Test
  func claudeHostProtectsEnforcementFilesWhenEditsAreAllowed() throws {
    let manifest = try writeNetworkOnlyManifest()
    let directory = manifest.deletingLastPathComponent().path
    let home = try freshProjectDir("pk-claude-home").path
    let binary = try freshProjectDir("pk-claude-bin").path + "/personakit"

    func decide(_ tool: String, _ input: [String: Any]) throws -> ClaudeCodeHookCheckDecision {
      let payload = try claudePayload(tool: tool, input: input, cwd: home)
      return decideClaude(
        manifest: manifest,
        readStdin: { payload },
        environment: ["HOME": home],
        executablePath: binary
      )
    }

    #expect(try decide("Edit", ["file_path": manifest.path]).isDenied)
    #expect(try decide("Write", ["file_path": "~/.claude/settings.json"]).isDenied)
    #expect(try decide("NotebookEdit", ["notebook_path": binary]).isDenied)
    #expect(try decide("Edit", ["file_path": 7]).reason?.contains("names no path") == true)
    #expect(try !decide("Edit", ["file_path": directory + "/../src/a.swift"]).isDenied)
    #expect(try !decide("Write", ["file_path": "notes.md"]).isDenied)
    #expect(try decide("Write", ["file_path": ".claude/settings.json"]).isDenied)
  }

  @Test
  func claudeHostUsesClaudeConfigDirForUserSettings() throws {
    let manifest = try writeNetworkOnlyManifest()
    let config = try freshProjectDir("pk-claude-config").path
    let payload = try claudePayload(tool: "Write", input: ["file_path": config + "/settings.json"], cwd: "/")

    let decision = decideClaude(manifest: manifest, readStdin: { payload }, environment: ["CLAUDE_CONFIG_DIR": config])
    #expect(decision.isDenied)
  }

  @Test
  func claudeHostDeniesWhenStdinCannotBeRead() throws {
    let manifest = try writeNetworkOnlyManifest()

    let decision = decideClaude(manifest: manifest, readStdin: { throw CocoaError(.fileReadUnknown) })
    #expect(decision.isDenied)
    #expect(decision.reason?.contains("could not read the tool call") == true)
    #expect(decision.reason?.contains("To fix it, the user can restart Claude Code") == true)
    #expect(decision.reason?.hasSuffix(ClaudeCodeHookCheckEvaluator.noWorkaroundInstruction) == true)
  }

  @Test
  func openCodeHostDeniesEditAllowsRead() throws {
    let manifest = try writeReadOnlyManifest()
    let sha = try sha256Hex(of: manifest)

    let denied = runHookCheckWithStatus(
      manifest: manifest,
      host: "opencode",
      expectSHA256: sha,
      stdin: try openCodePayload(tool: "edit", paths: ["/tmp/pk-project/a.swift"])
    )
    #expect(denied.status == 0)
    #expect(denied.stdout.hasPrefix("{\"decision\":\"deny\",\"reason\":\""))
    #expect(!denied.stdout.contains("hookSpecificOutput"))

    let allowed = runHookCheckWithStatus(
      manifest: manifest,
      host: "opencode",
      expectSHA256: sha,
      stdin: try openCodePayload(tool: "read", paths: ["/tmp/pk-project/a.swift"])
    )
    #expect(allowed.status == 0)
    #expect(allowed.stdout.isEmpty)
  }

  @Test
  func hookCheckDeniesOnSHA256Mismatch() throws {
    let manifest = try writeReadOnlyManifest()
    let wrong = String(repeating: "0", count: 64)

    // `read` would be allowed, so only the digest check can produce this deny.
    let output = runHookCheck(
      manifest: manifest,
      host: "opencode",
      expectSHA256: wrong,
      stdin: try openCodePayload(tool: "read", paths: ["/tmp/pk-project/a.swift"])
    )

    #expect(output.contains("\"decision\":\"deny\""))
    #expect(output.contains("changed since OpenCode started"))
    #expect(output.contains("\"reason\":\"Blocked by PersonaKit contract: PersonaKit enforcement manifest at "))
    #expect(output.contains("To fix it, the user can restart OpenCode to load the current contract."))
    #expect(output.contains("stop and tell the user"))
  }

  @Test
  func hookCheckNamesTheFixWhenTheOpenCodeManifestCannotBeDecoded() throws {
    let manifest = FileManager.default.temporaryDirectory.appendingPathComponent("pk-bad-\(UUID().uuidString).json")
    try Data("not a manifest".utf8).write(to: manifest)

    let output = runHookCheck(
      manifest: manifest,
      host: "opencode",
      expectSHA256: try sha256Hex(of: manifest),
      stdin: try openCodePayload(tool: "read")
    )

    #expect(output.contains("PersonaKit enforcement could not decode its manifest"))
    #expect(output.contains("To fix it, the user can run `personakit enforce install --host opencode --session <id>`"))
    #expect(output.contains("stop and tell the user"))
  }

  @Test
  func hookCheckDeniesWhenManifestChangesAfterDigest() throws {
    let manifest = try writeReadOnlyManifest()
    let sha = try sha256Hex(of: manifest)
    var bytes = try Data(contentsOf: manifest)
    bytes.append(contentsOf: Array("\n".utf8))
    try bytes.write(to: manifest)

    let output = runHookCheck(
      manifest: manifest,
      host: "opencode",
      expectSHA256: sha,
      stdin: try openCodePayload(tool: "read", paths: ["/tmp/pk-project/a.swift"])
    )

    #expect(output.contains("changed since OpenCode started"))
    #expect(output.contains("\"reason\":\"Blocked by PersonaKit contract: PersonaKit enforcement manifest at "))
  }

  @Test
  func openCodeManifestReasonsStripControlCharactersFromThePath() throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("pk-ctl-\u{1b}[2J-\u{9b}31m-\u{7f}-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let manifest = directory.appendingPathComponent("s.checks.json")
    let notAManifest = Data("[]".utf8)
    try notAManifest.write(to: manifest)
    let sha = SHA256.hash(data: notAManifest).map { String(format: "%02x", $0) }.joined()

    let decisions = [
      // decode
      HookCheckCommand.decideOpenCode(manifestPath: manifest.path, expectedSHA256: sha, environment: [:]),
      // mismatch
      HookCheckCommand.decideOpenCode(
        manifestPath: manifest.path,
        expectedSHA256: String(repeating: "0", count: 64),
        environment: [:]
      ),
      // unreadable
      HookCheckCommand.decideOpenCode(
        manifestPath: directory.appendingPathComponent("gone.checks.json").path,
        expectedSHA256: sha,
        environment: [:]
      ),
    ]
    for decision in decisions {
      let reason = try #require(decision.reason)
      #expect(decision.isDenied)
      #expect(reason.contains("pk-ctl-[2J-31m--"))
      #expect(!reason.unicodeScalars.contains { $0.value < 0x20 || (0x7F...0x9F).contains($0.value) })
    }
  }

  @Test
  func openCodeHostFailsClosedOnMalformedStdin() throws {
    let missing = URL(fileURLWithPath: "/no/such/manifest.json")
    let unreadable = runHookCheck(
      manifest: missing,
      host: "opencode",
      expectSHA256: String(repeating: "0", count: 64),
      stdin: try openCodePayload(tool: "read")
    )
    #expect(unreadable.contains("\"decision\":\"deny\""))
    #expect(unreadable.contains("fail-closed"))
    #expect(unreadable.contains("To fix it, the user can restart OpenCode"))
    #expect(unreadable.contains("stop and tell the user"))

    let manifest = try writeReadOnlyManifest()
    let sha = try sha256Hex(of: manifest)
    for stdin in ["", "not json", "{\"tool\":\"read\"}", "{\"tool_name\":\"Read\"}"] {
      let output = runHookCheck(manifest: manifest, host: "opencode", expectSHA256: sha, stdin: stdin)
      #expect(output.contains("\"decision\":\"deny\""))
      #expect(output.contains("fail-closed"))
      #expect(output.contains("To fix it, the user can"))
      #expect(output.contains("stop and tell the user"))
    }
  }

  @Test
  func openCodeHostRequiresExpectSHA256() throws {
    let manifest = try writeReadOnlyManifest()

    let result = runHookCheckWithStatus(
      manifest: manifest,
      host: "opencode",
      stdin: try openCodePayload(tool: "read")
    )

    #expect(result.status != 0)
    #expect(result.stderr.contains("--expect-sha256"))
    #expect(result.stdout.isEmpty)
  }

  @Test
  func openCodeHostProtectsGlobalConfigFromEnvironment() throws {
    let manifest = try writeNetworkOnlyManifest()
    let home = FileManager.default.temporaryDirectory.appendingPathComponent("pk-home-\(UUID().uuidString)").path
    let pluginPath = "\(home)/.config/opencode/plugins/x.ts"
    let stdin = try openCodePayload(tool: "edit", paths: [pluginPath])

    let protected = try decideOpenCode(
      manifest: manifest,
      stdin: stdin,
      environment: ["HOME": home],
      executablePath: nil
    )
    #expect(protected.isDenied)
    #expect(protected.reason?.contains("enforcement files") == true)

    // Same call with a different HOME is not protected: only the injected environment decides.
    let unprotected = try decideOpenCode(
      manifest: manifest,
      stdin: stdin,
      environment: ["HOME": home + "-other"],
      executablePath: nil
    )
    #expect(!unprotected.isDenied)
  }

  @Test
  func openCodeHostProtectsGlobalConfigWithoutHome() throws {
    let manifest = try writeNetworkOnlyManifest()
    let home = FileManager.default.temporaryDirectory.appendingPathComponent("pk-passwd-\(UUID().uuidString)").path

    for environment in [[String: String](), ["HOME": ""]] {
      let paths = [
        "\(home)/.config/opencode/plugins/x.ts",
        "\(home)/.opencode/plugins/x.ts",
        "\(home)/.cache/opencode/x",
      ]
      for path in paths {
        let decision = try decideOpenCode(
          manifest: manifest,
          stdin: try openCodePayload(tool: "write", paths: [path]),
          environment: environment,
          executablePath: nil,
          passwdHome: home
        )
        #expect(decision.isDenied, "expected \(path) protected with environment \(environment)")
      }
    }
  }

  @Test
  func hookCheckDeniesWhenManifestDeleted() throws {
    let manifest = try writeReadOnlyManifest()
    let sha = try sha256Hex(of: manifest)
    try FileManager.default.removeItem(at: manifest)

    let output = runHookCheck(
      manifest: manifest,
      host: "opencode",
      expectSHA256: sha,
      stdin: try openCodePayload(tool: "read", paths: ["/tmp/pk-project/a.swift"])
    )

    #expect(output.contains("\"decision\":\"deny\""))
    #expect(output.contains("missing or changed since OpenCode started"))
    #expect(output.contains("\"reason\":\"Blocked by PersonaKit contract: PersonaKit enforcement manifest at "))
    #expect(output.contains("restart OpenCode"))
  }

  @Test
  func openCodeHostAcceptsUppercaseExpectedSHA256() throws {
    let manifest = try writeReadOnlyManifest()
    let sha = try sha256Hex(of: manifest).uppercased()

    let output = runHookCheck(
      manifest: manifest,
      host: "opencode",
      expectSHA256: sha,
      stdin: try openCodePayload(tool: "read", paths: ["/tmp/pk-project/a.swift"])
    )

    #expect(output.isEmpty)
  }

  @Test
  func openCodeHostRejectsEmptyExpectSHA256() throws {
    let manifest = try writeReadOnlyManifest()

    let result = runHookCheckWithStatus(
      manifest: manifest,
      host: "opencode",
      expectSHA256: "",
      stdin: try openCodePayload(tool: "read")
    )

    #expect(result.status != 0)
    #expect(result.stderr.contains("--expect-sha256"))
    #expect(result.stdout.isEmpty)
  }

  @Test
  func openCodeHostProtectsOwnExecutable() throws {
    let manifest = try writeNetworkOnlyManifest()
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("pk-exe-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: root.appendingPathComponent("bin"), withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: root.appendingPathComponent("real"), withIntermediateDirectories: true)
    let plain = root.appendingPathComponent("bin/personakit").path
    let realTarget = root.appendingPathComponent("real/personakit").path

    func write(_ path: String, executable: String?) throws -> ClaudeCodeHookCheckDecision {
      try decideOpenCode(
        manifest: manifest,
        stdin: try openCodePayload(tool: "write", paths: [path], directory: root.path),
        environment: [:],
        executablePath: executable
      )
    }

    #expect(try write(plain, executable: plain).isDenied)
    #expect(try !write(plain, executable: nil).isDenied)

    // The executable is a symlink: both the link and its target are protected.
    try Data().write(to: URL(fileURLWithPath: realTarget))
    try FileManager.default.createSymbolicLink(atPath: plain, withDestinationPath: realTarget)
    #expect(try write(realTarget, executable: plain).isDenied)
    #expect(try write(plain, executable: plain).isDenied)
    #expect(try !write(realTarget, executable: nil).isDenied)
  }

  @Test
  func enforceInstallWritesArtifactsIdempotentlyAndOnlyUnderDotClaude() throws {
    let projectDir = FileManager.default.temporaryDirectory
      .appendingPathComponent("pk-project-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: projectDir, withIntermediateDirectories: true)

    func install() -> Int32 {
      PersonaKitCLI().run(arguments: [
        "personakit", "enforce", "install",
        "--root", readOnlyFixtureRootURL().path,
        "--no-global",
        "--session", "read-only-auditor_audit-pass",
        "--project-dir", projectDir.path,
        "--executable", "/usr/local/bin/personakit",
      ])
    }

    var status: Int32 = 0
    _ = captureStdout { status = install() }
    #expect(status == 0)

    let settingsURL = projectDir.appendingPathComponent(".claude/settings.json")
    let frozenURL = projectDir.appendingPathComponent(".claude/personakit/read-only-auditor_audit-pass.checks.json")
    #expect(FileManager.default.fileExists(atPath: settingsURL.path))
    #expect(FileManager.default.fileExists(atPath: frozenURL.path))

    // Re-install is idempotent: identical bytes, no duplicated hook entry.
    let firstSettings = try Data(contentsOf: settingsURL)
    _ = captureStdout { _ = install() }
    let secondSettings = try Data(contentsOf: settingsURL)
    #expect(firstSettings == secondSettings)

    // The installed frozen manifest denies edits through the real checker.
    #expect(runHookCheck(manifest: frozenURL, toolName: "Edit").contains("deny"))

    // PK wrote nothing into the project outside the explicit .claude install.
    let projectContents = try FileManager.default.contentsOfDirectory(atPath: projectDir.path)
    #expect(projectContents == [".claude"])
  }

  @Test
  func hookDecisionGateLetsOnlyTheFirstCallerWrite() {
    let gate = HookDecisionGate()

    #expect(gate.claim())
    #expect(!gate.claim())
  }

  @Test
  func watchdogFiresWhenTheCheckerHasNotDecided() {
    let fired = DispatchSemaphore(value: 0)

    HookCheckCommand.startWatchdog(after: .milliseconds(10), gate: HookDecisionGate()) { fired.signal() }

    #expect(fired.wait(timeout: .now() + 5) == .success)
  }

  @Test
  func watchdogStaysQuietOnceTheCheckerHasDecided() {
    let fired = DispatchSemaphore(value: 0)
    let gate = HookDecisionGate()
    #expect(gate.claim())

    HookCheckCommand.startWatchdog(after: .milliseconds(10), gate: gate) { fired.signal() }

    #expect(fired.wait(timeout: .now() + 0.5) == .timedOut)
  }

  @Test
  func missedDeadlineOutputDeniesTheCall() throws {
    let json = HookCheckCommand.claudeOutputJSON(for: HookCheckCommand.missedDeadlineDecision)
    let root = try #require(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
    let inner = try #require(root["hookSpecificOutput"] as? [String: Any])

    #expect(inner["permissionDecision"] as? String == "deny")
    let reason = try #require(inner["permissionDecisionReason"] as? String)
    #expect(reason.contains("could not reach a decision in time"))
    #expect(reason.contains("To fix it, the user can ask for the call again"))
    #expect(reason.hasSuffix(ClaudeCodeHookCheckEvaluator.noWorkaroundInstruction))
  }

  /// The mod's `DENY_MARKERS` (`Integrations/ClaudeCode/hooks/lib/drift.ts`): a deny reason without one is recorded
  /// as ordinary drift, not a PersonaKit block. Keep the two lists in step.
  private static let driftDenyMarkers = [
    "Blocked by PersonaKit contract:",
    "PersonaKit enforcement could not",
    "PersonaKit could not check this tool call",
    "PersonaKit contract needs approval:",
  ]

  @Test
  func everyFallbackAndFailClosedDenyReasonCarriesADriftMarker() throws {
    let manifest = try writeReadOnlyManifest()
    let missing = URL(fileURLWithPath: "/no/such/manifest.checks.json")
    let garbled = manifest.deletingLastPathComponent().appendingPathComponent("garbled.checks.json")
    try Data("not a manifest".utf8).write(to: garbled)
    let call = try openCodePayload(tool: "edit")

    func openCode(_ manifest: URL, sha: String, stdin: @escaping @Sendable () throws -> String) -> String? {
      let context = CLIContext(
        scopeRootResolver: ScopeRootResolver(),
        mcpServerRunner: MCPServerRunner(),
        interactiveIO: CLIInteractiveIO(isInteractive: { false }, readLine: { nil }, readStdinToEnd: stdin)
      )
      return CLIEnvironment.withContext(context) {
        HookCheckCommand.decideOpenCode(
          manifestPath: manifest.path,
          expectedSHA256: sha,
          environment: [:],
          executablePath: nil,
          passwdHome: { nil }
        ).reason
      }
    }

    let sha = try sha256Hex(of: manifest)
    // The hook command's shell fallback, for a checker that never ran: the text it echoes to stderr.
    let suffixReason = ClaudeCodeEnforcement.failClosedSuffix
      .components(separatedBy: "echo '").last?
      .components(separatedBy: "' >&2").first
    let reasons: [(label: String, reason: String?)] = [
      ("fallback", HookCheckCommand.fallbackDenyReason),
      ("Claude: hook-check failed", suffixReason),
      ("missed deadline", HookCheckCommand.missedDeadlineDecision.reason),
      ("Claude: missing manifest", decideClaude(manifest: missing, readStdin: { "{}" }).reason),
      (
        "Claude: unreadable call",
        decideClaude(manifest: manifest, readStdin: { throw CocoaError(.fileReadUnknown) }).reason
      ),
      ("Claude: unparseable call", decideClaude(manifest: manifest, readStdin: { "not json" }).reason),
      ("OpenCode: missing manifest", openCode(missing, sha: sha, stdin: { call })),
      ("OpenCode: changed manifest", openCode(manifest, sha: String(repeating: "0", count: 64), stdin: { call })),
      ("OpenCode: undecodable manifest", openCode(garbled, sha: try sha256Hex(of: garbled), stdin: { call })),
      ("OpenCode: unreadable call", openCode(manifest, sha: sha, stdin: { throw CocoaError(.fileReadUnknown) })),
      ("OpenCode: unparseable call", openCode(manifest, sha: sha, stdin: { "not json" })),
    ]

    for (label, reason) in reasons {
      let reason = try #require(reason, "\(label)")
      #expect(Self.driftDenyMarkers.contains { reason.hasPrefix($0) }, "\(label): \(reason)")
    }

    // A Claude Code deny without a reason of its own carries the fallback.
    let bare = ClaudeCodeHookCheckDecision(isDenied: true, reason: nil)
    #expect(HookCheckCommand.claudeOutputJSON(for: bare).contains(HookCheckCommand.fallbackDenyReason))
  }

  @Test
  func enforceInstallRefusesABareExecutableNameNotOnPath() throws {
    let projectDir = try freshProjectDir("pk-bareexe")
    let name = "personakit-missing-\(UUID().uuidString)"

    let result = runInstall(extra: ["--executable", name], projectDir: projectDir, dryRun: false)

    #expect(result.status != 0)
    #expect((result.stderr + result.stdout).contains("--executable \(name) is not an executable on PATH"))
    #expect(!FileManager.default.fileExists(atPath: projectDir.appendingPathComponent(".claude").path))
  }

  /// A temp directory holding an executable named `personakit`, for PATH lookups.
  private func binDirectoryWithPersonaKit() throws -> URL {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("pk-bin-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let binary = directory.appendingPathComponent("personakit")
    try "#!/bin/sh\n".write(to: binary, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: binary.path)
    return directory
  }

  @Test
  func executablePathResolvesABareNameOnPathToAnAbsolutePath() throws {
    let bin = try binDirectoryWithPersonaKit()
    defer { try? FileManager.default.removeItem(at: bin) }
    let empty = FileManager.default.temporaryDirectory.appendingPathComponent("pk-empty-\(UUID().uuidString)")
    // Empty and relative entries are skipped: they depend on the directory the hook runs in.
    let environment = ["PATH": "::.:relative:\(empty.path):\(bin.path)"]
    let expected = bin.appendingPathComponent("personakit").standardized.path

    #expect(
      try EnforceInstallCommand.resolveExecutablePath(
        override: "personakit",
        invokedAs: nil,
        environment: environment,
        ownExecutable: nil
      ) == expected
    )
    // Started as a bare `personakit`, the hook gets the binary the shell found, not the bare name.
    #expect(
      try EnforceInstallCommand.resolveExecutablePath(
        override: nil,
        invokedAs: "personakit",
        environment: environment,
        ownExecutable: "/own/personakit"
      ) == expected
    )
  }

  @Test
  func executablePathFallsBackToThisBinaryWhenItsNameIsNotOnPath() throws {
    #expect(
      try EnforceInstallCommand.resolveExecutablePath(
        override: nil,
        invokedAs: "personakit",
        environment: ["PATH": ""],
        ownExecutable: "/own/personakit"
      ) == "/own/personakit"
    )
    #expect(throws: (any Error).self) {
      try EnforceInstallCommand.resolveExecutablePath(
        override: nil,
        invokedAs: "personakit",
        environment: [:],
        ownExecutable: nil
      )
    }
  }

  @Test
  func executablePathMakesAPathLikeValueAbsolute() throws {
    let resolved = try EnforceInstallCommand.resolveExecutablePath(
      override: "bin/personakit",
      invokedAs: nil,
      environment: [:],
      ownExecutable: nil
    )

    #expect(resolved.hasPrefix("/"))
    #expect(resolved.hasSuffix("/bin/personakit"))
  }

  @Test
  func executablePathSkipsPathEntriesThatAreNotExecutableFiles() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("pk-skip-\(UUID().uuidString)")
    let dirEntry = root.appendingPathComponent("dir")
    let plainEntry = root.appendingPathComponent("plain")
    try FileManager.default.createDirectory(
      at: dirEntry.appendingPathComponent("personakit"),
      withIntermediateDirectories: true
    )
    try FileManager.default.createDirectory(at: plainEntry, withIntermediateDirectories: true)
    try "#!/bin/sh\n".write(to: plainEntry.appendingPathComponent("personakit"), atomically: true, encoding: .utf8)
    let bin = try binDirectoryWithPersonaKit()
    defer {
      try? FileManager.default.removeItem(at: root)
      try? FileManager.default.removeItem(at: bin)
    }

    // A directory named personakit and a file without the execute bit are passed over.
    #expect(
      try EnforceInstallCommand.resolveExecutablePath(
        override: "personakit",
        invokedAs: nil,
        environment: ["PATH": "\(dirEntry.path):\(plainEntry.path):\(bin.path)"],
        ownExecutable: nil
      ) == bin.appendingPathComponent("personakit").standardized.path
    )
  }

  @Test
  func enforceInstallWarnsWhenTheExecutableIsADirectory() throws {
    let projectDir = try freshProjectDir("pk-direxe")

    let result = runInstall(extra: ["--executable", projectDir.path], projectDir: projectDir)

    #expect(result.status == 0)
    #expect(result.stderr.contains("Warning: \(projectDir.path) is not an executable file"))
  }

  @Test
  func enforceInstallWarnsWhenTheExecutableIsMissing() throws {
    let projectDir = try freshProjectDir("pk-missingexe")
    let missing = "/nonexistent-\(UUID().uuidString)/personakit"

    let result = runInstall(extra: ["--executable", missing], projectDir: projectDir)

    #expect(result.status == 0)
    #expect(result.stderr.contains("Warning: \(missing) is not an executable file"))
  }

  @Test
  func enforceInstallDryRunWritesNothing() throws {
    let projectDir = FileManager.default.temporaryDirectory
      .appendingPathComponent("pk-dryrun-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: projectDir, withIntermediateDirectories: true)

    var status: Int32 = 0
    let output = captureStdout {
      status = PersonaKitCLI().run(arguments: [
        "personakit", "enforce", "install",
        "--root", readOnlyFixtureRootURL().path,
        "--no-global",
        "--session", "read-only-auditor_audit-pass",
        "--project-dir", projectDir.path,
        "--executable", "/usr/local/bin/personakit",
        "--dry-run",
      ])
    }

    #expect(status == 0)
    #expect(output.contains("Dry run"))
    #expect(output.contains("\"matcher\" : \".*\""))
    #expect(output.contains("\"timeout\" : 60"))
    #expect(!FileManager.default.fileExists(atPath: projectDir.appendingPathComponent(".claude").path))
  }

  /// Runs `enforce install` against the read-only fixture with extra arguments.
  private func runInstall(
    extra: [String],
    projectDir: URL,
    dryRun: Bool = true
  ) -> (status: Int32, stdout: String, stderr: String) {
    var status: Int32 = 0
    var stdout = ""
    let stderr = captureStderr {
      stdout = captureStdout {
        status = PersonaKitCLI().run(
          arguments: [
            "personakit", "enforce", "install",
            "--root", readOnlyFixtureRootURL().path,
            "--no-global",
            "--session", "read-only-auditor_audit-pass",
            "--project-dir", projectDir.path,
            "--executable", "/usr/local/bin/personakit",
          ] + (dryRun ? ["--dry-run"] : []) + extra
        )
      }
    }
    return (status, stdout, stderr)
  }

  private func freshProjectDir(_ prefix: String) throws -> URL {
    let projectDir = FileManager.default.temporaryDirectory
      .appendingPathComponent("\(prefix)-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: projectDir, withIntermediateDirectories: true)
    return projectDir
  }

  @Test
  func installDryRunRecordsCustomMCPServerName() throws {
    let projectDir = try freshProjectDir("pk-mcpname")
    let result = runInstall(extra: ["--mcp-server", "pk-local"], projectDir: projectDir)

    #expect(result.status == 0)
    #expect(result.stdout.contains("\"mcpServerName\" : \"pk-local\""))
  }

  @Test
  func installDryRunOmitsServerNameByDefault() throws {
    let projectDir = try freshProjectDir("pk-mcpdefault")
    let result = runInstall(extra: [], projectDir: projectDir)

    #expect(result.status == 0)
    #expect(!result.stdout.contains("mcpServerName"))
  }

  @Test(arguments: ["", "a__b", "pk local"])
  func installRejectsInvalidServerNames(name: String) throws {
    let projectDir = try freshProjectDir("pk-mcpbad")

    let result = runInstall(extra: ["--mcp-server", name], projectDir: projectDir, dryRun: false)

    #expect(result.status != 0)
    #expect((result.stderr + result.stdout).contains("--mcp-server must be non-empty"))
    #expect((result.stderr + result.stdout).contains("as it appears in Claude Code tool names"))
    #expect(!FileManager.default.fileExists(atPath: projectDir.appendingPathComponent(".claude").path))
  }

  // MARK: - enforce install --host opencode

  private static let openCodeSessionId = "read-only-auditor_audit-pass"

  /// Runs `enforce install --host opencode` with `HOME` pointed at `home` and `XDG_CONFIG_HOME` unset,
  /// so the plugin-listed check never reads the real user's OpenCode config. `XDG_CACHE_HOME` is `cacheHome`, or
  /// one beside `home` holding the plugin at this CLI's version.
  private func runOpenCodeInstall(
    projectDir: URL,
    home: URL,
    cacheHome: URL? = nil,
    dryRun: Bool = false,
    session: String = CLIEnforceTests.openCodeSessionId,
    extra: [String] = []
  ) -> (status: Int32, stdout: String, stderr: String) {
    withEnvironment(Self.isolatedOpenCodeEnvironment(home: home, cacheHome: cacheHome)) {
      var status: Int32 = 0
      var stdout = ""
      let stderr = captureStderr {
        stdout = captureStdout {
          status = PersonaKitCLI().run(
            arguments: [
              "personakit", "enforce", "install",
              "--host", "opencode",
              "--root", readOnlyFixtureRootURL().path,
              "--no-global",
              "--session=\(session)",
              "--project-dir", projectDir.path,
            ] + (dryRun ? ["--dry-run"] : []) + extra
          )
        }
      }
      return (status, stdout, stderr)
    }
  }

  /// `HOME` pointed at `home`, `XDG_CACHE_HOME` at `cacheHome` (by default a cache home beside `home` holding the
  /// plugin at this CLI's version), and every other variable the plugin checks read unset.
  private static func isolatedOpenCodeEnvironment(home: URL, cacheHome: URL? = nil) -> [String: String?] {
    [
      "HOME": home.path,
      "XDG_CACHE_HOME": (cacheHome ?? pluginCacheHome(beside: home)).path,
      "XDG_CONFIG_HOME": nil,
      "OPENCODE_CONFIG": nil,
      "OPENCODE_CONFIG_DIR": nil,
    ]
  }

  /// A cache home beside `home`: `<home>-cache`, holding the plugin `make opencode-install` installs with
  /// `packageJSON` as its `package.json`, or no plugin when `packageJSON` is nil.
  private static func pluginCacheHome(
    beside home: URL,
    packageJSON: String? = "{\"name\": \"opencode-personakit\", \"version\": \"\(PersonaKitVersion.current)\"}"
  ) -> URL {
    let cacheHome = URL(fileURLWithPath: home.path + "-cache")
    try? FileManager.default.createDirectory(at: cacheHome, withIntermediateDirectories: true)
    if let packageJSON {
      let plugin = cacheHome.appendingPathComponent("opencode/personakit/plugin")
      try? FileManager.default.createDirectory(at: plugin, withIntermediateDirectories: true)
      try? Data(packageJSON.utf8).write(to: plugin.appendingPathComponent("package.json"))
    }
    return cacheHome
  }

  /// The spec `make opencode-install` writes for the default cache home beside `home`.
  private static func pluginSpec(home: URL) -> String {
    "file://\(home.path)-cache/opencode/personakit/plugin"
  }

  /// Sets or unsets process environment variables for `body`, then restores them.
  private func withEnvironment<T>(_ values: [String: String?], _ body: () -> T) -> T {
    var saved: [String: String?] = [:]
    for (key, value) in values {
      saved[key] = ProcessInfo.processInfo.environment[key]
      if let value {
        setenv(key, value, 1)
      } else {
        unsetenv(key)
      }
    }
    defer {
      for (key, value) in saved {
        if let value {
          setenv(key, value, 1)
        } else {
          unsetenv(key)
        }
      }
    }
    return body()
  }

  /// Every file and directory under `root`, as sorted relative paths.
  private func tree(_ root: URL) -> [String] {
    let enumerator = FileManager.default.enumerator(atPath: root.path)
    return ((enumerator?.allObjects as? [String]) ?? []).sorted()
  }

  @Test
  func openCodeInstallWritesOnlyTheManifest() throws {
    let projectDir = try freshProjectDir("pk-oc-install")
    let home = try freshProjectDir("pk-oc-home")

    let result = runOpenCodeInstall(projectDir: projectDir, home: home)

    #expect(result.status == 0)
    #expect(
      tree(projectDir) == [
        ".opencode",
        ".opencode/personakit",
        ".opencode/personakit/\(Self.openCodeSessionId).checks.json",
      ]
    )
    #expect(tree(home).isEmpty)
  }

  @Test
  func openCodeInstallManifestMatchesClaudeFrozenManifestBytes() throws {
    let claudeDir = try freshProjectDir("pk-oc-claude")
    let openCodeDir = try freshProjectDir("pk-oc-opencode")
    let home = try freshProjectDir("pk-oc-home")

    let claude = runInstall(extra: [], projectDir: claudeDir, dryRun: false)
    let openCode = runOpenCodeInstall(projectDir: openCodeDir, home: home)

    #expect(claude.status == 0)
    #expect(openCode.status == 0)
    let name = "\(Self.openCodeSessionId).checks.json"
    let claudeBytes = try Data(contentsOf: claudeDir.appendingPathComponent(".claude/personakit/\(name)"))
    let openCodeBytes = try Data(contentsOf: openCodeDir.appendingPathComponent(".opencode/personakit/\(name)"))
    #expect(claudeBytes == openCodeBytes)
  }

  @Test
  func openCodeInstallReplacesOtherManifests() throws {
    let projectDir = try freshProjectDir("pk-oc-replace")
    let home = try freshProjectDir("pk-oc-home")
    let directory = projectDir.appendingPathComponent(".opencode/personakit")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try Data("{}".utf8).write(to: directory.appendingPathComponent("old.checks.json"))
    try Data("notes".utf8).write(to: directory.appendingPathComponent("notes.txt"))

    let result = runOpenCodeInstall(projectDir: projectDir, home: home)

    #expect(result.status == 0)
    #expect(!FileManager.default.fileExists(atPath: directory.appendingPathComponent("old.checks.json").path))
    #expect(FileManager.default.fileExists(atPath: directory.appendingPathComponent("notes.txt").path))
    #expect(
      FileManager.default.fileExists(
        atPath: directory.appendingPathComponent("\(Self.openCodeSessionId).checks.json").path
      )
    )
  }

  @Test
  func claudeInstallRefusesSettingsItCannotRead() throws {
    let projectDir = try freshProjectDir("pk-claude-unreadable")
    let settingsURL = projectDir.appendingPathComponent(".claude/settings.json")
    try FileManager.default.createDirectory(
      at: settingsURL.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try Data(#"{"theme":"dark"}"#.utf8).write(to: settingsURL)
    try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: settingsURL.path)
    defer { try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: settingsURL.path) }

    for dryRun in [false, true] {
      let result = runInstall(extra: [], projectDir: projectDir, dryRun: dryRun)

      #expect(result.status != 0)
      #expect((result.stderr + result.stdout).contains("could not read \(settingsURL.path)"))
    }

    try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: settingsURL.path)
    #expect(try String(contentsOf: settingsURL, encoding: .utf8) == #"{"theme":"dark"}"#)
    #expect(tree(projectDir.appendingPathComponent(".claude")) == ["settings.json"])
  }

  @Test(arguments: [".claude", ".claude/personakit", ".claude/settings.json"])
  func claudeInstallRefusesASymlinkedEnforcementPath(linked: String) throws {
    let projectDir = try freshProjectDir("pk-claude-symlink")
    let elsewhere = try freshProjectDir("pk-claude-elsewhere")
    let victim = elsewhere.appendingPathComponent("settings.json")
    try Data(#"{"theme":"dark"}"#.utf8).write(to: victim)
    let link = projectDir.appendingPathComponent(linked)
    try FileManager.default.createDirectory(
      at: link.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try FileManager.default.createSymbolicLink(
      at: link,
      withDestinationURL: linked.hasSuffix(".json") ? victim : elsewhere
    )

    for dryRun in [false, true] {
      let result = runInstall(extra: [], projectDir: projectDir, dryRun: dryRun)

      #expect(result.status != 0)
      #expect((result.stderr + result.stdout).contains("\(link.path) is a symbolic link"))
      // The target's settings are never read into the output.
      #expect(!result.stdout.contains("theme"))
    }
    #expect(
      (try? FileManager.default.attributesOfItem(atPath: link.path))?[.type] as? FileAttributeType
        == .typeSymbolicLink
    )
    // Nothing was written through the link, and no settings landed in the project beside it.
    #expect(tree(elsewhere) == ["settings.json"])
    #expect(try String(contentsOf: victim, encoding: .utf8) == #"{"theme":"dark"}"#)
    if linked == ".claude/personakit" {
      #expect(!FileManager.default.fileExists(atPath: projectDir.appendingPathComponent(".claude/settings.json").path))
    }
  }

  @Test
  func openCodeInstallRefusesASymlinkedManifestDirectory() throws {
    let projectDir = try freshProjectDir("pk-oc-symlink-leaf")
    let home = try freshProjectDir("pk-oc-home")
    let elsewhere = try freshProjectDir("pk-oc-elsewhere")
    let victim = elsewhere.appendingPathComponent("victim.checks.json")
    try Data("{}".utf8).write(to: victim)
    let opencodeDir = projectDir.appendingPathComponent(".opencode")
    try FileManager.default.createDirectory(at: opencodeDir, withIntermediateDirectories: true)
    try FileManager.default.createSymbolicLink(
      at: opencodeDir.appendingPathComponent("personakit"),
      withDestinationURL: elsewhere
    )

    for dryRun in [false, true] {
      let result = runOpenCodeInstall(projectDir: projectDir, home: home, dryRun: dryRun)

      #expect(result.status != 0)
      #expect((result.stderr + result.stdout).contains(".opencode/personakit"))
      #expect((result.stderr + result.stdout).contains("symbolic link"))
    }
    #expect(tree(elsewhere) == ["victim.checks.json"])
    #expect(try String(contentsOf: victim, encoding: .utf8) == "{}")
  }

  @Test
  func openCodeInstallRefusesASymlinkedOpencodeDirectory() throws {
    let projectDir = try freshProjectDir("pk-oc-symlink-parent")
    let home = try freshProjectDir("pk-oc-home")
    let elsewhere = try freshProjectDir("pk-oc-elsewhere")
    let personakit = elsewhere.appendingPathComponent("personakit")
    try FileManager.default.createDirectory(at: personakit, withIntermediateDirectories: true)
    let victim = personakit.appendingPathComponent("victim.checks.json")
    try Data("{}".utf8).write(to: victim)
    try FileManager.default.createSymbolicLink(
      at: projectDir.appendingPathComponent(".opencode"),
      withDestinationURL: elsewhere
    )

    for dryRun in [false, true] {
      let result = runOpenCodeInstall(projectDir: projectDir, home: home, dryRun: dryRun)

      #expect(result.status != 0)
      #expect((result.stderr + result.stdout).contains("symbolic link"))
    }
    #expect(tree(elsewhere) == ["personakit", "personakit/victim.checks.json"])
    #expect(try String(contentsOf: victim, encoding: .utf8) == "{}")
  }

  @Test
  func openCodeInstallRefusesNonRegularManifestEntries() throws {
    let projectDir = try freshProjectDir("pk-oc-nonregular")
    let home = try freshProjectDir("pk-oc-home")
    let directory = projectDir.appendingPathComponent(".opencode/personakit")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let target = projectDir.appendingPathComponent("target.txt")
    try Data("t".utf8).write(to: target)
    try FileManager.default.createSymbolicLink(
      at: directory.appendingPathComponent("link.checks.json"),
      withDestinationURL: target
    )
    try FileManager.default.createDirectory(
      at: directory.appendingPathComponent("dir.checks.json"),
      withIntermediateDirectories: true
    )
    try Data("{}".utf8).write(to: directory.appendingPathComponent("old.checks.json"))
    let before = tree(projectDir)

    for dryRun in [false, true] {
      let result = runOpenCodeInstall(projectDir: projectDir, home: home, dryRun: dryRun)

      #expect(result.status != 0)
      #expect((result.stderr + result.stdout).contains("link.checks.json"))
      #expect((result.stderr + result.stdout).contains("dir.checks.json"))
      #expect(!(result.stderr + result.stdout).contains("old.checks.json"))
    }
    #expect(tree(projectDir) == before)
  }

  @Test
  func openCodeInstallKeepsExactlyTheNewManifestWhenAnOldNameDiffersOnlyByCase() throws {
    let projectDir = try freshProjectDir("pk-oc-case")
    let home = try freshProjectDir("pk-oc-home")
    let directory = projectDir.appendingPathComponent(".opencode/personakit")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let variant = Self.openCodeSessionId.uppercased() + ".checks.json"
    try Data("{}".utf8).write(to: directory.appendingPathComponent(variant))

    let dry = runOpenCodeInstall(projectDir: projectDir, home: home, dryRun: true)
    #expect(dry.status == 0)
    #expect(!dry.stdout.contains("Would remove"))

    let result = runOpenCodeInstall(projectDir: projectDir, home: home)

    #expect(result.status == 0)
    // On disk the name is exactly the session id, whatever spelling the old entry had.
    #expect(tree(directory) == ["\(Self.openCodeSessionId).checks.json"])
    // The surviving file holds the new contract, not the stub.
    let text = try String(
      contentsOf: directory.appendingPathComponent("\(Self.openCodeSessionId).checks.json"),
      encoding: .utf8
    )
    #expect(text.contains("\"sessionId\""))
    #expect(result.stdout.contains("\(directory.path)/\(Self.openCodeSessionId).checks.json"))
  }

  @Test
  func openCodeInstallRemovesAnEntryThatOnlyLooksLikeTheNewName() throws {
    let projectDir = try freshProjectDir("pk-oc-dotless")
    let home = try freshProjectDir("pk-oc-home")
    let directory = projectDir.appendingPathComponent(".opencode/personakit")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    // Dotless i is a different file name from `i` on APFS, so this is another manifest.
    let lookalike = Self.openCodeSessionId.replacingOccurrences(of: "auditor", with: "aud\u{131}tor") + ".checks.json"
    try Data("{}".utf8).write(to: directory.appendingPathComponent(lookalike))
    try #require(tree(directory) == [lookalike])

    let dry = runOpenCodeInstall(projectDir: projectDir, home: home, dryRun: true)
    #expect(dry.status == 0)
    #expect(dry.stdout.contains("Would remove"))
    #expect(dry.stdout.contains(lookalike))
    #expect(tree(directory) == [lookalike])

    let result = runOpenCodeInstall(projectDir: projectDir, home: home)

    #expect(result.status == 0)
    #expect(tree(directory) == ["\(Self.openCodeSessionId).checks.json"])
  }

  @Test
  func openCodeInstallWarnsWhenPluginNotListed() throws {
    let projectDir = try freshProjectDir("pk-oc-warn")
    let home = try freshProjectDir("pk-oc-home")
    // Configs exist but none lists the plugin.
    try Data("{\"plugin\": [\"other\"]}".utf8).write(to: projectDir.appendingPathComponent("opencode.json"))

    let result = runOpenCodeInstall(projectDir: projectDir, home: home)

    #expect(result.status == 0)
    #expect(result.stderr.contains("does not list the PersonaKit plugin"))
    #expect(result.stderr.contains("make opencode-install"))
    // The check reads config; it never writes it.
    #expect(
      try String(contentsOf: projectDir.appendingPathComponent("opencode.json"), encoding: .utf8)
        == "{\"plugin\": [\"other\"]}"
    )
  }

  @Test(arguments: [
    "opencode.json", "opencode.jsonc", ".opencode/opencode.json", ".opencode/opencode.jsonc",
  ])
  func openCodeInstallWarnsWhenOnlyProjectConfigListsPlugin(relativePath: String) throws {
    let projectDir = try freshProjectDir("pk-oc-listed")
    let home = try freshProjectDir("pk-oc-home")
    let config = projectDir.appendingPathComponent(relativePath)
    try writePluginListing(in: config.deletingLastPathComponent(), name: config.lastPathComponent, home: home)

    let result = runOpenCodeInstall(projectDir: projectDir, home: home)

    #expect(result.status == 0)
    #expect(result.stderr.contains("does not list the PersonaKit plugin"))
  }

  @Test(arguments: ["config.json", "opencode.json", "opencode.jsonc"])
  func openCodeInstallDoesNotWarnWhenGlobalConfigListsPlugin(name: String) throws {
    let projectDir = try freshProjectDir("pk-oc-global")
    let home = try freshProjectDir("pk-oc-home")
    try writePluginListing(in: home.appendingPathComponent(".config/opencode"), name: name, home: home)

    let result = runOpenCodeInstall(projectDir: projectDir, home: home)

    #expect(result.status == 0)
    #expect(!result.stderr.contains("does not list the PersonaKit plugin"))
  }

  @Test
  func openCodeInstallRefusesWhenThePluginIsMissing() throws {
    let home = try freshProjectDir("pk-oc-home")
    let noDirectory = Self.pluginCacheHome(beside: home, packageJSON: nil)
    let noPackage = try freshProjectDir("pk-oc-cache-empty")
    try FileManager.default.createDirectory(
      at: noPackage.appendingPathComponent("opencode/personakit/plugin"),
      withIntermediateDirectories: true
    )

    for cacheHome in [noDirectory, noPackage] {
      for dryRun in [false, true] {
        let projectDir = try freshProjectDir("pk-oc-missing")
        let result = runOpenCodeInstall(projectDir: projectDir, home: home, cacheHome: cacheHome, dryRun: dryRun)

        #expect(result.status != 0)
        #expect(
          result.stderr.contains("the OpenCode plugin is not installed at \(cacheHome.path)/opencode/personakit/plugin")
        )
        #expect(
          result.stderr.contains(
            "Run `make opencode-install` from a PersonaKit checkout of tag v\(PersonaKitVersion.current)"
          )
        )
        #expect(tree(projectDir).isEmpty)
      }
    }
  }

  @Test
  func openCodeInstallRefusesWhenThePluginVersionDiffers() throws {
    let home = try freshProjectDir("pk-oc-home")
    let cacheHome = Self.pluginCacheHome(beside: home, packageJSON: "{\"version\": \"0.0.1\"}")

    for dryRun in [false, true] {
      let projectDir = try freshProjectDir("pk-oc-mismatch")
      let result = runOpenCodeInstall(projectDir: projectDir, home: home, cacheHome: cacheHome, dryRun: dryRun)

      #expect(result.status != 0)
      #expect(result.stderr.contains("(plugin 0.0.1, CLI \(PersonaKitVersion.current))"))
      #expect(
        result.stderr.contains(
          "Run `make opencode-install` from a PersonaKit checkout of tag v\(PersonaKitVersion.current)"
        )
      )
      #expect(tree(projectDir).isEmpty)
    }
  }

  @Test(arguments: ["{ not json", "[]", "{}", "{\"version\": 2}"])
  func openCodeInstallRefusesWhenThePluginVersionIsUnreadable(packageJSON: String) throws {
    let home = try freshProjectDir("pk-oc-home")
    let projectDir = try freshProjectDir("pk-oc-unreadable")
    let cacheHome = Self.pluginCacheHome(beside: home, packageJSON: packageJSON)

    let result = runOpenCodeInstall(projectDir: projectDir, home: home, cacheHome: cacheHome)

    #expect(result.status != 0)
    #expect(result.stderr.contains("has no readable \"version\""))
    #expect(tree(projectDir).isEmpty)
  }

  @Test
  func openCodeInstallSucceedsWhenThePluginVersionMatches() throws {
    let home = try freshProjectDir("pk-oc-home")
    let projectDir = try freshProjectDir("pk-oc-match")

    let result = runOpenCodeInstall(projectDir: projectDir, home: home, cacheHome: Self.pluginCacheHome(beside: home))

    #expect(result.status == 0)
    #expect(!result.stderr.contains("Refusing"))
    #expect(tree(projectDir).contains(".opencode/personakit/\(Self.openCodeSessionId).checks.json"))
  }

  @Test
  func openCodeInstallDryRunWritesNothing() throws {
    let projectDir = try freshProjectDir("pk-oc-dry")
    let home = try freshProjectDir("pk-oc-home")

    let result = runOpenCodeInstall(projectDir: projectDir, home: home, dryRun: true)

    #expect(result.status == 0)
    #expect(result.stdout.contains("Dry run"))
    #expect(result.stdout.contains(".opencode/personakit/\(Self.openCodeSessionId).checks.json"))
    #expect(!result.stdout.contains("\"matcher\""))
    #expect(tree(projectDir).isEmpty)
    #expect(tree(home).isEmpty)
  }

  @Test
  func openCodeInstallDryRunKeepsExistingManifests() throws {
    let projectDir = try freshProjectDir("pk-oc-dry-keep")
    let home = try freshProjectDir("pk-oc-home")
    let directory = projectDir.appendingPathComponent(".opencode/personakit")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try Data("{}".utf8).write(to: directory.appendingPathComponent("old.checks.json"))

    let result = runOpenCodeInstall(projectDir: projectDir, home: home, dryRun: true)

    #expect(result.status == 0)
    #expect(result.stdout.contains("old.checks.json"))
    #expect(tree(projectDir) == [".opencode", ".opencode/personakit", ".opencode/personakit/old.checks.json"])
  }

  @Test
  func openCodeInstallPrintsRestartNote() throws {
    let projectDir = try freshProjectDir("pk-oc-restart")
    let home = try freshProjectDir("pk-oc-home")

    let result = runOpenCodeInstall(projectDir: projectDir, home: home)

    #expect(result.status == 0)
    #expect(result.stdout.contains("Restart OpenCode"))
  }

  @Test
  func openCodeInstallOutputIsDeterministic() throws {
    let home = try freshProjectDir("pk-oc-home")
    let projectDir = try freshProjectDir("pk-oc-det")

    let one = runOpenCodeInstall(projectDir: projectDir, home: home, dryRun: true)
    let two = runOpenCodeInstall(projectDir: projectDir, home: home, dryRun: true)
    #expect(one.stdout == two.stdout)
    #expect(one.stderr == two.stderr)
  }

  @Test(arguments: ["a/b", "../x", ".hidden", "a b", "a..b/c", "a\n", "a\u{1b}[2Jb", "\u{e9}"])
  func openCodeInstallRejectsInvalidSessionIds(session: String) throws {
    let projectDir = try freshProjectDir("pk-oc-badid")
    let home = try freshProjectDir("pk-oc-home")

    let result = runOpenCodeInstall(projectDir: projectDir, home: home, session: session)

    #expect(result.status != 0)
    #expect((result.stderr + result.stdout).contains("--session must match"))
    #expect(tree(projectDir).isEmpty)
  }

  /// The workspace id rule allows a leading `_` or `-`; validation passes and only the session lookup fails.
  @Test(arguments: ["_wip", "-lead"])
  func openCodeInstallAcceptsWorkspaceSessionIds(session: String) throws {
    let projectDir = try freshProjectDir("pk-oc-wsid")
    let home = try freshProjectDir("pk-oc-home")

    let result = runOpenCodeInstall(projectDir: projectDir, home: home, session: session)

    #expect(!(result.stderr + result.stdout).contains("--session must match"))
    #expect((result.stderr + result.stdout).contains(session))
  }

  @Test(arguments: ["", "a b", "a/b", "a_\u{e9}"])
  func openCodeInstallRejectsInvalidServerNames(name: String) throws {
    let projectDir = try freshProjectDir("pk-oc-badserver")
    let home = try freshProjectDir("pk-oc-home")

    let result = runOpenCodeInstall(projectDir: projectDir, home: home, extra: ["--mcp-server", name])

    #expect(result.status != 0)
    #expect((result.stderr + result.stdout).contains("--mcp-server must"))
    #expect(tree(projectDir).isEmpty)
  }

  @Test
  func openCodeInstallAcceptsDotsAndDoubleUnderscoresInServerNames() throws {
    let projectDir = try freshProjectDir("pk-oc-server")
    let home = try freshProjectDir("pk-oc-home")

    let result = runOpenCodeInstall(
      projectDir: projectDir,
      home: home,
      dryRun: true,
      extra: ["--mcp-server", "pk.local__2"]
    )

    #expect(result.status == 0)
    #expect(result.stdout.contains("\"mcpServerName\" : \"pk.local__2\""))
  }

  @Test
  func claudeInstallWarnsThatAllowedCommandsReachWhatTheContractForbids() throws {
    let root = try fixtureRoot(forbidding: ["edit-files", "network-access"])
    let projectDir = try freshProjectDir("pk-claude-shell")

    let result = runInstall(extra: ["--root", root.path], projectDir: projectDir)

    #expect(result.status == 0)
    #expect(
      result.stderr.contains(
        "does not forbid run-commands, so Claude Code blocks only the dedicated tools for edit-files, "
          + "network-access; a shell command can still do them. Forbid run-commands too to enforce them."
      )
    )
  }

  @Test
  func claudeInstallDoesNotWarnWhenCommandsAreForbidden() throws {
    let projectDir = try freshProjectDir("pk-claude-noshell")

    let result = runInstall(extra: [], projectDir: projectDir)

    #expect(result.status == 0)
    #expect(!result.stderr.contains("a shell command can still do them"))
  }

  @Test
  func openCodeInstallWarnsThatAllowedCommandsReachWhatTheContractForbids() throws {
    let root = try fixtureRoot(forbidding: ["edit-files"])
    let projectDir = try freshProjectDir("pk-oc-shell")
    let home = try freshProjectDir("pk-oc-shell-home")

    let result = runOpenCodeInstall(root: root, projectDir: projectDir, home: home)

    #expect(result.status == 0)
    #expect(result.stderr.contains("so OpenCode blocks only the dedicated tools for edit-files; a shell command"))
  }

  @Test
  func openCodeInstallDoesNotWarnWhenCommandsAreForbidden() throws {
    let root = try fixtureRoot(forbidding: ["edit-files", "run-commands"])
    let projectDir = try freshProjectDir("pk-oc-noshell")
    let home = try freshProjectDir("pk-oc-noshell-home")

    let result = runOpenCodeInstall(root: root, projectDir: projectDir, home: home)

    #expect(result.status == 0)
    #expect(!result.stderr.contains("a shell command can still do them"))
  }

  @Test
  func claudeInstallStillRejectsServerNamesOpenCodeAccepts() throws {
    let projectDir = try freshProjectDir("pk-claude-badserver")

    let result = runInstall(extra: ["--mcp-server", "pk.local"], projectDir: projectDir, dryRun: false)

    #expect(result.status != 0)
    #expect((result.stderr + result.stdout).contains("--mcp-server must be non-empty"))
  }

  /// A copy of the read-only fixture whose persona forbids exactly `capabilities`.
  private func fixtureRoot(forbidding capabilities: [String]) throws -> URL {
    let container = FileManager.default.temporaryDirectory
      .appendingPathComponent("pk-oc-fixture-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: container, withIntermediateDirectories: true)
    let rootURL = container.appendingPathComponent("root")
    try FileManager.default.copyItem(at: readOnlyFixtureRootURL(), to: rootURL)
    let personaFiles = try FileManager.default.subpathsOfDirectory(atPath: rootURL.path)
      .filter { $0.hasSuffix(".persona.json") }
    for relative in personaFiles {
      let url = rootURL.appendingPathComponent(relative)
      var object = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
      object["forbiddenCapabilities"] = capabilities
      try JSONSerialization.data(withJSONObject: object).write(to: url)
    }
    return rootURL
  }

  @Test(arguments: [false, true])
  func claudeInstallSkipSaysWhetherAPriorHookRemainsInForce(hasPriorHook: Bool) throws {
    let root = try fixtureRoot(forbidding: ["autonomous-loop"])
    let projectDir = try freshProjectDir("pk-claude-nothing")
    let claudeDir = projectDir.appendingPathComponent(".claude")
    if hasPriorHook {
      try FileManager.default.createDirectory(at: claudeDir, withIntermediateDirectories: true)
      let settings =
        #"{"hooks":{"PreToolUse":[{"matcher":".*","hooks":[{"type":"command","#
        + #""command":"personakit hook-check --manifest /p/.claude/personakit/old.checks.json"}]}]}}"#
      try Data(settings.utf8).write(to: claudeDir.appendingPathComponent("settings.json"))
    }
    let before = snapshot(projectDir)

    var status: Int32 = 0
    var stdout = ""
    let stderr = captureStderr {
      stdout = captureStdout {
        status = PersonaKitCLI().run(arguments: [
          "personakit", "enforce", "install", "--root", root.path, "--no-global",
          "--session", "read-only-auditor_audit-pass", "--project-dir", projectDir.path,
          "--executable", "/usr/local/bin/personakit",
        ])
      }
    }

    #expect(status == 0)
    #expect(stdout.isEmpty)
    #expect(stderr.contains("Nothing to install for session read-only-auditor_audit-pass"))
    #expect(stderr.contains("forbids autonomous-loop, but no Claude Code tool maps to it"))
    #expect(!stderr.contains("class-1"))
    #expect(stderr.contains("still in force") == hasPriorHook)
    #expect(stderr.contains("Run `personakit enforce uninstall --project-dir ") == hasPriorHook)
    #expect(snapshot(projectDir) == before)
  }

  private func runOpenCodeInstall(
    root: URL,
    projectDir: URL,
    home: URL
  ) -> (status: Int32, stdout: String, stderr: String) {
    withEnvironment(Self.isolatedOpenCodeEnvironment(home: home)) {
      var status: Int32 = 0
      var stdout = ""
      let stderr = captureStderr {
        stdout = captureStdout {
          status = PersonaKitCLI().run(arguments: [
            "personakit", "enforce", "install", "--host", "opencode",
            "--root", root.path, "--no-global",
            "--session=\(Self.openCodeSessionId)",
            "--project-dir", projectDir.path,
          ])
        }
      }
      return (status, stdout, stderr)
    }
  }

  @Test(arguments: [[String](), ["autonomous-loop"]])
  func openCodeInstallSkipsContractOpenCodeCannotDeny(capabilities: [String]) throws {
    let root = try fixtureRoot(forbidding: capabilities)
    let projectDir = try freshProjectDir("pk-oc-nothing")
    let home = try freshProjectDir("pk-oc-home")

    let result = runOpenCodeInstall(root: root, projectDir: projectDir, home: home)

    #expect(result.status == 0)
    #expect(result.stderr.contains("Nothing to install for session"))
    #expect(result.stderr.contains("the capabilities OpenCode enforcement blocks"))
    #expect(!result.stderr.contains("still in force"))
    #expect(result.stdout.isEmpty)
    #expect(tree(projectDir).isEmpty)
    if !capabilities.isEmpty {
      #expect(result.stderr.contains("forbids autonomous-loop, but no OpenCode tool maps to it"))
    }
  }

  @Test
  func openCodeInstallSkipSaysAnExistingManifestRemainsInForce() throws {
    let root = try fixtureRoot(forbidding: ["autonomous-loop"])
    let projectDir = try freshProjectDir("pk-oc-remains")
    let home = try freshProjectDir("pk-oc-home")
    let directory = projectDir.appendingPathComponent(".opencode/personakit")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try Data("{}".utf8).write(to: directory.appendingPathComponent("prior.checks.json"))

    let result = runOpenCodeInstall(root: root, projectDir: projectDir, home: home)

    #expect(result.status == 0)
    #expect(result.stderr.contains("prior.checks.json"))
    #expect(result.stderr.contains("still in force"))
    #expect(result.stderr.contains("personakit enforce uninstall --host opencode"))
    #expect(tree(projectDir) == [".opencode", ".opencode/personakit", ".opencode/personakit/prior.checks.json"])
  }

  @Test
  func openCodeInstallNotesDegradationForAMixedContract() throws {
    let root = try fixtureRoot(forbidding: ["network-access", "autonomous-loop"])
    let projectDir = try freshProjectDir("pk-oc-mixed")
    let home = try freshProjectDir("pk-oc-home")

    let result = runOpenCodeInstall(root: root, projectDir: projectDir, home: home)

    #expect(result.status == 0)
    #expect(result.stdout.contains("Installed OpenCode enforcement"))
    #expect(result.stderr.contains("forbids autonomous-loop, but no OpenCode tool maps to it"))
    #expect(!result.stderr.contains("forbids network-access"))
  }

  @Test
  func openCodeInstallRejectsExecutableOption() throws {
    let projectDir = try freshProjectDir("pk-oc-exe")
    let home = try freshProjectDir("pk-oc-home")

    let result = runOpenCodeInstall(
      projectDir: projectDir,
      home: home,
      extra: ["--executable", "/usr/local/bin/personakit"]
    )

    #expect(result.status != 0)
    #expect((result.stderr + result.stdout).contains("--executable"))
    #expect(tree(projectDir).isEmpty)
  }

  @Test
  func openCodeInstallWarnsWhenNoConfigExistsAnywhere() throws {
    let projectDir = try freshProjectDir("pk-oc-noconfig")
    let home = try freshProjectDir("pk-oc-home")

    let result = runOpenCodeInstall(projectDir: projectDir, home: home)

    #expect(result.status == 0)
    #expect(result.stderr.contains("does not list the PersonaKit plugin"))
    #expect(tree(home).isEmpty)
  }

  /// Writes an OpenCode config at `directory/name` listing `spec`, by default the one `make opencode-install`
  /// writes for the cache home beside `home`.
  private func writePluginListing(in directory: URL, name: String = "opencode.json", home: URL) throws {
    try writePluginListing(in: directory, name: name, body: "{\"plugin\": [\"\(Self.pluginSpec(home: home))\"]}")
  }

  private func writePluginListing(in directory: URL, name: String = "opencode.json", body: String) throws {
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try Data(body.utf8).write(to: directory.appendingPathComponent(name))
  }

  private func listsPlugin(_ environment: [String: String]) -> Bool {
    EnforceInstallCommand.openCodeConfigListsPlugin(environment: environment, passwdHome: { nil })
  }

  @Test
  func openCodeConfigListingHonorsXDGConfigHome() throws {
    let home = try freshProjectDir("pk-oc-home")
    let xdg = try freshProjectDir("pk-oc-xdg-home")
    try writePluginListing(in: xdg.appendingPathComponent("opencode"), home: home)
    // A listing under $HOME/.config is ignored once XDG_CONFIG_HOME is set.
    try writePluginListing(in: home.appendingPathComponent(".config/opencode"), home: home)
    let emptyXDG = try freshProjectDir("pk-oc-xdg-empty")
    let cache = ["XDG_CACHE_HOME": home.path + "-cache"]

    #expect(listsPlugin(cache.merging(["HOME": home.path, "XDG_CONFIG_HOME": xdg.path]) { $1 }))
    #expect(!listsPlugin(cache.merging(["HOME": home.path, "XDG_CONFIG_HOME": emptyXDG.path]) { $1 }))
    #expect(listsPlugin(cache.merging(["HOME": home.path]) { $1 }))
    #expect(listsPlugin(cache.merging(["HOME": home.path, "XDG_CONFIG_HOME": ""]) { $1 }))
  }

  @Test
  func openCodeConfigListingReadsOnlyTheMachineWideConfig() throws {
    let projectDir = try freshProjectDir("pk-oc-locations")
    let home = try freshProjectDir("pk-oc-home")
    let environment = ["HOME": home.path, "XDG_CACHE_HOME": home.path + "-cache"]
    #expect(!listsPlugin(environment))

    let configFile = try freshProjectDir("pk-oc-config-file")
    try writePluginListing(in: configFile, name: "custom.jsonc", home: home)
    let configDir = try freshProjectDir("pk-oc-config-dir")
    try writePluginListing(in: configDir, name: "opencode.jsonc", home: home)
    try writePluginListing(in: home.appendingPathComponent(".opencode"), home: home)
    try writePluginListing(in: projectDir, home: home)
    try writePluginListing(in: projectDir.appendingPathComponent(".opencode"), home: home)
    #expect(
      !listsPlugin(
        environment.merging([
          "OPENCODE_CONFIG": configFile.appendingPathComponent("custom.jsonc").path,
          "OPENCODE_CONFIG_DIR": configDir.path,
        ]) { $1 }
      )
    )

    try writePluginListing(in: home.appendingPathComponent(".config/opencode"), name: "opencode.jsonc", home: home)
    #expect(listsPlugin(environment))
  }

  @Test
  func openCodeConfigListingFollowsTheCacheHome() throws {
    let home = try freshProjectDir("pk-oc-home")
    let globalDir = home.appendingPathComponent(".config/opencode")
    try writePluginListing(
      in: globalDir,
      body: "{\"plugin\": [\"file://\(home.path)/.cache/opencode/personakit/plugin\"]}"
    )

    #expect(listsPlugin(["HOME": home.path]))
    #expect(listsPlugin(["HOME": home.path, "XDG_CACHE_HOME": ""]))
    #expect(listsPlugin(["HOME": home.path, "XDG_CACHE_HOME": "\(home.path)/x/../.cache/"]))
    #expect(!listsPlugin(["HOME": home.path, "XDG_CACHE_HOME": "/elsewhere"]))
    // Without HOME, the passwd home stands in.
    #expect(
      EnforceInstallCommand.openCodeConfigListsPlugin(
        environment: ["XDG_CONFIG_HOME": home.path + "/.config"],
        passwdHome: { home.path }
      )
    )
    #expect(!listsPlugin([:]))
  }

  @Test
  func openCodeConfigListingParsesJSONCAndMatchesOnlyTheInstalledSpec() throws {
    let home = try freshProjectDir("pk-oc-home")
    let environment = ["HOME": home.path, "XDG_CACHE_HOME": home.path + "-cache"]
    let spec = Self.pluginSpec(home: home)
    let globalDir = home.appendingPathComponent(".config/opencode")

    func lists(_ body: String) throws -> Bool {
      try writePluginListing(in: globalDir, name: "opencode.jsonc", body: body)
      return listsPlugin(environment)
    }

    #expect(try lists("{ // plugins\n \"plugin\": [\"\(spec)\",], /* end */ }"))
    #expect(try lists("{\"plugin\": [\"other\", [\"\(spec)\", {\"personakitPath\": \"/x\"}]]}"))
    for listed in [
      "opencode-personakit", "opencode-personakit@\(PersonaKitVersion.current)", "opencode-personakit@latest",
      "\(spec)/", "\(spec)-evil", "\(spec)/Integrations/OpenCode/src/server.ts", "file://\(home.path)/plugin",
      "FILE://\(home.path)-cache/opencode/personakit/plugin", "\(home.path)-cache/opencode/personakit/plugin",
      " \(spec)",
    ] {
      #expect(try !lists("{\"plugin\": [\"\(listed)\"]}"), "\(listed)")
    }
    for body in [
      "{\"plugin\": [[[\"\(spec)\"]]]}", "{\"plugin\": \"\(spec)\"}", "{\"plugin\": [\"\(spec)\"", "[\"\(spec)\"]", "",
    ] {
      #expect(try !lists(body), "\(body)")
    }
  }

  // MARK: - enforce uninstall

  /// Runs `enforce uninstall` for `host` in `projectDir`.
  private func runUninstall(
    host: String = "claude",
    projectDir: URL,
    dryRun: Bool = false
  ) -> (status: Int32, stdout: String, stderr: String) {
    var status: Int32 = 0
    var stdout = ""
    let stderr = captureStderr {
      stdout = captureStdout {
        status = PersonaKitCLI().run(
          arguments: ["personakit", "enforce", "uninstall", "--host", host, "--project-dir", projectDir.path]
            + (dryRun ? ["--dry-run"] : [])
        )
      }
    }
    return (status, stdout, stderr)
  }

  /// Every entry under `root` by relative path: a file's bytes, or nil for a directory or a link.
  private func snapshot(_ root: URL) -> [String: Data?] {
    var entries: [String: Data?] = [:]
    for path in tree(root) {
      let url = root.appendingPathComponent(path)
      let type = (try? FileManager.default.attributesOfItem(atPath: url.path))?[.type] as? FileAttributeType
      entries[path] = type == .typeRegular ? try? Data(contentsOf: url) : nil
    }
    return entries
  }

  /// A project with Claude Code settings in install's own format, local settings, and a command.
  private func claudeProjectWithOwnSettings() throws -> URL {
    let projectDir = try freshProjectDir("pk-un-claude")
    let claudeDir = projectDir.appendingPathComponent(".claude")
    try FileManager.default.createDirectory(
      at: claudeDir.appendingPathComponent("commands"),
      withIntermediateDirectories: true
    )
    let settings = try JSONSerialization.data(
      withJSONObject: [
        "model": "opus",
        "permissions": ["allow": ["Bash(make test)"]],
        "hooks": ["PreToolUse": [["matcher": "Bash", "hooks": [["type": "command", "command": "audit-log"]]]]],
      ],
      options: [.prettyPrinted, .sortedKeys]
    )
    try (settings + Data("\n".utf8)).write(to: claudeDir.appendingPathComponent("settings.json"))
    try Data(#"{"theme":"dark"}"#.utf8).write(to: claudeDir.appendingPathComponent("settings.local.json"))
    try Data("# review\n".utf8).write(to: claudeDir.appendingPathComponent("commands/review.md"))
    return projectDir
  }

  @Test
  func claudeUninstallRestoresTheProjectInstallChanged() throws {
    let projectDir = try claudeProjectWithOwnSettings()
    let before = snapshot(projectDir)

    #expect(runInstall(extra: [], projectDir: projectDir, dryRun: false).status == 0)
    #expect(snapshot(projectDir) != before)
    let result = runUninstall(projectDir: projectDir)

    #expect(result.status == 0)
    #expect(result.stdout.contains("removed the PersonaKit hook from"))
    #expect(result.stdout.contains("removed manifest"))
    #expect(result.stdout.contains(EnforceInstallCommand.claudeCodeReloadNote))
    #expect(snapshot(projectDir) == before)
  }

  @Test
  func claudeUninstallFromABareProjectLeavesNothing() throws {
    let projectDir = try freshProjectDir("pk-un-claude-bare")

    #expect(runInstall(extra: [], projectDir: projectDir, dryRun: false).status == 0)
    let result = runUninstall(projectDir: projectDir)

    #expect(result.status == 0)
    #expect(tree(projectDir).isEmpty)
  }

  @Test
  func claudeUninstallKeepsUnrelatedSettingsInAnotherFormat() throws {
    let projectDir = try freshProjectDir("pk-un-claude-format")
    let settingsURL = projectDir.appendingPathComponent(".claude/settings.json")
    try FileManager.default.createDirectory(
      at: settingsURL.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    let original = #"{"theme":"dark","env":{"A":"1"},"hooks":{"Stop":[{"hooks":[{"type":"command","command":"x"}]}]}}"#
    try Data(original.utf8).write(to: settingsURL)

    #expect(runInstall(extra: [], projectDir: projectDir, dryRun: false).status == 0)
    #expect(runUninstall(projectDir: projectDir).status == 0)

    let restored = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: settingsURL)) as? NSDictionary)
    let expected = try #require(try JSONSerialization.jsonObject(with: Data(original.utf8)) as? NSDictionary)
    #expect(restored == expected)
    #expect(tree(projectDir.appendingPathComponent(".claude")) == ["settings.json"])
  }

  @Test
  func claudeUninstallWithNothingInstalledChangesNothing() throws {
    let projectDir = try freshProjectDir("pk-un-claude-none")
    let bare = runUninstall(projectDir: projectDir)

    #expect(bare.status == 0)
    #expect(bare.stdout.contains("No Claude Code enforcement installed in \(projectDir.path)."))
    #expect(tree(projectDir).isEmpty)

    let settingsURL = projectDir.appendingPathComponent(".claude/settings.json")
    try FileManager.default.createDirectory(
      at: settingsURL.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try Data(#"{"theme":"dark"}"#.utf8).write(to: settingsURL)
    let before = snapshot(projectDir)
    let result = runUninstall(projectDir: projectDir)

    #expect(result.status == 0)
    #expect(result.stdout.contains("No Claude Code enforcement installed"))
    #expect(snapshot(projectDir) == before)
  }

  @Test
  func claudeUninstallDryRunChangesNothing() throws {
    let projectDir = try claudeProjectWithOwnSettings()
    #expect(runInstall(extra: [], projectDir: projectDir, dryRun: false).status == 0)
    let installed = snapshot(projectDir)

    let result = runUninstall(projectDir: projectDir, dryRun: true)

    #expect(result.status == 0)
    #expect(result.stdout.contains("Dry run"))
    #expect(result.stdout.contains("audit-log"))
    #expect(!result.stdout.contains("hook-check --manifest"))
    #expect(result.stdout.contains("# Would remove → "))
    #expect(snapshot(projectDir) == installed)
  }

  @Test(arguments: [".claude", ".claude/personakit", ".claude/settings.json"])
  func claudeUninstallRefusesASymlinkedEnforcementPath(linked: String) throws {
    // The link's target holds installed enforcement, as ~/.claude could.
    let elsewhere = try freshProjectDir("pk-un-claude-elsewhere")
    #expect(runInstall(extra: [], projectDir: elsewhere, dryRun: false).status == 0)
    let target = elsewhere.appendingPathComponent(".claude").appendingPathComponent(
      String(linked.dropFirst(".claude".count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    )
    let before = snapshot(elsewhere)

    let projectDir = try freshProjectDir("pk-un-claude-symlink")
    let link = projectDir.appendingPathComponent(linked)
    try FileManager.default.createDirectory(at: link.deletingLastPathComponent(), withIntermediateDirectories: true)
    try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)

    for dryRun in [false, true] {
      let result = runUninstall(projectDir: projectDir, dryRun: dryRun)

      #expect(result.status != 0)
      #expect((result.stderr + result.stdout).contains("Refusing to uninstall: \(link.path) is a symbolic link"))
    }
    #expect(snapshot(elsewhere) == before)
    #expect(
      (try? FileManager.default.attributesOfItem(atPath: link.path))?[.type] as? FileAttributeType == .typeSymbolicLink
    )
  }

  @Test
  func claudeUninstallRefusesNonRegularManifestEntries() throws {
    let projectDir = try freshProjectDir("pk-un-claude-nonregular")
    #expect(runInstall(extra: [], projectDir: projectDir, dryRun: false).status == 0)
    let directory = projectDir.appendingPathComponent(".claude/personakit")
    let nested = directory.appendingPathComponent("dir.checks.json")
    try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
    try Data("keep".utf8).write(to: nested.appendingPathComponent("inside.txt"))
    let target = projectDir.appendingPathComponent("target.txt")
    try Data("t".utf8).write(to: target)
    try FileManager.default.createSymbolicLink(
      at: directory.appendingPathComponent("link.checks.json"),
      withDestinationURL: target
    )
    let before = snapshot(projectDir)

    for dryRun in [false, true] {
      let result = runUninstall(projectDir: projectDir, dryRun: dryRun)

      #expect(result.status != 0)
      #expect((result.stderr + result.stdout).contains("Refusing to uninstall"))
      #expect((result.stderr + result.stdout).contains("dir.checks.json, link.checks.json"))
    }
    #expect(snapshot(projectDir) == before)
  }

  @Test
  func claudeUninstallRefusesSettingsThatAreNotAJSONObject() throws {
    let projectDir = try freshProjectDir("pk-un-claude-badjson")
    #expect(runInstall(extra: [], projectDir: projectDir, dryRun: false).status == 0)
    let settingsURL = projectDir.appendingPathComponent(".claude/settings.json")
    try Data("{ not json".utf8).write(to: settingsURL)
    let before = snapshot(projectDir)

    let result = runUninstall(projectDir: projectDir)

    #expect(result.status != 0)
    #expect((result.stderr + result.stdout).contains("Refusing to uninstall: \(settingsURL.path) is not a JSON object"))
    #expect(snapshot(projectDir) == before)
  }

  @Test
  func openCodeUninstallRestoresTheProjectInstallChanged() throws {
    let projectDir = try freshProjectDir("pk-un-oc")
    let home = try freshProjectDir("pk-oc-home")
    try Data("{\"plugin\": [\"other\"]}".utf8).write(to: projectDir.appendingPathComponent("opencode.json"))
    let plugins = projectDir.appendingPathComponent(".opencode/plugins")
    try FileManager.default.createDirectory(at: plugins, withIntermediateDirectories: true)
    try Data("export {}\n".utf8).write(to: plugins.appendingPathComponent("local.ts"))
    let before = snapshot(projectDir)

    #expect(runOpenCodeInstall(projectDir: projectDir, home: home).status == 0)
    #expect(snapshot(projectDir) != before)
    let result = runUninstall(host: "opencode", projectDir: projectDir)

    #expect(result.status == 0)
    #expect(result.stdout.contains("removed manifest"))
    #expect(result.stdout.contains("Restart OpenCode"))
    #expect(snapshot(projectDir) == before)
  }

  @Test
  func openCodeUninstallFromABareProjectLeavesNothing() throws {
    let projectDir = try freshProjectDir("pk-un-oc-bare")
    let home = try freshProjectDir("pk-oc-home")

    #expect(runOpenCodeInstall(projectDir: projectDir, home: home).status == 0)
    let result = runUninstall(host: "opencode", projectDir: projectDir)

    #expect(result.status == 0)
    #expect(tree(projectDir).isEmpty)
  }

  @Test
  func openCodeUninstallRemovesEveryManifestAndKeepsOtherFiles() throws {
    let projectDir = try freshProjectDir("pk-un-oc-many")
    let directory = projectDir.appendingPathComponent(".opencode/personakit")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try Data("{}".utf8).write(to: directory.appendingPathComponent("a.checks.json"))
    try Data("{}".utf8).write(to: directory.appendingPathComponent("b.checks.json"))
    try Data("notes".utf8).write(to: directory.appendingPathComponent("notes.txt"))

    let dry = runUninstall(host: "opencode", projectDir: projectDir, dryRun: true)
    #expect(dry.status == 0)
    #expect(tree(directory) == ["a.checks.json", "b.checks.json", "notes.txt"])

    let result = runUninstall(host: "opencode", projectDir: projectDir)

    #expect(result.status == 0)
    #expect(tree(directory) == ["notes.txt"])
  }

  @Test
  func openCodeUninstallWithNothingInstalledChangesNothing() throws {
    let projectDir = try freshProjectDir("pk-un-oc-none")
    try Data("{}".utf8).write(to: projectDir.appendingPathComponent("opencode.json"))
    let before = snapshot(projectDir)

    let result = runUninstall(host: "opencode", projectDir: projectDir)

    #expect(result.status == 0)
    #expect(result.stdout.contains("No OpenCode enforcement installed in \(projectDir.path)."))
    #expect(snapshot(projectDir) == before)
  }

  @Test(arguments: [".opencode", ".opencode/personakit"])
  func openCodeUninstallRefusesASymlinkedEnforcementPath(linked: String) throws {
    let elsewhere = try freshProjectDir("pk-un-oc-elsewhere")
    let personakit = elsewhere.appendingPathComponent("personakit")
    try FileManager.default.createDirectory(at: personakit, withIntermediateDirectories: true)
    try Data("{}".utf8).write(to: personakit.appendingPathComponent("victim.checks.json"))
    let before = snapshot(elsewhere)

    let projectDir = try freshProjectDir("pk-un-oc-symlink")
    let link = projectDir.appendingPathComponent(linked)
    try FileManager.default.createDirectory(at: link.deletingLastPathComponent(), withIntermediateDirectories: true)
    try FileManager.default.createSymbolicLink(
      at: link,
      withDestinationURL: linked == ".opencode" ? elsewhere : personakit
    )

    for dryRun in [false, true] {
      let result = runUninstall(host: "opencode", projectDir: projectDir, dryRun: dryRun)

      #expect(result.status != 0)
      #expect((result.stderr + result.stdout).contains("Refusing to uninstall: \(link.path) is a symbolic link"))
    }
    #expect(snapshot(elsewhere) == before)
  }

  @Test
  func openCodeUninstallRefusesNonRegularManifestEntries() throws {
    let projectDir = try freshProjectDir("pk-un-oc-nonregular")
    let directory = projectDir.appendingPathComponent(".opencode/personakit")
    try FileManager.default.createDirectory(
      at: directory.appendingPathComponent("dir.checks.json"),
      withIntermediateDirectories: true
    )
    try Data("keep".utf8).write(to: directory.appendingPathComponent("dir.checks.json/inside.txt"))
    try Data("{}".utf8).write(to: directory.appendingPathComponent("old.checks.json"))
    let before = snapshot(projectDir)

    for dryRun in [false, true] {
      let result = runUninstall(host: "opencode", projectDir: projectDir, dryRun: dryRun)

      #expect(result.status != 0)
      #expect((result.stderr + result.stdout).contains("not regular files: dir.checks.json."))
    }
    #expect(snapshot(projectDir) == before)
  }

  @Test
  func claudeUninstallRefusesSettingsItCannotReadAndKeepsTheManifests() throws {
    let projectDir = try freshProjectDir("pk-un-claude-unreadable")
    #expect(runInstall(extra: [], projectDir: projectDir, dryRun: false).status == 0)
    let settingsURL = projectDir.appendingPathComponent(".claude/settings.json")
    let before = snapshot(projectDir)
    try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: settingsURL.path)
    defer { try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: settingsURL.path) }

    let result = runUninstall(projectDir: projectDir)

    #expect(result.status != 0)
    #expect((result.stderr + result.stdout).contains("Refusing to uninstall: could not read \(settingsURL.path)"))
    try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: settingsURL.path)
    #expect(snapshot(projectDir) == before)
  }

  @Test
  func claudeUninstallRemovesWhicheverHalfIsLeft() throws {
    let manifestsOnly = try claudeProjectWithOwnSettings()
    let settings = try Data(contentsOf: manifestsOnly.appendingPathComponent(".claude/settings.json"))
    #expect(runInstall(extra: [], projectDir: manifestsOnly, dryRun: false).status == 0)
    try settings.write(to: manifestsOnly.appendingPathComponent(".claude/settings.json"))

    let first = runUninstall(projectDir: manifestsOnly)

    #expect(first.status == 0)
    #expect(!first.stdout.contains("removed the PersonaKit hook"))
    #expect(first.stdout.contains("removed manifest"))
    #expect(!FileManager.default.fileExists(atPath: manifestsOnly.appendingPathComponent(".claude/personakit").path))

    let hookOnly = try claudeProjectWithOwnSettings()
    let before = snapshot(hookOnly)
    #expect(runInstall(extra: [], projectDir: hookOnly, dryRun: false).status == 0)
    try FileManager.default.removeItem(at: hookOnly.appendingPathComponent(".claude/personakit"))

    let second = runUninstall(projectDir: hookOnly)

    #expect(second.status == 0)
    #expect(second.stdout.contains("removed the PersonaKit hook"))
    #expect(!second.stdout.contains("removed manifest"))
    #expect(snapshot(hookOnly) == before)
  }

  @Test
  func claudeUninstallKeepsAHookAddedToThePersonaKitGroup() throws {
    let projectDir = try freshProjectDir("pk-un-claude-shared")
    #expect(runInstall(extra: [], projectDir: projectDir, dryRun: false).status == 0)
    let settingsURL = projectDir.appendingPathComponent(".claude/settings.json")
    var root = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: settingsURL)) as? [String: Any])
    var hooks = try #require(root["hooks"] as? [String: Any])
    var groups = try #require(hooks["PreToolUse"] as? [[String: Any]])
    var groupHooks = try #require(groups[0]["hooks"] as? [[String: Any]])
    groupHooks.append(["type": "command", "command": "audit-log"])
    groups[0]["hooks"] = groupHooks
    hooks["PreToolUse"] = groups
    root["hooks"] = hooks
    try JSONSerialization.data(withJSONObject: root).write(to: settingsURL)

    #expect(runUninstall(projectDir: projectDir).status == 0)

    let text = try String(contentsOf: settingsURL, encoding: .utf8)
    #expect(text.contains("audit-log"))
    #expect(!text.contains("hook-check --manifest"))
  }
}
