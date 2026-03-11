import Foundation
import Testing

@testable import ContextCLI
@testable import ContextCore

struct WorkstreamDocsCommandTests {
  @Test
  func writeRegeneratesExpectedDocs() throws {
    let fixture = try makeWorkstreamDocsProjectFixture()
    let expected = try WorkstreamDocsBuilder.buildOutput(
      root: fixture.personaKitRoot,
      currentSessionDirectory: fixture.sessionDirectoryTemplate
    )
    let cli = PersonaKitCLI()

    var status: Int32 = 0
    _ = captureStdout {
      status = cli.run(arguments: [
        "personakit",
        "workstream-docs",
        "--root",
        fixture.personaKitRoot.path,
        "--write",
      ])
    }

    #expect(status == 0)
    let workstreamDirectory = try String(
      contentsOf: fixture.workstreamDirectoryURL,
      encoding: .utf8
    )
    let sessionDirectory = try String(
      contentsOf: fixture.sessionDirectoryURL,
      encoding: .utf8
    )
    #expect(
      normalizedTrailingNewline(workstreamDirectory)
        == normalizedTrailingNewline(expected.workstreamDirectory)
    )
    #expect(
      normalizedTrailingNewline(sessionDirectory)
        == normalizedTrailingNewline(expected.sessionDirectory)
    )
  }

  @Test
  func writeIsNoOpWhenDocsAreCurrent() throws {
    let fixture = try makeWorkstreamDocsProjectFixture()
    let expected = try WorkstreamDocsBuilder.buildOutput(
      root: fixture.personaKitRoot,
      currentSessionDirectory: fixture.sessionDirectoryTemplate
    )
    try expected.workstreamDirectory.write(
      to: fixture.workstreamDirectoryURL,
      atomically: true,
      encoding: .utf8
    )
    try expected.sessionDirectory.write(
      to: fixture.sessionDirectoryURL,
      atomically: true,
      encoding: .utf8
    )

    let before = try snapshotFiles(at: fixture.projectRoot)
    let cli = PersonaKitCLI()

    var status: Int32 = 0
    _ = captureStdout {
      status = cli.run(arguments: [
        "personakit",
        "workstream-docs",
        "--root",
        fixture.personaKitRoot.path,
        "--write",
      ])
    }

    let after = try snapshotFiles(at: fixture.projectRoot)
    #expect(status == 0)
    #expect(before == after)
  }

  @Test
  func checkPassesWhenDocsAreCurrent() throws {
    let fixture = try makeWorkstreamDocsProjectFixture()
    let expected = try WorkstreamDocsBuilder.buildOutput(
      root: fixture.personaKitRoot,
      currentSessionDirectory: fixture.sessionDirectoryTemplate
    )
    try expected.workstreamDirectory.write(
      to: fixture.workstreamDirectoryURL,
      atomically: true,
      encoding: .utf8
    )
    try expected.sessionDirectory.write(
      to: fixture.sessionDirectoryURL,
      atomically: true,
      encoding: .utf8
    )
    let cli = PersonaKitCLI()

    var status: Int32 = 0
    let stderrOutput = captureStderr {
      status = cli.run(arguments: [
        "personakit",
        "workstream-docs",
        "--root",
        fixture.personaKitRoot.path,
        "--check",
      ])
    }

    #expect(status == 0)
    #expect(!stderrOutput.contains("Drift detected:"))
  }

  @Test
  func checkFailsWhenDocsDrift() throws {
    let fixture = try makeWorkstreamDocsProjectFixture()
    let cli = PersonaKitCLI()

    var status: Int32 = 0
    let stderrOutput = captureStderr {
      status = cli.run(arguments: [
        "personakit",
        "workstream-docs",
        "--root",
        fixture.personaKitRoot.path,
        "--check",
      ])
    }

    #expect(status == 1)
    #expect(
      stderrOutput.contains(WorkstreamDocsBuilder.workstreamDirectoryRelativePath)
    )
    #expect(
      stderrOutput.contains(WorkstreamDocsBuilder.sessionDirectoryRelativePath)
    )
  }

  @Test
  func checkFailsOnInconsistentWorkstreamDefinitions() throws {
    let fixture = try makeWorkstreamDocsProjectFixture()
    let conflictingWorkstream = Directive.Workstream(
      id: "style-workstream",
      phase: "followup",
      entrySessionId: "style-followup",
      requiredCloseoutSessionId: "style-closeout",
      nodes: makeValidFixtureWorkstream().nodes,
      edges: makeValidFixtureWorkstream().edges
    )
    try writeDirective(
      id: "z-conflicting-followup",
      title: "Conflicting followup",
      root: fixture.personaKitRoot,
      workstream: conflictingWorkstream
    )
    let cli = PersonaKitCLI()

    var status: Int32 = 0
    let stdoutOutput = captureStdout {
      status = cli.run(arguments: [
        "personakit",
        "workstream-docs",
        "--root",
        fixture.personaKitRoot.path,
        "--check",
      ])
    }

    #expect(status == 1)
    #expect(stdoutOutput.contains("Validation summary:"))
    #expect(stdoutOutput.contains("style-workstream"))
    #expect(stdoutOutput.contains("z-conflicting-followup"))
  }

  @Test
  func commandRejectsMissingOrConflictingModeFlags() {
    let cli = PersonaKitCLI()
    let root = "/tmp/project/.personakit"

    var missingStatus: Int32 = 0
    let missingOutput = captureStderr {
      missingStatus = cli.run(arguments: [
        "personakit",
        "workstream-docs",
        "--root",
        root,
      ])
    }

    var conflictingStatus: Int32 = 0
    let conflictingOutput = captureStderr {
      conflictingStatus = cli.run(arguments: [
        "personakit",
        "workstream-docs",
        "--root",
        root,
        "--write",
        "--check",
      ])
    }

    #expect(missingStatus == 1)
    #expect(conflictingStatus == 1)
    #expect(missingOutput.contains("exactly one of --write or --check"))
    #expect(conflictingOutput.contains("exactly one of --write or --check"))
  }

  @Test
  func commandRejectsInvalidRootUsage() throws {
    let root = try makeTempDirectory()
    let cli = PersonaKitCLI()

    var status: Int32 = 0
    let stderrOutput = captureStderr {
      status = cli.run(arguments: [
        "personakit",
        "workstream-docs",
        "--root",
        root.path,
        "--check",
      ])
    }

    #expect(status == 1)
    #expect(stderrOutput.contains("project .personakit directory"))
  }
}

