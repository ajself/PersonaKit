import Foundation
import Testing
@testable import PersonaKit

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
}
