import Foundation
import Testing
@testable import PersonaKitCore

struct ProjectPersonaKitLocatorTests {
    @Test
    func findsPersonaKitInCurrentDirectory() throws {
        let root = try makeTempDirectory()
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent(".personakit"),
            withIntermediateDirectories: true
        )

        let locator = ProjectPersonaKitLocator(startingURL: root)
        let found = locator.locate()

        #expect(found == root.appendingPathComponent(".personakit"))
    }

    @Test
    func findsPersonaKitInParentDirectory() throws {
        let root = try makeTempDirectory()
        let nested = root.appendingPathComponent("a/b/c")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent(".personakit"),
            withIntermediateDirectories: true
        )

        let locator = ProjectPersonaKitLocator(startingURL: nested)
        let found = locator.locate()

        #expect(found == root.appendingPathComponent(".personakit"))
    }

    @Test
    func returnsNilWhenPersonaKitAbsent() throws {
        let root = try makeTempDirectory()
        let nested = root.appendingPathComponent("a/b/c")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)

        let locator = ProjectPersonaKitLocator(startingURL: nested)
        let found = locator.locate()

        #expect(found == nil)
    }
}
