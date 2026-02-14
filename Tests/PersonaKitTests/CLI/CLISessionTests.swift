import Foundation
import Testing
@testable import PersonaKitCore

struct CLISessionTests {
    @Test
    func exportViaSessionMatchesGoldenFile() throws {
        let root = fixtureKitRootURL()
        let fixtureURL = fixturesRootURL()
            .appendingPathComponent("expected/export_senior-swiftui-engineer_apply-style.md")
        let expected = try String(contentsOf: fixtureURL, encoding: .utf8)

        var status: Int32 = 0
        let output = captureStdout {
            status = PersonaKitCLI().run(arguments: [
                "personakit",
                "export",
                "--root",
                root.path,
                "--session",
                "senior-swiftui-engineer_apply-style",
            ])
        }

        #expect(status == 0)
        #expect(normalizedTrailingNewline(output) == normalizedTrailingNewline(expected))
    }

    @Test
    func graphViaSessionMatchesGoldenFile() throws {
        let root = fixtureKitRootURL()
        let fixtureURL = fixturesRootURL()
            .appendingPathComponent("expected/graph_senior-swiftui-engineer_apply-style.txt")
        let expected = try String(contentsOf: fixtureURL, encoding: .utf8)

        var status: Int32 = 0
        let output = captureStdout {
            status = PersonaKitCLI().run(arguments: [
                "personakit",
                "graph",
                "--root",
                root.path,
                "--session",
                "senior-swiftui-engineer_apply-style",
            ])
        }

        #expect(status == 0)
        #expect(normalizedTrailingNewline(output) == normalizedTrailingNewline(expected))
    }

    @Test
    func exportRequiresDirectiveWhenPersonaProvided() {
        var status: Int32 = 0
        let stderrOutput = captureStderr {
            status = PersonaKitCLI().run(arguments: [
                "personakit",
                "export",
                "--persona",
                "senior-swiftui-engineer",
            ])
        }

        #expect(status == 1)
        #expect(stderrOutput.contains("Error:"))
    }

    @Test
    func exportRejectsMixingSessionWithPersonaDirectiveFlags() {
        var status: Int32 = 0
        let stderrOutput = captureStderr {
            status = PersonaKitCLI().run(arguments: [
                "personakit",
                "export",
                "--session",
                "senior-swiftui-engineer_apply-style",
                "--persona",
                "senior-swiftui-engineer",
                "--directive",
                "apply-style",
            ])
        }

        #expect(status == 1)
        #expect(stderrOutput.contains("Error:"))
    }
}
