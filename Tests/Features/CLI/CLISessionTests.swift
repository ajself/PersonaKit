import Foundation
import Synchronization
import Testing

@testable import ContextCLI
@testable import ContextCore

struct CLISessionTests {
  @Test
  func exportViaSessionMatchesGoldenFile() throws {
    let root = fixtureKitRootURL()
    let fixtureURL = fixturesRootURL()
      .appendingPathComponent("expected/export_senior-swiftui-engineer_apply-style.md")
    let expected = try String(contentsOf: fixtureURL, encoding: .utf8)

    var status: Int32 = 0
    let output = captureStdout {
      status = PersonaKitCLI().run(arguments: [
        "personakit",
        "export",
        "--root",
        root.path,
        "--session",
        "senior-swiftui-engineer_apply-style",
      ])
    }

    #expect(status == 0)
    #expect(normalizedTrailingNewline(output) == normalizedTrailingNewline(expected))
  }

  @Test
  func exportViaSessionCopiesToClipboard() throws {
    let root = fixtureKitRootURL()
    let fixtureURL = fixturesRootURL()
      .appendingPathComponent("expected/export_senior-swiftui-engineer_apply-style.md")
    let expected = try String(contentsOf: fixtureURL, encoding: .utf8)
    let clipboardContents = Mutex<String?>(nil)
    let cli = PersonaKitCLI(
      clipboardIO: CLIClipboardIO(
        writeString: { value in
          clipboardContents.withLock { contents in
            contents = value
          }
          return true
        }
      )
    )

    var status: Int32 = 0
    let stderrOutput = captureStderr {
      let stdoutOutput = captureStdout {
        status = cli.run(arguments: [
          "personakit",
          "export",
          "--root",
          root.path,
          "--session",
          "senior-swiftui-engineer_apply-style",
          "--copy",
        ])
      }

      #expect(stdoutOutput.isEmpty)
    }

    #expect(status == 0)
    #expect(stderrOutput.contains("Copied prompt to clipboard."))
    #expect(clipboardContents.withLock { $0 } == expected)
  }

  @Test
  func exportStatsWriteToStderrAndLeaveStdoutClean() throws {
    let root = fixtureKitRootURL()
    let fixtureURL = fixturesRootURL()
      .appendingPathComponent("expected/export_senior-swiftui-engineer_apply-style.md")
    let expected = try String(contentsOf: fixtureURL, encoding: .utf8)

    var status: Int32 = 0
    var stdoutOutput = ""
    let stderrOutput = captureStderr {
      stdoutOutput = captureStdout {
        status = PersonaKitCLI().run(arguments: [
          "personakit",
          "export",
          "--root",
          root.path,
          "--session",
          "senior-swiftui-engineer_apply-style",
          "--stats",
        ])
      }
    }

    #expect(status == 0)
    #expect(stdoutOutput == expected + "\n")
    #expect(stderrOutput.contains("Export stats:"))
    #expect(stderrOutput.contains("sections."))
  }

  @Test
  func exportStatsSummaryCountsLinesBytesAndSections() {
    let summary = ExportCommand.statsSummary(for: "# Persona\nrole line\n# Directive\ngoal\n")

    #expect(summary == "Export stats: 5 lines, 37 bytes, 2 sections.")
  }

  @Test
  func graphViaSessionMatchesGoldenFile() throws {
    let root = fixtureKitRootURL()
    let fixtureURL = fixturesRootURL()
      .appendingPathComponent("expected/graph_senior-swiftui-engineer_apply-style.txt")
    let expected = try String(contentsOf: fixtureURL, encoding: .utf8)

    var status: Int32 = 0
    let output = captureStdout {
      status = PersonaKitCLI().run(arguments: [
        "personakit",
        "graph",
        "--root",
        root.path,
        "--session",
        "senior-swiftui-engineer_apply-style",
      ])
    }

    #expect(status == 0)
    #expect(normalizedTrailingNewline(output) == normalizedTrailingNewline(expected))
  }

