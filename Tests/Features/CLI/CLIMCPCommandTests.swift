import ContextMCP
import Synchronization
import Testing

@testable import ContextCLI
@testable import ContextCore

struct CLIMCPCommandTests {
  @Test
  func mcpCommandInvokesRunner() {
    let runner = TestMCPServerRunner()
    let cli = PersonaKitCLI(mcpServerRunner: runner)

    var status: Int32 = 0
    let output = captureStdout {
      status = cli.run(arguments: [
        "personakit",
        "mcp",
      ])
    }

    #expect(status == 0)
    #expect(output.isEmpty)
    #expect(runner.invocations == [PersonaKitVersion.current])
  }
}

final class TestMCPServerRunner: MCPServerRunning, Sendable {
  private let invocationsState = Mutex<[String]>([])

  var invocations: [String] {
    invocationsState.withLock { $0 }
  }

  func run(version: String) throws {
    invocationsState.withLock { invocations in
      invocations.append(version)
    }
  }
}
