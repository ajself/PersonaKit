import ArgumentParser
import Foundation
import Testing

@testable import ContextCLI
@testable import ContextCore

struct CLITerminalTextTests {
  /// A persona name that retitles and clears the terminal, hides text, and reverses it.
  private static let hostileName =
    "Evil\u{1B}]0;PWNED\u{07}\u{1B}[2J\u{1B}[8mhidden\u{9B}31m\r\u{202E}desrever\u{2066}x\u{2069}\u{7F}"

  @Test
  func sanitizedStripsTerminalControlsButKeepsTabsNewlinesAndText() {
    #expect(TerminalText.sanitized(Self.hostileName) == "Evil]0;PWNED[2J[8mhidden31mdesreverx")
    #expect(TerminalText.sanitized("a\tb\nc — café 🚀") == "a\tb\nc — café 🚀")
  }

  @Test
  func sanitizedStripsInvisibleFormattingAndTagCharacters() {
    // Tag characters spell "hi" invisibly; a model reads them, a person does not.
    let hidden = "ok\u{E0068}\u{E0069}\u{200B}\u{2060}\u{FEFF}\u{061C}\u{200E}\u{200F}!"

    #expect(TerminalText.sanitized(hidden) == "ok!")
  }

  @Test
  func escapingJSONKeepsTheValueButPrintsSafely() throws {
    let value = "N\u{202E}X\u{9B}\u{E0041}é"
    let json = String(decoding: try JSONEncoder().encode(["name": value]), as: UTF8.self)

    let escaped = TerminalText.escapingJSON(json)

    #expect(escaped == #"{"name":"N\u202eX\u009b\udb40\udc41é"}"#)
    let decoded = try JSONDecoder().decode([String: String].self, from: Data(escaped.utf8))
    #expect(decoded["name"] == value)
  }

  @Test
  func reportedErrorsAreSanitizedAndKeepTheirExitCode() {
    var code: Int32 = 0
    let stderr = captureStderr {
      code = ContextCLIEntrypoint.report(CLIError.failure("persona evil\u{1B}]0;T\u{07}id is a duplicate"))
    }

    #expect(code == 1)
    #expect(stderr.contains("persona evil]0;Tid is a duplicate"))
    #expect(!stderr.unicodeScalars.contains { $0.value == 0x1B || $0.value == 0x07 })
  }

  @Test
  func helpReportsToStdoutWithASuccessCode() {
    var code: Int32 = 1
    let stdout = captureStdout { code = ContextCLIEntrypoint.report(CleanExit.helpRequest()) }

    #expect(code == 0)
    #expect(stdout.contains("USAGE: personakit"))
  }

  @Test
  func hookDecisionReasonsAreSanitizedBeforeTheHostDecodesThem() {
    let decision = ClaudeCodeHookCheckDecision(isDenied: true, reason: "forbidden by \u{202E}evil\u{E0041} mandate")

    let json = HookCheckCommand.claudeOutputJSON(for: decision)

    #expect(json.contains("forbidden by evil mandate"))
  }

  @Test
  func completionDropsIdsWithControlCharacters() throws {
    let root = try hostileRoot()
    defer { try? FileManager.default.removeItem(at: root.deletingLastPathComponent()) }
    let sessions = root.appendingPathComponent("Sessions")
    let hostileID = "evil\u{1B}]0;T\u{07}\u{202E}id"
    let original = try Data(contentsOf: sessions.appendingPathComponent("read-only-auditor_audit-pass.session.json"))
    var object = try #require(JSONSerialization.jsonObject(with: original) as? [String: Any])
    object["id"] = hostileID
    try JSONSerialization.data(withJSONObject: object).write(
      to: sessions.appendingPathComponent("\(hostileID).session.json")
    )

    let completions = CLICompletions.sessionIDs(
      arguments: ["personakit", "export", "--root", root.path, "--no-global", "--session", ""],
      index: 6,
      prefix: ""
    )

    #expect(completions == ["read-only-auditor_audit-pass"])
  }

  /// A copy of the read-only fixture whose persona carries the hostile name.
  private func hostileRoot() throws -> URL {
    let rootURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("pk-terminal-\(UUID().uuidString)")
      .appendingPathComponent("root")
    try FileManager.default.createDirectory(
      at: rootURL.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try FileManager.default.copyItem(at: readOnlyFixtureRootURL(), to: rootURL)
    let personaURL = rootURL.appendingPathComponent("Packs/personas/read-only-auditor.persona.json")
    var object = try #require(
      JSONSerialization.jsonObject(with: Data(contentsOf: personaURL)) as? [String: Any]
    )
    object["name"] = Self.hostileName
    try JSONSerialization.data(withJSONObject: object).write(to: personaURL)
    return rootURL
  }

  private func run(_ arguments: [String]) -> (status: Int32, stdout: String) {
    var status: Int32 = 0
    let stdout = captureStdout {
      status = PersonaKitCLI().run(arguments: ["personakit"] + arguments)
    }
    return (status, stdout)
  }

  @Test
  func textOutputNeverCarriesTerminalControlsFromContent() throws {
    let root = try hostileRoot()
    defer { try? FileManager.default.removeItem(at: root.deletingLastPathComponent()) }

    let list = run(["list", "personas", "--root", root.path, "--no-global"])
    let export = run([
      "export", "--root", root.path, "--no-global", "--session", "read-only-auditor_audit-pass",
    ])
    let graph = run([
      "graph", "--root", root.path, "--no-global", "--session", "read-only-auditor_audit-pass",
    ])

    for result in [list, export, graph] {
      #expect(result.status == 0)
      #expect(result.stdout.contains("Evil]0;PWNED"))
      #expect(!result.stdout.unicodeScalars.contains { [0x1B, 0x7F, 0x9B, 0x202E, 0x2066].contains($0.value) })
    }
  }

  @Test
  func exportWrittenToAFileIsSanitizedToo() throws {
    let root = try hostileRoot()
    defer { try? FileManager.default.removeItem(at: root.deletingLastPathComponent()) }
    let outputURL = root.deletingLastPathComponent().appendingPathComponent("export.md")

    let result = run([
      "export", "--root", root.path, "--no-global", "--session", "read-only-auditor_audit-pass",
      "--output", outputURL.path,
    ])

    #expect(result.status == 0)
    let written = try String(contentsOf: outputURL, encoding: .utf8)
    #expect(written.contains("Evil]0;PWNED"))
    #expect(!written.unicodeScalars.contains { $0.value == 0x1B })
  }

  @Test
  func jsonOutputKeepsTheContentExact() throws {
    let root = try hostileRoot()
    defer { try? FileManager.default.removeItem(at: root.deletingLastPathComponent()) }

    let result = run(["list", "personas", "--json", "--root", root.path, "--no-global"])

    #expect(result.status == 0)
    // Every control is escaped, so the document prints safely and still says exactly what the file says.
    #expect(result.stdout.contains(#"\u001b]0;PWNED"#))
    #expect(!result.stdout.unicodeScalars.contains { [0x1B, 0x9B, 0x202E].contains($0.value) })
    let document = try JSONSerialization.jsonObject(with: Data(result.stdout.utf8))
    #expect(Self.strings(in: document).contains(Self.hostileName))
  }

  /// Every string value anywhere in a decoded JSON document.
  private static func strings(in value: Any) -> [String] {
    switch value {
    case let string as String:
      return [string]
    case let array as [Any]:
      return array.flatMap { strings(in: $0) }
    case let object as [String: Any]:
      return object.values.flatMap { strings(in: $0) }
    default:
      return []
    }
  }
}