  @Test
  func contractViaSessionReturnsStructuredJSON() throws {
    let root = fixtureKitRootURL()

    var status: Int32 = 0
    let output = captureStdout {
      status = PersonaKitCLI().run(arguments: [
        "personakit",
        "contract",
        "--root",
        root.path,
        "--session",
        "senior-swiftui-engineer_apply-style",
        "--check-skills",
        "codex-cli,missing-skill",
      ])
    }

    #expect(status == 0)

    let data = try #require(output.data(using: .utf8))
    let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

    #expect(object["personaId"] as? String == "senior-swiftui-engineer")
    #expect(object["directiveId"] as? String == "apply-style")
    #expect(object["authorizedSkillIds"] as? [String] == ["codex-cli"])
    #expect(object["undeclaredRequestedSkillIds"] as? [String] == ["missing-skill"])
    #expect(object["isAuthorized"] as? Bool == false)

    let scope = try #require(object["scope"] as? [String: Any])
    #expect(scope["mode"] as? String == "project-only")
    #expect(scope["projectRoot"] as? String == root.standardizedFileURL.path)
    #expect(scope["resolutionOrder"] as? [String] == [root.standardizedFileURL.path])
  }

  @Test
  func resolveGroundingSkillsViaSessionReturnsStructuredJSON() throws {
    let root = fixtureKitRootURL()

    var status: Int32 = 0
    let output = captureStdout {
      status = PersonaKitCLI().run(arguments: [
        "personakit",
        "resolve-grounding-skills",
        "--root",
        root.path,
        "--session",
        "senior-swiftui-engineer_apply-style",
        "--target-path",
        "Sources/FooView.swift",
        "--skill-tag",
        "swiftui",
      ])
    }

    #expect(status == 0)

    let data = try #require(output.data(using: .utf8))
    let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    let matchedGroundingSkills = try #require(object["matchedGroundingSkills"] as? [[String: Any]])
    #expect(
      matchedGroundingSkills.map { $0["id"] as? String } == [
        "swift-style-guide-reference",
        "swiftui-style-guide-reference",
        "tools-and-constraints",
      ]
    )
  }

  @Test
  func exportRequiresDirectiveWhenPersonaProvided() {
    var status: Int32 = 0
    let stderrOutput = captureStderr {
      status = PersonaKitCLI().run(arguments: [
        "personakit",
        "export",
        "--persona",
        "senior-swiftui-engineer",
      ])
    }

    #expect(status == 1)
    #expect(stderrOutput.contains("Error:"))
  }

  @Test
  func exportRejectsMixingSessionWithPersonaDirectiveFlags() {
    var status: Int32 = 0
    let stderrOutput = captureStderr {
      status = PersonaKitCLI().run(arguments: [
        "personakit",
        "export",
        "--session",
        "senior-swiftui-engineer_apply-style",
        "--persona",
        "senior-swiftui-engineer",
        "--directive",
        "apply-style",
      ])
    }

    #expect(status == 1)
    #expect(stderrOutput.contains("Error:"))
  }

  @Test
  func exportRejectsCopyAndOutputTogether() {
    var status: Int32 = 0
    let stderrOutput = captureStderr {
      status = PersonaKitCLI().run(arguments: [
        "personakit",
        "export",
        "--session",
        "senior-swiftui-engineer_apply-style",
        "--copy",
        "--output",
        "/tmp/export.md",
      ])
    }

    #expect(status == 1)
    #expect(stderrOutput.contains("export allows only one destination: --copy or --output."))
  }

  @Test
  func exportReportsClipboardFailure() {
    let root = fixtureKitRootURL()
    let cli = PersonaKitCLI(
      clipboardIO: CLIClipboardIO(
        writeString: { _ in false }
      )
    )

    var status: Int32 = 0
    let stderrOutput = captureStderr {
      let stdoutOutput = captureStdout {
        status = cli.run(arguments: [
          "personakit",
          "export",
          "--root",
          root.path,
          "--session",
          "senior-swiftui-engineer_apply-style",
          "--copy",
        ])
      }

      #expect(stdoutOutput.isEmpty)
    }

    #expect(status == 1)
    #expect(stderrOutput.contains("Failed to copy prompt to the clipboard."))
  }
}
