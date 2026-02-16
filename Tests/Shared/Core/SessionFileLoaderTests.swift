import Foundation
import Testing

@testable import PersonaKitCore

struct SessionFileLoaderTests {
  @Test
  func rejectsEmptySessionIdForScopesLoad() throws {
    let scopes = ScopeSet(projectScopeURL: URL(fileURLWithPath: "/tmp"), globalScopeURL: nil)

    do {
      _ = try SessionFileLoader.load(scopes: scopes, sessionId: "   ")
      #expect(Bool(false))
    } catch let error as SessionFileError {
      if case .invalidSessionId = error {
        return
      }
      #expect(Bool(false))
    }
  }

  @Test
  func rejectsEmptySessionIdForRootLoad() throws {
    let root = try makeTempDirectory()

    do {
      _ = try SessionFileLoader.load(root: root, sessionId: "\n\t")
      #expect(Bool(false))
    } catch let error as SessionFileError {
      if case .invalidSessionId = error {
        return
      }
      #expect(Bool(false))
    }
  }

  @Test
  func reportsMissingSessionFile() throws {
    let root = try makeTempDirectory()

    do {
      _ = try SessionFileLoader.load(root: root, sessionId: "missing")
      #expect(Bool(false))
    } catch let error as SessionFileError {
      if case .notFound(let sessionId, let expectedPath) = error {
        #expect(sessionId == "missing")
        #expect(expectedPath == "Sessions/missing.session.json")
        return
      }
      #expect(Bool(false))
    }
  }

  @Test
  func reportsDecodeFailureForInvalidJSON() throws {
    let root = try makeTempDirectory()
    let sessionsDirectory = root.appendingPathComponent("Sessions")
    let sessionURL = sessionsDirectory.appendingPathComponent("bad.session.json")

    try FileManager.default.createDirectory(at: sessionsDirectory, withIntermediateDirectories: true)
    try Data("{not-json}".utf8).write(to: sessionURL, options: .atomic)

    do {
      _ = try SessionFileLoader.load(root: root, sessionId: "bad")
      #expect(Bool(false))
    } catch let error as SessionFileError {
      if case .decodeFailed(let sessionId, _) = error {
        #expect(sessionId == "bad")
        return
      }
      #expect(Bool(false))
    }
  }

  @Test
  func reportsIDMismatchWhenFileIDDiffersFromRequestedID() throws {
    let root = try makeTempDirectory()

    try writeSessionFile(
      root: root,
      sessionId: "requested",
      fileID: "actual-id",
      personaId: "persona",
      directiveId: "directive"
    )

    do {
      _ = try SessionFileLoader.load(root: root, sessionId: "requested")
      #expect(Bool(false))
    } catch let error as SessionFileError {
      if case .idMismatch(let sessionId, let actualId, let path) = error {
        #expect(sessionId == "requested")
        #expect(actualId == "actual-id")
        #expect(path == "Sessions/requested.session.json")
        return
      }
      #expect(Bool(false))
    }
  }

  @Test
  func prefersProjectScopeBeforeGlobalScope() throws {
    let root = try makeTempDirectory()
    let project = root.appendingPathComponent("project/.personakit")
    let global = root.appendingPathComponent("global/.personakit")
    let sessionId = "shared"

    try writeSessionFile(
      root: global,
      sessionId: sessionId,
      fileID: sessionId,
      personaId: "global-persona",
      directiveId: "global-directive"
    )
    try writeSessionFile(
      root: project,
      sessionId: sessionId,
      fileID: sessionId,
      personaId: "project-persona",
      directiveId: "project-directive"
    )

    let scopes = ScopeSet(projectScopeURL: project, globalScopeURL: global)
    let session = try SessionFileLoader.load(scopes: scopes, sessionId: sessionId)

    #expect(session.personaId == "project-persona")
    #expect(session.directiveId == "project-directive")
  }

  @Test
  func fallsBackToGlobalScopeWhenProjectMissingSession() throws {
    let root = try makeTempDirectory()
    let project = root.appendingPathComponent("project/.personakit")
    let global = root.appendingPathComponent("global/.personakit")
    let sessionId = "shared"

    try writeSessionFile(
      root: global,
      sessionId: sessionId,
      fileID: sessionId,
      personaId: "global-persona",
      directiveId: "global-directive"
    )

    let scopes = ScopeSet(projectScopeURL: project, globalScopeURL: global)
    let session = try SessionFileLoader.load(scopes: scopes, sessionId: sessionId)

    #expect(session.personaId == "global-persona")
    #expect(session.directiveId == "global-directive")
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
