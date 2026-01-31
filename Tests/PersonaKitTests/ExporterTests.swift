import Foundation
import XCTest
@testable import PersonaKit

final class ExporterTests: XCTestCase {
    func testExportMatchesGoldenFile() throws {
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

        XCTAssertEqual(output, expected)
    }

    func testExportFailsWhenValidationErrorsExist() throws {
        let root = try makeTempDirectory().appendingPathComponent("PersonaKit")
        try PersonaKitInitializer().run(destination: root.path)

        let missingURL = root.appendingPathComponent("Packs/essentials/tools-and-constraints.md")
        try FileManager.default.removeItem(at: missingURL)

        XCTAssertThrowsError(
            try SessionExporter.export(
                root: root,
                personaId: "senior-swiftui-engineer",
                taskId: "apply-style",
                kitOverrides: []
            )
        ) { error in
            guard case ExportError.validationFailed = error else {
                return XCTFail("Expected validation failure")
            }
        }
    }
}
