import Foundation
import Testing

@testable import ContextCLI
@testable import ContextCore

struct CLIChecksTests {
  @Test
  func checksViaSessionDerivesCommandAndReviewGates() throws {
    let root = fixtureKitRootURL()

    var status: Int32 = 0
    let output = captureStdout {
      status = PersonaKitCLI().run(arguments: [
        "personakit",
        "checks",
        "--root",
        root.path,
        "--session",
        "senior-swiftui-engineer_apply-style",
      ])
    }

    #expect(status == 0)

    let manifest = try JSONDecoder().decode(ChecksManifest.self, from: Data(output.utf8))
    #expect(manifest.personaId == "senior-swiftui-engineer")
    #expect(manifest.directiveId == "apply-style")
    #expect(manifest.checks.map(\.maxClass) == ["command", "review", "review"])
    #expect(
      manifest.summary
        == ChecksManifestSummary(hookCount: 0, commandCount: 1, reviewCount: 2, unrepresentedCount: 2)
    )
  }

  @Test
  func checksOutputIsByteIdenticalAcrossRuns() {
    let root = fixtureKitRootURL()

    func runChecks() -> String {
      captureStdout {
        _ = PersonaKitCLI().run(arguments: [
          "personakit",
          "checks",
          "--root",
          root.path,
          "--persona",
          "senior-swiftui-engineer",
          "--directive",
          "apply-style",
        ])
      }
    }

    #expect(runChecks() == runChecks())
  }

  @Test
  func checksRejectsMissingPersona() {
    var status: Int32 = 0
    let stderr = captureStderr {
      status = PersonaKitCLI().run(arguments: [
        "personakit",
        "checks",
        "--root",
        fixtureKitRootURL().path,
      ])
    }

    #expect(status == 1)
    #expect(stderr.contains("checks requires --persona"))
  }
}
