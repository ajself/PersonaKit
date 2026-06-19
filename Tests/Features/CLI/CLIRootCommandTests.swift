import Foundation
import Testing

@testable import ContextCLI

struct CLIRootCommandTests {
  /// Bare `personakit` (no subcommand) must orient a cold agent with a short,
  /// scope-free message and exit 0 — even from a directory with no `.personakit`,
  /// since the orientation resolves no scope.
  @Test
  func bareCommandPrintsScopeFreeOrientation() throws {
    let workspace = try makeTempDirectory()
    let fileManager = FileManager.default
    let originalDirectory = fileManager.currentDirectoryPath
    #expect(fileManager.changeCurrentDirectoryPath(workspace.path))
    defer { _ = fileManager.changeCurrentDirectoryPath(originalDirectory) }

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
