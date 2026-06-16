import Foundation
import Testing

@testable import ContextCLI

struct RefsCommandTests {
  private func makeStarterRoot() throws -> URL {
    let root = try makeTempDirectory().appendingPathComponent(".personakit")
    let status = PersonaKitCLI().run(arguments: ["personakit", "init", root.path])
    #expect(status == 0)
    return root
  }

  @Test
  func refsTracesOutgoingAndIncomingForAStarterPersona() throws {
    let root = try makeStarterRoot()

    var status: Int32 = 0
    let output = captureStdout {
      status = PersonaKitCLI().run(arguments: [
        "personakit", "refs", "--root", root.path, "solo-developer",
      ])
    }

    #expect(status == 0)
    #expect(output.contains("persona \"solo-developer\""))
    #expect(output.contains("references (outgoing):"))
    #expect(output.contains("kit \"cli-guardrails\" (defaultKitIds)"))
    #expect(output.contains("referenced by (incoming):"))
    #expect(output.contains("session \"solo-dev\" (personaId)"))
  }

  @Test
  func refsRejectsUnknownId() {
    var status: Int32 = 0
    let stderrOutput = captureStderr {
      _ = captureStdout {
        status = PersonaKitCLI().run(arguments: [
          "personakit", "refs", "--root", "/dev/null/missing", "nope",
        ])
      }
    }

    #expect(status != 0)
    #expect(!stderrOutput.isEmpty)
  }

  @Test
  func orphansAnnotatesEntryPointsButNotBuildingBlocks() throws {
    let root = try makeStarterRoot()

    _ = PersonaKitCLI().run(arguments: [
      "personakit", "create", "skill", "--root", root.path,
      "--id", "lonely-skill", "--name", "Lonely", "--description", "x", "--provided-by", "tests",
    ])
    _ = PersonaKitCLI().run(arguments: [
      "personakit", "create", "persona", "--root", root.path,
      "--id", "stray-persona", "--name", "Stray", "--summary", "x",
    ])

    var status: Int32 = 0
    let output = captureStdout {
      status = PersonaKitCLI().run(arguments: ["personakit", "orphans", "--root", root.path])
    }

    #expect(status == 0)
    // Building blocks are listed bare.
    #expect(output.contains("\n  skill \"lonely-skill\""))
    #expect(!output.contains("skill \"lonely-skill\" —"))
    // Directly-invocable entry points are flagged so an agent does not treat them as dead.
    #expect(
      output.contains(
        "persona \"stray-persona\" — unreferenced by any session, but invocable directly via --persona"
      )
    )
  }
}
