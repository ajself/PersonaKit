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
    let publicStarterSnapshot = try snapshotFiles(at: publicStarterRootURL())
    let expectedPaths = Set(StarterKitManifest.entries.map { $0.relativePath })

    #expect(Set(snapshot.keys) == expectedPaths)
    #expect(snapshot == publicStarterSnapshot)

    for entry in StarterKitManifest.entries {
      #expect(snapshot[entry.relativePath] == entry.contents)
    }
  }

  @Test
  func initAllowsEmptyExistingDestination() throws {
    let destination = try makeTempDirectory().appendingPathComponent("PersonaKit")
    try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)

    try PersonaKitInitializer().run(destination: destination.path)

    let snapshot = try snapshotFiles(at: destination)
    let publicStarterSnapshot = try snapshotFiles(at: publicStarterRootURL())

    #expect(snapshot == publicStarterSnapshot)
  }

  @Test
  func initRefusesNonEmptyDestinationWithoutForce() throws {
    let destination = try makeTempDirectory().appendingPathComponent("PersonaKit")
    try PersonaKitInitializer().run(destination: destination.path)

    let firstSnapshot = try snapshotFiles(at: destination)
    let extraURL = destination.appendingPathComponent("extra.txt")
    try Data("extra".utf8).write(to: extraURL)

    do {
      try PersonaKitInitializer().run(destination: destination.path)
      #expect(Bool(false))
    } catch {
      guard case InitError.destinationExists(let path) = error else {
        #expect(Bool(false))
        return
      }
      #expect(path == destination.path)
    }

    #expect(try snapshotFiles(at: destination) != firstSnapshot)
    #expect(FileManager.default.fileExists(atPath: extraURL.path))
  }

  @Test
  func initForceIsDeterministicAndRemovesExtras() throws {
    let destination = try makeTempDirectory().appendingPathComponent("PersonaKit")
    try PersonaKitInitializer().run(destination: destination.path)

    let firstSnapshot = try snapshotFiles(at: destination)
    let extraURL = destination.appendingPathComponent("extra.txt")
    try Data("extra".utf8).write(to: extraURL)

    try PersonaKitInitializer().run(destination: destination.path, force: true)
    let secondSnapshot = try snapshotFiles(at: destination)

    #expect(firstSnapshot == secondSnapshot)
    #expect(!FileManager.default.fileExists(atPath: extraURL.path))
  }

  @Test
  func cliInitForceReplacesNonEmptyDestination() throws {
    let destination = try makeTempDirectory().appendingPathComponent("PersonaKit")
    try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
    try Data("extra".utf8).write(to: destination.appendingPathComponent("extra.txt"))

    var status: Int32 = 0
    let stderrOutput = captureStderr {
      status = PersonaKitCLI().run(arguments: [
        "personakit",
        "init",
        destination.path,
      ])
    }

    #expect(status == 1)
    #expect(stderrOutput.contains("without --force"))

    status = PersonaKitCLI().run(arguments: [
      "personakit",
      "init",
      destination.path,
      "--force",
    ])

    #expect(status == 0)
    #expect(try snapshotFiles(at: destination) == snapshotFiles(at: publicStarterRootURL()))
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