private struct WorkstreamDocsProjectFixture {
  let projectRoot: URL
  let personaKitRoot: URL
  let workstreamDirectoryURL: URL
  let sessionDirectoryURL: URL
  let sessionDirectoryTemplate: String
}

private func makeWorkstreamDocsProjectFixture() throws -> WorkstreamDocsProjectFixture {
  let projectRoot = try makeTempDirectory().appendingPathComponent("Project")
  let personaKitRoot = projectRoot.appendingPathComponent(".personakit")
  try FileManager.default.createDirectory(
    at: projectRoot,
    withIntermediateDirectories: true
  )
  try copyFixtureKit(to: personaKitRoot)
  try installWorkstreamFixture(into: personaKitRoot)

  let developmentDirectory = projectRoot.appendingPathComponent("Docs/PersonaKit/Development")
  try FileManager.default.createDirectory(
    at: developmentDirectory,
    withIntermediateDirectories: true
  )

  let workstreamDirectoryURL = developmentDirectory.appendingPathComponent(
    "workstream-directory.md"
  )
  let sessionDirectoryURL = developmentDirectory.appendingPathComponent(
    "session-directory.md"
  )

  let sessionDirectoryTemplate = """
    # Session Directory

    Status: Active  
    Owner: AJ  
    Last Reviewed: 2026-03-11

    ## Purpose

    Manual content stays here.

    ## State Summary

    - `active`: 3 sessions

    <!-- WORKSTREAM_MEMBERSHIP:START -->
    ## Workstream Membership

    old
    <!-- WORKSTREAM_MEMBERSHIP:END -->
    """

  try "# Placeholder\n".write(
    to: workstreamDirectoryURL,
    atomically: true,
    encoding: .utf8
  )
  try sessionDirectoryTemplate.write(
    to: sessionDirectoryURL,
    atomically: true,
    encoding: .utf8
  )

  return WorkstreamDocsProjectFixture(
    projectRoot: projectRoot,
    personaKitRoot: personaKitRoot,
    workstreamDirectoryURL: workstreamDirectoryURL,
    sessionDirectoryURL: sessionDirectoryURL,
    sessionDirectoryTemplate: sessionDirectoryTemplate
  )
}
