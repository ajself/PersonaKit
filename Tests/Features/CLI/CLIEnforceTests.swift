import Foundation
import Testing

@testable import ContextCLI
@testable import ContextCore

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

  /// Runs `hook-check` with a synthetic PreToolUse payload and returns stdout.
  private func runHookCheck(manifest: URL, toolName: String) -> String {
    let payload = "{\"tool_name\":\"\(toolName)\",\"tool_input\":{}}"
    let cli = PersonaKitCLI(
      interactiveIO: CLIInteractiveIO(
        isInteractive: { false },
        readLine: { nil },
        readStdinToEnd: { payload }
      )
    )

    return captureStdout {
      _ = cli.run(arguments: ["personakit", "hook-check", "--manifest", manifest.path])
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
}
