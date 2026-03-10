import Foundation
import Testing

@testable import ContextCore

struct SessionReferenceResolverTests {
  @Test
  func resolvesSessionIDToProjectScopeFile() throws {
    let root = try makeTempDirectory()
    let project = root.appendingPathComponent("project/.personakit")

    try writeSessionFile(
      root: project,
      sessionId: "reviewable",
      fileID: "reviewable",
      personaId: "persona",
      directiveId: "directive"
    )

    let scopes = ScopeSet(projectScopeURL: project, globalScopeURL: nil)
    let resolved = try SessionReferenceResolver.resolve(
      scopes: scopes,
      sessionRef: "reviewable"
    )

    #expect(resolved.sourceRefType == .id)
    #expect(resolved.sessionId == "reviewable")
    #expect(resolved.resolvedPath.hasSuffix("Sessions/reviewable.session.json"))
  }

  @Test
  func resolvesScopeRelativeSessionPath() throws {
    let root = try makeTempDirectory()
    let project = root.appendingPathComponent("project/.personakit")

    try writeSessionFile(
      root: project,
      sessionId: "reviewable",
      fileID: "reviewable",
      personaId: "persona",
      directiveId: "directive"
    )

    let scopes = ScopeSet(projectScopeURL: project, globalScopeURL: nil)
    let resolved = try SessionReferenceResolver.resolve(
      scopes: scopes,
      sessionRef: "Sessions/reviewable.session.json"
    )

    #expect(resolved.sourceRefType == .path)
    #expect(resolved.sessionId == "reviewable")
  }

  @Test
  func resolvesRepoRelativePersonaKitPath() throws {
    let root = try makeTempDirectory()
    let workspace = root.appendingPathComponent("Workspace")
    let project = workspace.appendingPathComponent(".personakit")

    try writeSessionFile(
      root: project,
      sessionId: "reviewable",
      fileID: "reviewable",
      personaId: "persona",
      directiveId: "directive"
    )

    let scopes = ScopeSet(projectScopeURL: project, globalScopeURL: nil)
    let resolved = try SessionReferenceResolver.resolve(
      scopes: scopes,
      sessionRef: ".personakit/Sessions/reviewable.session.json"
    )

    #expect(resolved.sourceRefType == .path)
    #expect(resolved.sessionId == "reviewable")
  }
}

private func writeSessionFile(
  root: URL,
  sessionId: String,
  fileID: String,
  personaId: String,
  directiveId: String
) throws {
  let sessionsDirectory = root.appendingPathComponent("Sessions")
  let fileURL = sessionsDirectory.appendingPathComponent("\(sessionId).session.json")
  let json = """
    {
      "id": "\(fileID)",
      "personaId": "\(personaId)",
      "directiveId": "\(directiveId)"
    }
    """

  try FileManager.default.createDirectory(at: sessionsDirectory, withIntermediateDirectories: true)
  try Data(json.utf8).write(to: fileURL, options: .atomic)
}
