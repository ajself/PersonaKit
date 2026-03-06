import ContextMCP
import Foundation
import Synchronization
import Testing

@testable import ContextCLI
@testable import ContextCore

struct CLIMCPCommandTests {
  @Test
  func mcpCommandInvokesRunner() throws {
    let root = try makeTempDirectory()
    let projectScope = root.appendingPathComponent(".personakit")
    try FileManager.default.createDirectory(
      at: projectScope.appendingPathComponent("Packs"),
      withIntermediateDirectories: true
    )
    let home = try makeTempDirectory()
    let resolver = ScopeRootResolver(startingURL: root, homeDirectory: home)
    let runner = TestMCPServerRunner()
    let cli = PersonaKitCLI(
      scopeRootResolver: resolver,
      mcpServerRunner: runner
    )

    var status: Int32 = 0
    let output = captureStdout {
      status = cli.run(arguments: [
        "personakit",
        "mcp",
        "--root",
        projectScope.path,
      ])
    }

    #expect(status == 0)
    #expect(output.isEmpty)
    #expect(runner.invocations.map(\.version) == [PersonaKitVersion.current])
    #expect(runner.invocations.first?.scopes.projectScopeURL?.path == projectScope.path)
    #expect(runner.invocations.first?.scopes.globalScopeURL == nil)
  }
}

final class TestMCPServerRunner: MCPServerRunning, Sendable {
  struct Invocation: Equatable {
    let version: String
    let scopes: ScopeSet
  }

  private let invocationsState = Mutex<[Invocation]>([])

  var invocations: [Invocation] {
    invocationsState.withLock { $0 }
  }

  func run(version: String, scopes: ScopeSet) throws {
    invocationsState.withLock { invocations in
      invocations.append(Invocation(version: version, scopes: scopes))
    }
  }
}
