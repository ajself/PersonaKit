import Foundation
import Testing

@testable import ContextCore

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
  func rejectsUnsafeSessionPathSegments() throws {
    let root = try makeTempDirectory()
    let unsafeIds = [
      ".",
      "..",
      "nested/name",
      "nested\\name",
    ]

    for unsafeId in unsafeIds {
      do {
        _ = try SessionFileLoader.load(root: root, sessionId: unsafeId)
        #expect(Bool(false))
      } catch let error as SessionFileError {
        if case .invalidSessionPath(let path) = error {
          #expect(path == "Sessions/<invalid>.session.json")
          continue
        }

        #expect(Bool(false))
      }
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
  func rejectsEscapingSessionIDWithoutReadingEscapedFile() throws {
    let root = try makeTempDirectory()
    let escapedURL = root.appendingPathComponent("escaped.session.json")
    let escapedJSON = """
      {
        "id": "../escaped",
        "personaId": "escaped-persona",
        "directiveId": "escaped-directive"
      }
      """

    try Data(escapedJSON.utf8).write(to: escapedURL, options: .atomic)

    do {
      _ = try SessionFileLoader.load(root: root, sessionId: "../escaped")
      #expect(Bool(false))
    } catch let error as SessionFileError {
      if case .invalidSessionPath(let path) = error {
        #expect(path == "Sessions/<invalid>.session.json")
        return
      }

      #expect(Bool(false))
    }
  }

  @Test
  func rejectsEscapingSessionSymlinkWithoutReadingTarget() throws {
    let root = try makeTempDirectory()
    let sessionsDirectory = root.appendingPathComponent("Sessions")
    let outsideURL = try makeTempDirectory().appendingPathComponent("linked.session.json")
    let symlinkURL = sessionsDirectory.appendingPathComponent("linked.session.json")
    let escapedJSON = """
      {
        "id": "linked",
        "personaId": "escaped-persona",
        "directiveId": "escaped-directive"
      }
      """

    try FileManager.default.createDirectory(
      at: sessionsDirectory,
      withIntermediateDirectories: true
    )
    try Data(escapedJSON.utf8).write(to: outsideURL, options: .atomic)
    try FileManager.default.createSymbolicLink(
      at: symlinkURL,
      withDestinationURL: outsideURL
    )

    #expect(
      try SessionFileLoader.discoveredSessionIDs(scopes: ScopeSet(projectScopeURL: root, globalScopeURL: nil)).isEmpty
    )

    do {
      _ = try SessionFileLoader.load(root: root, sessionId: "linked")
      #expect(Bool(false))
    } catch let error as SessionFileError {
      if case .invalidSessionPath(let path) = error {
        #expect(path == "Sessions/linked.session.json")
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

  @Test
  func loadsSessionDirectlyFromFileURL() throws {
    let root = try makeTempDirectory()
    let sessionId = "direct-file"

    try writeSessionFile(
      root: root,
      sessionId: sessionId,
      fileID: sessionId,
      personaId: "persona",
      directiveId: "directive"
    )

    let fileURL = root.appendingPathComponent("Sessions/\(sessionId).session.json")
    let session = try SessionFileLoader.load(fileURL: fileURL)

    #expect(session.id == sessionId)
    #expect(session.personaId == "persona")
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
