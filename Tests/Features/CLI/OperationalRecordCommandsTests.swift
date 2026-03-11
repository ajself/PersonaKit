import Foundation
import Testing

@testable import ContextCLI
@testable import ContextCore

struct OperationalRecordCommandsTests {
  @Test
  func migrateWriteRegeneratesCanonicalJSONL() throws {
    let fixture = try makeOperationalRecordsProjectFixture(
      seedCanonicalRecords: false
    )
    let expected = try OperationalRecordBuilder.buildMigrationOutput(
      root: fixture.personaKitRoot
    )
    let cli = PersonaKitCLI()

    var status: Int32 = 0
    _ = captureStdout {
      status = cli.run(arguments: [
        "personakit",
        "migrate-log-records",
        "--root",
        fixture.personaKitRoot.path,
        "--write",
      ])
    }

    #expect(status == 0)
    for relativePath in expected.files.keys.sorted() {
      let contents = try String(
        contentsOf: fixture.projectRoot.appendingPathComponent(relativePath),
        encoding: .utf8
      )
      #expect(
        normalizedTrailingNewline(contents)
          == normalizedTrailingNewline(expected.files[relativePath] ?? "")
      )
    }
  }

  @Test
  func migrateCheckFailsWhenCanonicalJSONLDrifts() throws {
    let fixture = try makeOperationalRecordsProjectFixture(
      seedCanonicalRecords: false
    )
    try "[]\n".write(
      to: fixture.projectRoot.appendingPathComponent(
        OperationalRecordBuilder.partnerContextEventsRelativePath
      ),
      atomically: true,
      encoding: .utf8
    )
    let cli = PersonaKitCLI()

    var status: Int32 = 0
    let stderrOutput = captureStderr {
      status = cli.run(arguments: [
        "personakit",
        "migrate-log-records",
        "--root",
        fixture.personaKitRoot.path,
        "--check",
      ])
    }

    #expect(status == 1)
    #expect(
      stderrOutput.contains(OperationalRecordBuilder.partnerContextEventsRelativePath)
    )
  }

  @Test
  func logDocsWriteRegeneratesProjectionDocs() throws {
    let fixture = try makeOperationalRecordsProjectFixture()
    let expected = try OperationalRecordBuilder.buildDocsOutput(
      root: fixture.personaKitRoot
    )
    let cli = PersonaKitCLI()

    var status: Int32 = 0
    _ = captureStdout {
      status = cli.run(arguments: [
        "personakit",
        "log-docs",
        "--root",
        fixture.personaKitRoot.path,
        "--write",
      ])
    }

    #expect(status == 0)
    for relativePath in expected.files.keys.sorted() {
      let contents = try String(
        contentsOf: fixture.projectRoot.appendingPathComponent(relativePath),
        encoding: .utf8
      )
      #expect(
        normalizedTrailingNewline(contents)
          == normalizedTrailingNewline(expected.files[relativePath] ?? "")
      )
    }
  }

  @Test
  func migrateCommandRejectsGeneratedProjectionDocs() throws {
    let fixture = try makeOperationalRecordsProjectFixture()
    let cli = PersonaKitCLI()

    var writeStatus: Int32 = 0
    _ = captureStdout {
      writeStatus = cli.run(arguments: [
        "personakit",
        "log-docs",
        "--root",
        fixture.personaKitRoot.path,
        "--write",
      ])
    }

    var migrateStatus: Int32 = 0
    let migrateOutput = captureStderr {
      migrateStatus = cli.run(arguments: [
        "personakit",
        "migrate-log-records",
        "--root",
        fixture.personaKitRoot.path,
        "--check",
      ])
    }

    #expect(writeStatus == 0)
    #expect(migrateStatus == 1)
    #expect(migrateOutput.contains("legacy markdown ledgers"))
  }

  @Test
  func commandsRejectMissingOrConflictingModeFlags() {
    let cli = PersonaKitCLI()
    let root = "/tmp/project/.personakit"

    var migrateStatus: Int32 = 0
    let migrateOutput = captureStderr {
      migrateStatus = cli.run(arguments: [
        "personakit",
        "migrate-log-records",
        "--root",
        root,
      ])
    }

    var docsStatus: Int32 = 0
    let docsOutput = captureStderr {
      docsStatus = cli.run(arguments: [
        "personakit",
        "log-docs",
        "--root",
        root,
        "--write",
        "--check",
      ])
    }

    #expect(migrateStatus == 1)
    #expect(docsStatus == 1)
    #expect(
      migrateOutput.contains("migrate-log-records requires exactly one of --write or --check")
    )
    #expect(
      docsOutput.contains("log-docs requires exactly one of --write or --check")
    )
  }
}
