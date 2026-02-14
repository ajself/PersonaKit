import Foundation
import Testing
@testable import PersonaKitCore

struct ExporterTests {
    @Test
    func exportMatchesGoldenFile() throws {
        let root = fixtureKitRootURL()

        let output = try SessionExporter.export(
            root: root,
            personaId: "senior-swiftui-engineer",
            directiveId: "apply-style",
            kitOverrides: []
        )

        let fixtureURL = fixturesRootURL()
            .appendingPathComponent("expected/export_senior-swiftui-engineer_apply-style.md")
        let expected = try String(contentsOf: fixtureURL, encoding: .utf8)

        #expect(normalizedTrailingNewline(output) == normalizedTrailingNewline(expected))
    }

    @Test
    func exportMatchesGoldenFileUsingSession() throws {
        let root = fixtureKitRootURL()
        let session = try SessionFileLoader.load(
            root: root,
            sessionId: "senior-swiftui-engineer_apply-style"
        )

        let output = try SessionExporter.export(
            root: root,
            personaId: session.personaId,
            directiveId: session.directiveId,
            kitOverrides: session.kitOverrides ?? []
        )

        let fixtureURL = fixturesRootURL()
            .appendingPathComponent("expected/export_senior-swiftui-engineer_apply-style.md")
        let expected = try String(contentsOf: fixtureURL, encoding: .utf8)

        #expect(normalizedTrailingNewline(output) == normalizedTrailingNewline(expected))
    }

    @Test
    func exportFailsWhenValidationErrorsExist() throws {
        let root = try makeTempDirectory().appendingPathComponent("PersonaKit")
        try copyFixtureKit(to: root)

        let missingURL = root.appendingPathComponent("Packs/essentials/tools-and-constraints.md")
        try FileManager.default.removeItem(at: missingURL)

        do {
            _ = try SessionExporter.export(
                root: root,
                personaId: "senior-swiftui-engineer",
                directiveId: "apply-style",
                kitOverrides: []
            )
            #expect(Bool(false))
        } catch let error as ExportError {
            if case .validationFailed = error {
                return
            }
            #expect(Bool(false))
        }
    }
}
