import Dispatch
import Foundation
import MCP

protocol MCPServerRunning {
    func run(version: String) throws
}

struct MCPServerRunner: MCPServerRunning {
    func run(version: String) throws {
        Task {
            do {
                try await runServer(version: version)
            } catch {
                var stderrStream = StandardError()
                stderrStream.write("Error: MCP server failed to start: \(error.localizedDescription)\n")
                exit(1)
            }
        }
        dispatchMain()
    }

    private func runServer(version: String) async throws {
        let server = Server(
            name: "PersonaKit",
            version: version,
            capabilities: .init(
                prompts: .init(listChanged: false),
                resources: .init(subscribe: false, listChanged: false)
            )
        )

        await server.withMethodHandler(ListResources.self) { _ in
            ListResources.Result(resources: [], nextCursor: nil)
        }

        await server.withMethodHandler(ListPrompts.self) { _ in
            ListPrompts.Result(prompts: [], nextCursor: nil)
        }

        let transport = StdioTransport()
        try await server.start(transport: transport)
        let sleepNanoseconds = UInt64(60 * 60 * 24 * 365 * 100) * 1_000_000_000
        try await Task.sleep(nanoseconds: sleepNanoseconds)
    }
}
