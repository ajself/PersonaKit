import Testing
@testable import PersonaKit

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

final class TestMCPServerRunner: MCPServerRunning {
    private(set) var invocations: [String] = []

    func run(version: String) throws {
        invocations.append(version)
    }
}
