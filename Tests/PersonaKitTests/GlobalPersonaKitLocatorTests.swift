import Foundation
import Testing
@testable import PersonaKit

struct GlobalPersonaKitLocatorTests {
    @Test
    func returnsNilWhenMissing() throws {
        let home = try makeTempDirectory()
        let locator = GlobalPersonaKitLocator(homeDirectory: home)

        #expect(locator.locate() == nil)
    }

    @Test
    func returnsDirectoryWhenPresent() throws {
        let home = try makeTempDirectory()
        let expected = home.appendingPathComponent(".personakit")
        try FileManager.default.createDirectory(at: expected, withIntermediateDirectories: true)

        let locator = GlobalPersonaKitLocator(homeDirectory: home)

        #expect(locator.locate()?.path == expected.path)
    }
}
