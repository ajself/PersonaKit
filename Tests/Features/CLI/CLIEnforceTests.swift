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
  func hookCheckDeniesEditAndBashButAllowsRead() throws {
    let manifest = try writeReadOnlyManifest()

    #expect(runHookCheck(manifest: manifest, toolName: "Edit").contains("\"permissionDecision\":\"deny\""))
    // The bypass proof: a shell write goes through Bash, which read-only forbids.
    #expect(runHookCheck(manifest: manifest, toolName: "Bash").contains("\"permissionDecision\":\"deny\""))
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

    let manifest = try writeReadOnlyManifest()
    let sha = try sha256Hex(of: manifest)
    for stdin in ["", "not json", "{\"tool\":\"read\"}", "{\"tool_name\":\"Read\"}"] {
      let output = runHookCheck(manifest: manifest, host: "opencode", expectSHA256: sha, stdin: stdin)
      #expect(output.contains("\"decision\":\"deny\""))
      #expect(output.contains("fail-closed"))
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
  func enforceInstallKeepsBareExecutableNameForPathResolution() throws {
    let projectDir = FileManager.default.temporaryDirectory
      .appendingPathComponent("pk-bareexe-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: projectDir, withIntermediateDirectories: true)

    var status: Int32 = 0
    _ = captureStdout {
      status = PersonaKitCLI().run(arguments: [
        "personakit", "enforce", "install",
        "--root", readOnlyFixtureRootURL().path,
        "--no-global",
        "--session", "read-only-auditor_audit-pass",
        "--project-dir", projectDir.path,
        "--executable", "personakit",
      ])
    }
    #expect(status == 0)

    let settingsURL = projectDir.appendingPathComponent(".claude/settings.json")
    let settings = try JSONSerialization.jsonObject(with: Data(contentsOf: settingsURL)) as? [String: Any]
    let hooks = try #require(settings?["hooks"] as? [String: Any])
    let preToolUse = try #require(hooks["PreToolUse"] as? [[String: Any]])
    let command = try #require(
      (preToolUse.first?["hooks"] as? [[String: Any]])?.first?["command"] as? String
    )

    // A bare name stays bare — never rewritten to <cwd>/personakit.
    #expect(command.hasPrefix("'personakit' hook-check --manifest "))
    #expect(!command.contains("\(projectDir.path)/personakit"))
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
    #expect(output.contains("Edit|Write|NotebookEdit|Bash"))
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
  /// so the plugin-listed check never reads the real user's OpenCode config.
  private func runOpenCodeInstall(
    projectDir: URL,
    home: URL,
    dryRun: Bool = false,
    session: String = CLIEnforceTests.openCodeSessionId,
    extra: [String] = []
  ) -> (status: Int32, stdout: String, stderr: String) {
    withEnvironment(Self.isolatedOpenCodeEnvironment(home: home)) {
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

  /// `HOME` pointed at `home` and every other variable the plugin-listed check reads unset.
  private static func isolatedOpenCodeEnvironment(home: URL) -> [String: String?] {
    ["HOME": home.path, "XDG_CONFIG_HOME": nil, "OPENCODE_CONFIG": nil, "OPENCODE_CONFIG_DIR": nil]
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
    #expect(result.stderr.contains("opencode plugin opencode-personakit@"))
    // The check reads config; it never writes it.
    #expect(
      try String(contentsOf: projectDir.appendingPathComponent("opencode.json"), encoding: .utf8)
        == "{\"plugin\": [\"other\"]}"
    )
  }

  @Test(arguments: [
    "opencode.json", "opencode.jsonc", ".opencode/opencode.json", ".opencode/opencode.jsonc",
  ])
  func openCodeInstallDoesNotWarnWhenProjectConfigListsPlugin(relativePath: String) throws {
    let projectDir = try freshProjectDir("pk-oc-listed")
    let home = try freshProjectDir("pk-oc-home")
    let config = projectDir.appendingPathComponent(relativePath)
    try FileManager.default.createDirectory(
      at: config.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    // JSONC with a comment: the check is a substring search, not a parse.
    try Data("{ // plugins\n \"plugin\": [\"opencode-personakit@2.1.0\"] }".utf8).write(to: config)

    let result = runOpenCodeInstall(projectDir: projectDir, home: home)

    #expect(result.status == 0)
    #expect(!result.stderr.contains("opencode plugin opencode-personakit@"))
  }

  @Test
  func openCodeInstallDoesNotWarnWhenGlobalConfigListsPlugin() throws {
    let projectDir = try freshProjectDir("pk-oc-global")
    let home = try freshProjectDir("pk-oc-home")
    let globalDir = home.appendingPathComponent(".config/opencode")
    try FileManager.default.createDirectory(at: globalDir, withIntermediateDirectories: true)
    try Data("{\"plugin\": [\"opencode-personakit@2.1.0\"]}".utf8)
      .write(to: globalDir.appendingPathComponent("opencode.json"))

    let result = runOpenCodeInstall(projectDir: projectDir, home: home)

    #expect(result.status == 0)
    #expect(!result.stderr.contains("opencode plugin opencode-personakit@"))
  }

  @Test
  func openCodeInstallDryRunWritesNothing() throws {
    let projectDir = try freshProjectDir("pk-oc-dry")
    let home = try freshProjectDir("pk-oc-home")

    let result = runOpenCodeInstall(projectDir: projectDir, home: home, dryRun: true)

    #expect(result.status == 0)
    #expect(result.stdout.contains("Dry run"))
    #expect(result.stdout.contains(".opencode/personakit/\(Self.openCodeSessionId).checks.json"))
    #expect(!result.stdout.contains("Edit|Write|NotebookEdit|Bash"))
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
    #expect(result.stderr.contains("No class-1 hook checks to install for session"))
    #expect(result.stderr.contains("nothing OpenCode can deny"))
    #expect(result.stdout.isEmpty)
    #expect(tree(projectDir).isEmpty)
    if !capabilities.isEmpty {
      #expect(result.stderr.contains("degrade to review"))
      #expect(result.stderr.contains("unattended-iteration"))
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
    #expect(result.stderr.contains("remains in force"))
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
    #expect(result.stderr.contains("degrade to review"))
    #expect(result.stderr.contains("unattended-iteration"))
    #expect(!result.stderr.contains("network-egress —"))
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
    #expect(result.stderr.contains("opencode plugin opencode-personakit@"))
    #expect(tree(home).isEmpty)
  }

  /// Writes an OpenCode config listing the plugin at `directory/name`.
  private func writePluginListing(in directory: URL, name: String = "opencode.json") throws {
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try Data("{\"plugin\": [\"opencode-personakit@2.1.0\"]}".utf8).write(to: directory.appendingPathComponent(name))
  }

  private func listsPlugin(projectDir: URL, _ environment: [String: String]) -> Bool {
    EnforceInstallCommand.openCodeConfigListsPlugin(
      projectRoot: projectDir,
      environment: environment,
      passwdHome: { nil }
    )
  }

  @Test
  func openCodeConfigListingHonorsXDGConfigHome() throws {
    let projectDir = try freshProjectDir("pk-oc-xdg")
    let home = try freshProjectDir("pk-oc-home")
    let xdg = try freshProjectDir("pk-oc-xdg-home")
    try writePluginListing(in: xdg.appendingPathComponent("opencode"))
    // A listing under $HOME/.config is ignored once XDG_CONFIG_HOME is set.
    try writePluginListing(in: home.appendingPathComponent(".config/opencode"))
    let emptyXDG = try freshProjectDir("pk-oc-xdg-empty")

    #expect(listsPlugin(projectDir: projectDir, ["HOME": home.path, "XDG_CONFIG_HOME": xdg.path]))
    #expect(!listsPlugin(projectDir: projectDir, ["HOME": home.path, "XDG_CONFIG_HOME": emptyXDG.path]))
    #expect(listsPlugin(projectDir: projectDir, ["HOME": home.path]))
  }

  @Test
  func openCodeConfigListingReadsEveryConfigLocation() throws {
    let projectDir = try freshProjectDir("pk-oc-locations")
    let home = try freshProjectDir("pk-oc-home")
    #expect(!listsPlugin(projectDir: projectDir, ["HOME": home.path]))

    let configFile = try freshProjectDir("pk-oc-config-file")
    try writePluginListing(in: configFile, name: "custom.jsonc")
    #expect(
      listsPlugin(
        projectDir: projectDir,
        ["HOME": home.path, "OPENCODE_CONFIG": configFile.appendingPathComponent("custom.jsonc").path]
      )
    )

    let configDir = try freshProjectDir("pk-oc-config-dir")
    try writePluginListing(in: configDir, name: "opencode.jsonc")
    #expect(listsPlugin(projectDir: projectDir, ["HOME": home.path, "OPENCODE_CONFIG_DIR": configDir.path]))

    let dotHome = try freshProjectDir("pk-oc-dot-home")
    try writePluginListing(in: dotHome.appendingPathComponent(".opencode"))
    #expect(listsPlugin(projectDir: projectDir, ["HOME": dotHome.path]))

    try writePluginListing(in: projectDir.appendingPathComponent(".opencode"))
    #expect(listsPlugin(projectDir: projectDir, [:]))
  }
}
