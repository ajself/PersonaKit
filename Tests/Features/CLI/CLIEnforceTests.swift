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
}
