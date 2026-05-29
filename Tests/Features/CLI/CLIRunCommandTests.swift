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
          kitIds: ["repo-constraints", "swift-style", "swiftui-style"],
          authorizedSkillIds: ["codex-cli"],
          authorizedProviderIds: ["codex-cli"]
        )
    )
    #expect(result.payload.contains("## Context\n\(exportedContext)"))
    #expect(result.payload.contains("## Task\nRefactor the networking layer."))
  }

  @Test
  func dryRunPrintsPayload() throws {
    let root = publicStarterRootURL()

    var status: Int32 = 0
    let output = captureStdout {
      status = PersonaKitCLI().run(arguments: [
        "personakit",
        "run",
        "--root",
        root.path,
        "--session",
        "solo-dev",
        "--agent",
        "opencode",
        "--dry-run",
        "--",
        "Make a small, reviewable CLI improvement.",
      ])
    }

    #expect(status == 0)
    #expect(output.contains("# PersonaKit Runtime Payload"))
    #expect(output.contains("## Task\nMake a small, reviewable CLI improvement."))
  }

  @Test
  func dryRunCopiesPayloadToClipboard() {
    let root = publicStarterRootURL()
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
          "solo-dev",
          "--agent",
          "opencode",
          "--dry-run",
          "--copy",
          "--",
          "Make a small, reviewable CLI improvement.",
        ])
      }

      #expect(stdoutOutput.isEmpty)
    }

    #expect(status == 0)
    #expect(stderrOutput.contains("Copied dry-run payload to clipboard."))
    #expect(clipboardContents.withLock { $0 }?.contains("# PersonaKit Runtime Payload") == true)
    #expect(
      clipboardContents.withLock { $0 }?
        .contains("## Task\nMake a small, reviewable CLI improvement.") == true
    )
  }

  @Test
  func dryRunRejectsUnauthorizedAgent() {
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
        "--dry-run",
        "--",
        "Refactor the networking layer.",
      ])
    }

    #expect(status == 1)
    #expect(stderrOutput.contains("run agent `opencode` is not authorized"))
    #expect(stderrOutput.contains("Authorized providers: codex-cli"))
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
    let root = publicStarterRootURL()
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
          "solo-dev",
          "--agent",
          "opencode",
          "--dry-run",
          "--copy",
          "--",
          "Make a small, reviewable CLI improvement.",
        ])
      }

      #expect(stdoutOutput.isEmpty)
    }

    #expect(status == 1)
    #expect(stderrOutput.contains("Failed to copy dry-run payload to the clipboard."))
  }

  @Test
  func openCodeAdapterInvokesExecutableWithPayloadFile() throws {
    let temporaryDirectory = try makeTempDirectory()
    let executableURL = temporaryDirectory.appendingPathComponent("opencode")
    let capturedInvocation = Mutex<AgentProcessInvocation?>(nil)
    let capturedPayload = Mutex<String?>(nil)
    let adapter = OpenCodeAgentAdapter(
      processRunner: StubAgentProcessRunner { invocation in
        capturedInvocation.withLock { $0 = invocation }
        capturedPayload.withLock { payload in
          payload = try? String(contentsOf: URL(fileURLWithPath: invocation.arguments[0]), encoding: .utf8)
        }

        return 0
      },
      executableResolver: StubAgentExecutableResolver(executableURL: executableURL),
      temporaryDirectory: temporaryDirectory
    )

    let status = try adapter.invoke(payload: "resolved runtime payload")
    let invocation = try #require(capturedInvocation.withLock { $0 })
    let payloadPath = try #require(invocation.arguments.first)

    #expect(status == 0)
    #expect(invocation.executableURL == executableURL)
    #expect(invocation.arguments.count == 1)
    #expect(payloadPath.hasPrefix(temporaryDirectory.path))
    #expect(payloadPath.hasSuffix(".md"))
    #expect(capturedPayload.withLock { $0 } == "resolved runtime payload")
    #expect(!FileManager.default.fileExists(atPath: payloadPath))
  }

  @Test
  func openCodeAdapterPropagatesExitStatus() throws {
    let temporaryDirectory = try makeTempDirectory()
    let adapter = OpenCodeAgentAdapter(
      processRunner: StubAgentProcessRunner { _ in 42 },
      executableResolver: StubAgentExecutableResolver(
        executableURL: temporaryDirectory.appendingPathComponent("opencode")
      ),
      temporaryDirectory: temporaryDirectory
    )

    #expect(try adapter.invoke(payload: "payload") == 42)
  }

  @Test
  func openCodeAdapterReportsMissingExecutable() throws {
    let adapter = OpenCodeAgentAdapter(
      processRunner: StubAgentProcessRunner { _ in
        #expect(Bool(false))
        return 0
      },
      executableResolver: StubAgentExecutableResolver(executableURL: nil),
      temporaryDirectory: try makeTempDirectory()
    )

    do {
      _ = try adapter.invoke(payload: "payload")
      #expect(Bool(false))
    } catch {
      #expect(error.localizedDescription.contains("Failed to launch opencode"))
    }
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

private struct StubAgentProcessRunner: AgentProcessRunning {
  let runHandler: (AgentProcessInvocation) throws -> Int32

  func run(_ invocation: AgentProcessInvocation) throws -> Int32 {
    try runHandler(invocation)
  }
}

private struct StubAgentExecutableResolver: AgentExecutableResolving {
  let executableURL: URL?

  func executableURL(named executableName: String) -> URL? {
    executableURL
  }
}
