import XCTest
@testable import PersonaKit

final class PersonaKitInitTests: XCTestCase {
    func testInitCreatesExpectedFiles() throws {
        let destination = try makeTempDirectory().appendingPathComponent("PersonaKit")
        try PersonaKitInitializer().run(destination: destination.path)

        let snapshot = try snapshotFiles(at: destination)
        let expectedPaths = Set(StarterKitManifest.entries.map { $0.relativePath })

        XCTAssertEqual(Set(snapshot.keys), expectedPaths)

        for entry in StarterKitManifest.entries {
            XCTAssertEqual(snapshot[entry.relativePath], entry.contents)
        }
    }

    func testInitIsDeterministicAndRemovesExtras() throws {
        let destination = try makeTempDirectory().appendingPathComponent("PersonaKit")
        try PersonaKitInitializer().run(destination: destination.path)

        let firstSnapshot = try snapshotFiles(at: destination)
        let extraURL = destination.appendingPathComponent("extra.txt")
        try Data("extra".utf8).write(to: extraURL)

        try PersonaKitInitializer().run(destination: destination.path)
        let secondSnapshot = try snapshotFiles(at: destination)

        XCTAssertEqual(firstSnapshot, secondSnapshot)
        XCTAssertFalse(FileManager.default.fileExists(atPath: extraURL.path))
    }

    func testInitRefusesDangerousDestinations() throws {
        let initializer = PersonaKitInitializer()

        XCTAssertThrowsError(try initializer.run(destination: "")) { error in
            XCTAssertEqual(error as? InitError, .emptyPath)
        }

        XCTAssertThrowsError(try initializer.run(destination: "/")) { error in
            guard case let InitError.disallowedPath(path) = error else {
                return XCTFail("Expected disallowedPath error")
            }
            XCTAssertEqual(path, "/")
        }

        let homePath = FileManager.default.homeDirectoryForCurrentUser.path
        XCTAssertThrowsError(try initializer.run(destination: homePath)) { error in
            guard case let InitError.disallowedPath(path) = error else {
                return XCTFail("Expected disallowedPath error")
            }
            XCTAssertEqual(path, homePath)
        }
    }
}
