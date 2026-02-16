import Testing

import ContextMCP
@testable import ContextCLI
@testable import PersonaKitCore

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

// EXCEPTION(SwiftStyle): Test runner used synchronously in CLI tests.
// Default rule: Avoid @unchecked Sendable.
// Tradeoff: Tests run on a single thread; mutable state is safe here.
final class TestMCPServerRunner: MCPServerRunning, @unchecked Sendable {
  private(set) var invocations: [String] = []

  func run(version: String) throws {
    invocations.append(version)
  }
}
