import ContextCore
import ContextWorkspaceCore
import Foundation
import StudioFoundation
import Testing

struct WorkspaceSessionDiagnosticsTests {
  @Test
  func validateSessionsReportsDecodeFilenameAndReferenceIssues() throws {
    let workspaceURL = try makeTempDirectory()
    let sessionsDirectory = workspaceURL.appendingPathComponent(".personakit/Sessions")

    try FileManager.default.createDirectory(
      at: sessionsDirectory,
      withIntermediateDirectories: true
    )

    let invalidJSONURL = sessionsDirectory.appendingPathComponent("broken.session.json")
    let mismatchedFilenameURL = sessionsDirectory.appendingPathComponent("mismatch.session.json")
    let missingReferencesURL = sessionsDirectory.appendingPathComponent("refs.session.json")

    try Data("{not-json".utf8).write(to: invalidJSONURL, options: [.atomic])
    try Data(
      """
      {
        "directiveId" : "directive-a",
        "id" : "actual-id",
        "personaId" : "persona-a"
      }
      """.utf8
    )
    .write(to: mismatchedFilenameURL, options: [.atomic])
    try Data(
      """
      {
        "directiveId" : "missing-directive",
        "id" : "refs",
        "kitOverrides" : [
          "kit-a",
          "missing-kit"
        ],
        "personaId" : "missing-persona"
      }
      """.utf8
    )
    .write(to: missingReferencesURL, options: [.atomic])

    let snapshot = WorkspaceSnapshot(
      sessions: [
        WorkspaceSessionListItem(
          id: "broken",
          personaId: "persona-a",
          directiveId: "directive-a",
          fileURL: invalidJSONURL,
          sourceScope: .project
        ),
        WorkspaceSessionListItem(
          id: "actual-id",
          personaId: "persona-a",
          directiveId: "directive-a",
          fileURL: mismatchedFilenameURL,
          sourceScope: .project
        ),
        WorkspaceSessionListItem(
          id: "refs",
          personaId: "missing-persona",
          directiveId: "missing-directive",
          fileURL: missingReferencesURL,
          sourceScope: .project
        ),
      ],
      personas: [
        WorkspaceListItem(
          id: "persona-a",
          displayName: "Persona A",
          fileURL: URL(fileURLWithPath: "/unused/persona-a.persona.json"),
          sourceScope: .project
        )
      ],
      directives: [
        WorkspaceListItem(
          id: "directive-a",
          displayName: "Directive A",
          fileURL: URL(fileURLWithPath: "/unused/directive-a.directive.json"),
          sourceScope: .project
        )
      ],
      kits: [
        WorkspaceListItem(
          id: "kit-a",
          displayName: "Kit A",
          fileURL: URL(fileURLWithPath: "/unused/kit-a.kit.json"),
          sourceScope: .project
        )
      ],
      skills: [],
      essentials: []
    )

    let issues = WorkspaceSessionDiagnostics.validateSessions(
      workspaceURL: workspaceURL,
      snapshot: snapshot
    )
    let hasDecodeIssue = issues.contains(where: { issue in
      issue.entityId == "broken"
        && issue.field == "json"
        && issue.message.hasPrefix("Failed to decode session JSON:")
    })
    let hasFilenameMismatchIssue = issues.contains(where: { issue in
      issue.entityId == "actual-id"
        && issue.field == "id"
        && issue.message == "Session id does not match filename."
    })
    let hasMissingPersonaIssue = issues.contains(where: { issue in
      issue.entityId == "refs"
        && issue.field == "personaId"
        && issue.message.contains("missing persona id")
    })
    let hasMissingDirectiveIssue = issues.contains(where: { issue in
      issue.entityId == "refs"
        && issue.field == "directiveId"
        && issue.message.contains("missing directive id")
    })
    let hasMissingKitIssue = issues.contains(where: { issue in
      issue.entityId == "refs"
        && issue.field == "kitOverrides"
        && issue.message.contains("\"missing-kit\"")
    })

    #expect(issues.count == 5)
    #expect(issues.allSatisfy { $0.entityType == .session })
    #expect(hasDecodeIssue)
    #expect(hasFilenameMismatchIssue)
    #expect(hasMissingPersonaIssue)
    #expect(hasMissingDirectiveIssue)
    #expect(hasMissingKitIssue)

    // Reference issues are tagged for the global-library banner; structural ones are not.
    let referenceFields = Set(
      issues.filter(\.referencesUnresolvedID).map(\.field)
    )
    #expect(referenceFields == ["personaId", "directiveId", "kitOverrides"])
    #expect(
      issues
        .filter { $0.field == "json" || $0.field == "id" }
        .allSatisfy { !$0.referencesUnresolvedID }
    )
  }

  @Test
  func validateSessionsIgnoresGlobalScopeAndMissingFiles() throws {
    let workspaceURL = try makeTempDirectory()
    let sessionsDirectory = workspaceURL.appendingPathComponent(".personakit/Sessions")

    try FileManager.default.createDirectory(
      at: sessionsDirectory,
      withIntermediateDirectories: true
    )

    let projectSessionURL = sessionsDirectory.appendingPathComponent("project.session.json")
    let globalSessionURL = URL(fileURLWithPath: "/Global/.personakit/Sessions/global.session.json")
    let missingProjectSessionURL = sessionsDirectory.appendingPathComponent("missing.session.json")

    try Data(
      """
      {
        "directiveId" : "directive-a",
        "id" : "project",
        "kitOverrides" : [
          "kit-a"
        ],
        "personaId" : "persona-a"
      }
      """.utf8
    )
    .write(to: projectSessionURL, options: [.atomic])

    let snapshot = WorkspaceSnapshot(
      sessions: [
        WorkspaceSessionListItem(
          id: "project",
          personaId: "persona-a",
          directiveId: "directive-a",
          fileURL: projectSessionURL,
          sourceScope: .project
        ),
        WorkspaceSessionListItem(
          id: "missing",
          personaId: "persona-a",
          directiveId: "directive-a",
          fileURL: missingProjectSessionURL,
          sourceScope: .project
        ),
        WorkspaceSessionListItem(
          id: "global",
          personaId: "missing-persona",
          directiveId: "missing-directive",
          fileURL: globalSessionURL,
          sourceScope: .global
        ),
      ],
      personas: [
        WorkspaceListItem(
          id: "persona-a",
          displayName: "Persona A",
          fileURL: URL(fileURLWithPath: "/unused/persona-a.persona.json"),
          sourceScope: .project
        )
      ],
      directives: [
        WorkspaceListItem(
          id: "directive-a",
          displayName: "Directive A",
          fileURL: URL(fileURLWithPath: "/unused/directive-a.directive.json"),
          sourceScope: .project
        )
      ],
      kits: [
        WorkspaceListItem(
          id: "kit-a",
          displayName: "Kit A",
          fileURL: URL(fileURLWithPath: "/unused/kit-a.kit.json"),
          sourceScope: .project
        )
      ],
      skills: [],
      essentials: []
    )

    let issues = WorkspaceSessionDiagnostics.validateSessions(
      workspaceURL: workspaceURL,
      snapshot: snapshot
    )

    #expect(issues.isEmpty)
  }
}
