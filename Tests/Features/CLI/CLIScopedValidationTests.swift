import Foundation
import Testing

@testable import ContextCLI
@testable import ContextCore

/// Handoff commands block only on errors in the session they hand off; `validate` stays strict.
struct CLIScopedValidationTests {
  private static let sessionId = "senior-swiftui-engineer_apply-style"

  @Test
  func exportOfAHealthySessionSucceedsAndWarnsOnStderr() throws {
    let root = try makeRootWithBrokenExtraSession()
    let expected = try String(
      contentsOf: fixturesRootURL()
        .appendingPathComponent("expected/export_senior-swiftui-engineer_apply-style.md"),
      encoding: .utf8
    )

    let run = runCLI(["export", "--root", root.path, "--no-global", "--session", Self.sessionId])

    #expect(run.status == 0)
    #expect(run.stdout == expected + "\n")
    let lines = run.stderr.split(separator: "\n").map(String.init)
    #expect(lines.count == 2)
    #expect(lines.first?.hasPrefix("Validation summary: ") == true)
    #expect(lines.first?.hasSuffix(" warnings=1 errors=0") == true)
    #expect(lines.last?.hasPrefix("warning: session broken-extra ") == true)
  }

  @Test
  func exportOfACleanLibraryWritesNothingToStderr() {
    let run = runCLI([
      "export", "--root", fixtureKitRootURL().path, "--no-global", "--session", Self.sessionId,
    ])

    #expect(run.status == 0)
    #expect(run.stderr.isEmpty)
  }

  @Test
  func exportFailsOnAnErrorInItsOwnSessionAndStillListsWarnings() throws {
    let root = try makeRootWithBrokenExtraSession()
    try FileManager.default.removeItem(at: root.appendingPathComponent("Packs/skills/tools-and-constraints.md"))

    let run = runCLI(["export", "--root", root.path, "--no-global", "--session", Self.sessionId])

    #expect(run.status == 1)
    #expect(run.stdout.isEmpty)
    let lines = run.stderr.split(separator: "\n").map(String.init)
    #expect(lines.count == 3)
    #expect(lines.first?.hasSuffix(" warnings=1 errors=1") == true)
    #expect(lines.dropFirst().first?.hasPrefix("skill tools-and-constraints body: ") == true)
    #expect(lines.last?.hasPrefix("warning: session broken-extra ") == true)
  }

  @Test(arguments: ["export", "resolve-grounding-skills"])
  func aResolutionFailureStillListsWarnings(command: String) throws {
    let root = try makeRootWithBrokenExtraSession()

    let run = runCLI([
      command, "--root", root.path, "--no-global",
      "--persona", "senior-swiftui-engineer", "--directive", "apply-style", "--kits", "no-such-kit",
    ])

    #expect(run.status == 1)
    #expect(run.stdout.isEmpty)
    let lines = run.stderr.split(separator: "\n").map(String.init)
    #expect(lines.count == 2)
    #expect(lines.first?.contains("missingId=no-such-kit") == true)
    #expect(lines.last?.hasPrefix("warning: session broken-extra ") == true)
  }

  @Test(arguments: ["export", "resolve-grounding-skills"])
  func aGroundingSkillReadFailureStillListsWarnings(command: String) throws {
    let root = try makeRootWithBrokenExtraSession()
    try Data([0xFF, 0xFE]).write(to: root.appendingPathComponent("Packs/skills/swiftui-style-guide-reference.md"))

    let run = runCLI([
      command, "--root", root.path, "--no-global", "--session", Self.sessionId,
      "--target-path", "Sources/FooView.swift", "--skill-tag", "swiftui",
    ])

    #expect(run.status == 1)
    #expect(run.stdout.isEmpty)
    let lines = run.stderr.split(separator: "\n").map(String.init)
    #expect(lines.count == 2)
    #expect(lines.first?.hasPrefix("Error: ") == true)
    #expect(lines.first?.contains("swiftui-style-guide-reference") == true)
    #expect(lines.last?.hasPrefix("warning: session broken-extra ") == true)
  }

