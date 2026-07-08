import Foundation
import Testing

@testable import ContextCLI

struct CLIRootCommandTests {
  /// Bare `personakit` (no subcommand) must orient a cold agent with a short,
  /// scope-free message and exit 0. The orientation is static and never resolves
  /// scope, so it works from any directory. We deliberately do NOT mutate the
  /// process working directory here: it is process-global state and Swift Testing
  /// runs tests in parallel, so a `changeCurrentDirectoryPath` would race with any
  /// concurrent test that reads the cwd (e.g. the MCP guidance scope-risk checks).
  @Test
  func bareCommandPrintsScopeFreeOrientation() throws {
    var status: Int32 = -1
    let output = captureStdout {
      status = PersonaKitCLI().run(arguments: ["personakit"])
    }

    #expect(status == 0)
    #expect(output.contains("PersonaKit provides reusable operating contracts"))
    #expect(output.contains("personakit guidance"))
    #expect(output.contains("personakit --help"))
    // It must be the orientation, not the old full-help dump.
    #expect(!output.contains("USAGE:"))
    #expect(!output.contains("SUBCOMMANDS:"))
  }
}
