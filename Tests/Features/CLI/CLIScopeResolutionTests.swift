import Foundation
import Testing

@testable import ContextCLI
@testable import ContextCore

struct CLIScopeResolutionTests {
  @Test
  func projectScopeUsedWhenRootMissing() throws {
    let root = try makeTempDirectory()
    let projectScope = root.appendingPathComponent(".personakit")
    try PersonaKitInitializer().run(destination: projectScope.path)

    let home = try makeTempDirectory()
    let resolver = ScopeRootResolver(startingURL: root, homeDirectory: home)
    let cli = PersonaKitCLI(scopeRootResolver: resolver)

    var status: Int32 = 0
    let output = captureStdout {
      status = cli.run(arguments: [
        "personakit",
        "list",
        "personas",
      ])
    }

    #expect(status == 0)
    #expect(output.contains("solo-developer"))
  }

  @Test
  func globalScopeUsedWhenProjectMissing() throws {
    let root = try makeTempDirectory()
    let home = try makeTempDirectory()
    let globalScope = home.appendingPathComponent(".personakit")
    try PersonaKitInitializer().run(destination: globalScope.path)

    let resolver = ScopeRootResolver(startingURL: root, homeDirectory: home)
    let cli = PersonaKitCLI(scopeRootResolver: resolver)

    var status: Int32 = 0
    let output = captureStdout {
      status = cli.run(arguments: [
        "personakit",
        "list",
        "personas",
      ])
    }

    #expect(status == 0)
    #expect(output.contains("solo-developer"))
  }

  @Test
  func missingScopesRequireRoot() throws {
    let root = try makeTempDirectory()
    let home = try makeTempDirectory()
    let resolver = ScopeRootResolver(startingURL: root, homeDirectory: home)
    let cli = PersonaKitCLI(scopeRootResolver: resolver)

    var status: Int32 = 0
    let stderrOutput = captureStderr {
      status = cli.run(arguments: [
        "personakit",
        "list",
        "personas",
      ])
    }

    #expect(status == 1)
    #expect(stderrOutput.contains("No PersonaKit scope found."))
  }
}
