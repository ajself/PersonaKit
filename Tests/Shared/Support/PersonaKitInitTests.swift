import Foundation
import Testing

@testable import ContextCLI
@testable import ContextCore

struct PersonaKitInitTests {
  @Test
  func initCreatesExpectedFiles() throws {
    let destination = try makeTempDirectory().appendingPathComponent("PersonaKit")
    try PersonaKitInitializer().run(destination: destination.path)

    let snapshot = try snapshotFiles(at: destination)
    let expectedPaths = Set(StarterKitManifest.entries.map { $0.relativePath })

    #expect(Set(snapshot.keys) == expectedPaths)

    for entry in StarterKitManifest.entries {
      #expect(snapshot[entry.relativePath] == entry.contents)
    }
  }

  @Test
  func initIsDeterministicAndRemovesExtras() throws {
    let destination = try makeTempDirectory().appendingPathComponent("PersonaKit")
    try PersonaKitInitializer().run(destination: destination.path)

    let firstSnapshot = try snapshotFiles(at: destination)
    let extraURL = destination.appendingPathComponent("extra.txt")
    try Data("extra".utf8).write(to: extraURL)

    try PersonaKitInitializer().run(destination: destination.path)
    let secondSnapshot = try snapshotFiles(at: destination)

    #expect(firstSnapshot == secondSnapshot)
    #expect(!FileManager.default.fileExists(atPath: extraURL.path))
  }

  @Test
  func initRefusesDangerousDestinations() throws {
    let initializer = PersonaKitInitializer()

    do {
      try initializer.run(destination: "")
      #expect(Bool(false))
    } catch {
      #expect(error as? InitError == .emptyPath)
    }

    do {
      try initializer.run(destination: "/")
      #expect(Bool(false))
    } catch {
      guard case InitError.disallowedPath(let path) = error else {
        #expect(Bool(false))
        return
      }
      #expect(path == "/")
    }

    let homePath = FileManager.default.homeDirectoryForCurrentUser.path
    do {
      try initializer.run(destination: homePath)
      #expect(Bool(false))
    } catch {
      guard case InitError.disallowedPath(let path) = error else {
        #expect(Bool(false))
        return
      }
      #expect(path == homePath)
    }
  }
}
