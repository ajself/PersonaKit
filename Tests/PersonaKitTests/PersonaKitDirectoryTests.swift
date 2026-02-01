import Foundation
import Testing
@testable import PersonaKit

struct PersonaKitDirectoryTests {
    @Test
    func urlsAppendExpectedDirectories() throws {
        let root = try makeTempDirectory()

        #expect(PersonaKitDirectory.packsURL(root: root) == root.appendingPathComponent("Packs"))
        #expect(PersonaKitDirectory.sessionsURL(root: root) == root.appendingPathComponent("Sessions"))
    }

    @Test
    func hasPacksDetectsPresence() throws {
        let root = try makeTempDirectory()

        #expect(PersonaKitDirectory.hasPacks(root: root) == false)

        try FileManager.default.createDirectory(
            at: root.appendingPathComponent("Packs"),
            withIntermediateDirectories: true
        )

        #expect(PersonaKitDirectory.hasPacks(root: root) == true)
    }

    @Test
    func hasSessionsDetectsPresence() throws {
        let root = try makeTempDirectory()

        #expect(PersonaKitDirectory.hasSessions(root: root) == false)

        try FileManager.default.createDirectory(
            at: root.appendingPathComponent("Sessions"),
            withIntermediateDirectories: true
        )

        #expect(PersonaKitDirectory.hasSessions(root: root) == true)
    }
}
