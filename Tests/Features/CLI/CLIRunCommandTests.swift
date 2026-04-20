import Foundation
import Synchronization
import Testing

@testable import ContextCLI
@testable import ContextCore

struct CLIRunCommandTests {
  @Test
  func runBuildsCorrectPayload() throws {
    let scopes = ScopeSet(projectScopeURL: fixtureKitRootURL(), globalScopeURL: nil)
    let session = try SessionFileLoader.load(
      root: fixtureKitRootURL(),
      sessionId: "senior-swiftui-engineer_apply-style"
    )
    let exportedContext = try String(
      contentsOf: fixturesRootURL().appendingPathComponent(
        "expected/export_senior-swiftui-engineer_apply-style.md"
      ),
      encoding: .utf8
    )

    let result = try RunPayloadBuilder.build(
      scopes: scopes,
      session: session,
      task: "Refactor the networking layer."
    )

    #expect(
      result.resolution
        == RunResolution(
          sessionId: "senior-swiftui-engineer_apply-style",
          personaId: "senior-swiftui-engineer",
          directiveId: "apply-style",
          kitIds: ["repo-constraints", "swift-style", "swiftui-style"]
        )
    )
    #expect(result.payload.contains("## Context\n\(exportedContext)"))
    #expect(result.payload.contains("## Task\nRefactor the networking layer."))
  }

  @Test
  func dryRunPrintsPayload() throws {
    let root = fixtureKitRootURL()

    var status: Int32 = 0
    let output = captureStdout {
      status = PersonaKitCLI().run(arguments: [
        "personakit",
        "run",
        "--root",
        root.path,
        "--session",
        "senior-swiftui-engineer_apply-style",
        "--agent",
        "opencode",
        "--dry-run",
        "--",
        "Refactor the networking layer.",
      ])
    }

    #expect(status == 0)
    #expect(output.contains("# PersonaKit Runtime Payload"))
    #expect(output.contains("## Task\nRefactor the networking layer."))
  }

  @Test
  func dryRunCopiesPayloadToClipboard() {
    let root = fixtureKitRootURL()
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
          "run",
          "--root",
          root.path,
          "--session",
          "senior-swiftui-engineer_apply-style",
          "--agent",
          "opencode",
          "--dry-run",
          "--copy",
          "--",
          "Refactor the networking layer.",
        ])
      }

      #expect(stdoutOutput.isEmpty)
    }

    #expect(status == 0)
    #expect(stderrOutput.contains("Copied dry-run payload to clipboard."))
    #expect(clipboardContents.withLock { $0 }?.contains("# PersonaKit Runtime Payload") == true)
    #expect(clipboardContents.withLock { $0 }?.contains("## Task\nRefactor the networking layer.") == true)
  }

  @Test
  func copyRequiresDryRun() {
    let root = fixtureKitRootURL()

    var status: Int32 = 0
    let stderrOutput = captureStderr {
      status = PersonaKitCLI().run(arguments: [
        "personakit",
        "run",
        "--root",
        root.path,
        "--session",
        "senior-swiftui-engineer_apply-style",
        "--agent",
        "opencode",
        "--copy",
        "--",
        "Refactor the networking layer.",
      ])
    }

    #expect(status == 1)
    #expect(stderrOutput.contains("run allows --copy only with --dry-run."))
  }

  @Test
  func dryRunReportsClipboardFailure() {
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
          "run",
          "--root",
          root.path,
          "--session",
          "senior-swiftui-engineer_apply-style",
          "--agent",
          "opencode",
          "--dry-run",
          "--copy",
          "--",
          "Refactor the networking layer.",
        ])
      }

      #expect(stdoutOutput.isEmpty)
    }

    #expect(status == 1)
    #expect(stderrOutput.contains("Failed to copy dry-run payload to the clipboard."))
  }

  @Test
  func missingSessionFails() throws {
    let root = fixtureKitRootURL()

    var status: Int32 = 0
    let stderrOutput = captureStderr {
      status = PersonaKitCLI().run(arguments: [
        "personakit",
        "run",
        "--root",
        root.path,
        "--session",
        "missing-session",
        "--agent",
        "opencode",
        "--dry-run",
        "--",
        "Refactor the networking layer.",
      ])
    }

    #expect(status == 1)
    #expect(stderrOutput.contains("Session file not found"))
  }

  @Test
  func missingTaskFails() throws {
    let root = fixtureKitRootURL()

    var status: Int32 = 0
    _ = captureStderr {
      status = PersonaKitCLI().run(arguments: [
        "personakit",
        "run",
        "--root",
        root.path,
        "--session",
        "senior-swiftui-engineer_apply-style",
        "--agent",
        "opencode",
      ])
    }

    #expect(status == 1)
  }
}
