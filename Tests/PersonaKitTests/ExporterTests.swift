import Foundation
import Testing
@testable import PersonaKit

struct ExporterTests {
    @Test
    func exportMatchesGoldenFile() throws {
        let root = try makeTempDirectory().appendingPathComponent("PersonaKit")
        try PersonaKitInitializer().run(destination: root.path)

        let output = try SessionExporter.export(
            root: root,
            personaId: "senior-swiftui-engineer",
            taskId: "apply-style",
            kitOverrides: []
        )

        let fixtureURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/export_golden.md")
        let expected = try String(contentsOf: fixtureURL, encoding: .utf8)

        #expect(output == expected)
    }

    @Test
    func exportFailsWhenValidationErrorsExist() throws {
        let root = try makeTempDirectory().appendingPathComponent("PersonaKit")
        try PersonaKitInitializer().run(destination: root.path)

        let missingURL = root.appendingPathComponent("Packs/essentials/tools-and-constraints.md")
        try FileManager.default.removeItem(at: missingURL)

        do {
            _ = try SessionExporter.export(
                root: root,
                personaId: "senior-swiftui-engineer",
                taskId: "apply-style",
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