  @Test
  func resolveGroundingSkillsSucceedsAndWarnsOnStderr() throws {
    let root = try makeRootWithBrokenExtraSession()

    let run = runCLI([
      "resolve-grounding-skills", "--root", root.path, "--no-global", "--session", Self.sessionId,
    ])

    #expect(run.status == 0)
    #expect(try JSONSerialization.jsonObject(with: Data(run.stdout.utf8)) is [String: Any])
    #expect(run.stderr.contains("\nwarning: session broken-extra "))
  }

  @Test
  func validateStillFailsOnAnyErrorInTheLibrary() throws {
    let root = try makeRootWithBrokenExtraSession()

    let run = runCLI(["validate", "--root", root.path, "--no-global"])

    #expect(run.status == 1)
    #expect(run.stdout.contains("session broken-extra "))
  }

  @Test
  func enforceInstallOfAHealthySessionSucceedsWithAWarning() throws {
    let root = try makeRootWithBrokenExtraSession()
    try forbidNetworkAccess(root: root)
    let projectDir = try makeTempDirectory()

    let run = runCLI(enforceInstallArguments(root: root, projectDir: projectDir))

    #expect(run.status == 0)
    #expect(run.stderr.contains("warning: session broken-extra "))
    #expect(
      FileManager.default.fileExists(
        atPath: projectDir.appendingPathComponent(".claude/personakit/\(Self.sessionId).checks.json").path
      )
    )
  }

  @Test
  func enforceInstallRefusesASessionWithItsOwnErrorAndWritesNothing() throws {
    let root = try makeTempDirectory().appendingPathComponent("PersonaKit")
    try copyFixtureKit(to: root)
    try FileManager.default.removeItem(at: root.appendingPathComponent("Packs/skills/tools-and-constraints.md"))
    try forbidNetworkAccess(root: root)
    let projectDir = try makeTempDirectory()

    let run = runCLI(enforceInstallArguments(root: root, projectDir: projectDir))

    #expect(run.status == 1)
    #expect(run.stderr.contains("skill tools-and-constraints body: "))
    #expect(!FileManager.default.fileExists(atPath: projectDir.appendingPathComponent(".claude").path))
  }

  @Test
  func enforceInstallPrintsNoPassingSummaryBeforeALaterRefusal() throws {
    let root = try makeRootWithBrokenExtraSession()
    try forbidNetworkAccess(root: root)
    let projectDir = try makeTempDirectory()
    let outside = try makeTempDirectory()
    try FileManager.default.createSymbolicLink(
      at: projectDir.appendingPathComponent(".claude"),
      withDestinationURL: outside
    )

    let run = runCLI(enforceInstallArguments(root: root, projectDir: projectDir))

    #expect(run.status != 0)
    #expect(!run.stderr.contains("Validation summary:"))
  }

  private func enforceInstallArguments(root: URL, projectDir: URL) -> [String] {
    [
      "enforce", "install",
      "--root", root.path,
      "--no-global",
      "--session", Self.sessionId,
      "--project-dir", projectDir.path,
      "--executable", "/usr/local/bin/personakit",
    ]
  }

  /// Gives the session's persona something to enforce, so install writes a manifest.
  private func forbidNetworkAccess(root: URL) throws {
    let personaURL = root.appendingPathComponent("Packs/personas/senior-swiftui-engineer.persona.json")
    var json = try #require(
      try JSONSerialization.jsonObject(with: Data(contentsOf: personaURL)) as? [String: Any]
    )
    json["forbiddenCapabilities"] = ["network-access"]
    try JSONSerialization.data(withJSONObject: json, options: [.sortedKeys]).write(to: personaURL)
  }

  private func makeRootWithBrokenExtraSession() throws -> URL {
    let root = try makeTempDirectory().appendingPathComponent("PersonaKit")
    try copyFixtureKit(to: root)
    try writeSessionFile(
      SessionFile(
        id: "broken-extra",
        personaId: "missing-persona",
        directiveId: "apply-style",
        kitOverrides: []
      ),
      root: root
    )
    return root
  }

  private func runCLI(_ arguments: [String]) -> (status: Int32, stdout: String, stderr: String) {
    var status: Int32 = 0
    var stdout = ""
    let stderr = captureStderr {
      stdout = captureStdout {
        status = PersonaKitCLI().run(arguments: ["personakit"] + arguments)
      }
    }
    return (status, stdout, stderr)
  }
}
