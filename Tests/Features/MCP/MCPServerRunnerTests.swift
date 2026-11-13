import ContextCore
import MCP
import Testing

@testable import ContextMCP

struct MCPServerRunnerTests {
  @Test(.timeLimit(.minutes(1)))
  func serveReturnsOnceTheClientDisconnects() async throws {
    let scopes = ScopeSet(projectScopeURL: fixtureKitRootURL(), globalScopeURL: nil)
    let (clientTransport, serverTransport) = await InMemoryTransport.createConnectedPair()
    // The in-memory transport drops messages sent to an unconnected peer; connecting again in serve is a no-op.
    try await serverTransport.connect()
    let serving = Task {
      try await MCPServerRunner.serve(version: "test", scopes: scopes, transport: serverTransport)
    }
    defer { serving.cancel() }

    let client = Client(name: "test", version: "1")
    let initialized = try await client.connect(transport: clientTransport)
    #expect(initialized.serverInfo.name == "PersonaKit")
    #expect(try await !client.listTools().tools.isEmpty)

    await client.disconnect()

    let returned = await withTaskGroup(of: Bool.self) { group in
      group.addTask {
        _ = try? await serving.value
        return true
      }
      group.addTask {
        try? await Task.sleep(for: .seconds(5))
        return false
      }
      let first = await group.next() ?? false
      serving.cancel()
      group.cancelAll()
      return first
    }
    #expect(returned, "serve should return once its transport closes, so `personakit mcp` exits")
  }
}
