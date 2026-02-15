import Foundation
import Testing

@testable import PersonaKitStudio

struct WorkspaceSessionManagerTests {
  @Test
  func saveRejectsUnsafeSessionID() throws {
    let manager = WorkspaceSessionManager()

    do {
      _ = try manager.saveSession(
        workspaceURL: URL(fileURLWithPath: "/Workspace"),
        draft: WorkspaceSessionDraft(
          id: "../escape",
          personaId: "persona-a",
          directiveId: "directive-a",
          kitOverrides: []
        ),
        originalSessionID: nil,
        validPersonaIDs: Set(["persona-a"]),
        validDirectiveIDs: Set(["directive-a"]),
        validKitIDs: []
      )
      #expect(Bool(false))
    } catch let error as WorkspaceSessionManagerError {
      if case .invalidSessionIDFormat(let value) = error {
        #expect(value == "../escape")
      } else {
        #expect(Bool(false))
      }
    }
  }

  @Test
  func saveReturnsCanonicalTrimmedSessionID() throws {
    let workspaceURL = try makeTempDirectory()
    let projectScopeURL = workspaceURL.appendingPathComponent(".personakit")
    let packsURL = projectScopeURL.appendingPathComponent("Packs")

    try FileManager.default.createDirectory(
      at: packsURL,
      withIntermediateDirectories: true
    )

    let manager = WorkspaceSessionManager()
    let savedID = try manager.saveSession(
      workspaceURL: workspaceURL,
      draft: WorkspaceSessionDraft(
        id: "  session-a  ",
        personaId: "persona-a",
        directiveId: "directive-a",
        kitOverrides: ["kit-b", "kit-a", "kit-b"]
      ),
      originalSessionID: nil,
      validPersonaIDs: Set(["persona-a"]),
      validDirectiveIDs: Set(["directive-a"]),
      validKitIDs: Set(["kit-a", "kit-b"])
    )

    #expect(savedID == "session-a")

    let sessionURL = projectScopeURL.appendingPathComponent("Sessions/session-a.session.json")
    #expect(FileManager.default.fileExists(atPath: sessionURL.path()))

    let sessionData = try Data(contentsOf: sessionURL)
    let sessionJSON = try JSONSerialization.jsonObject(with: sessionData) as? [String: Any]

    #expect(sessionJSON?["id"] as? String == "session-a")
    #expect(sessionJSON?["personaId"] as? String == "persona-a")
    #expect(sessionJSON?["directiveId"] as? String == "directive-a")
    #expect(sessionJSON?["kitOverrides"] as? [String] == ["kit-a", "kit-b"])
  }

  @Test
  func renameRollsBackDestinationWhenSourceDeletionFails() throws {
    let workspaceURL = try makeTempDirectory()
    let projectScopeURL = workspaceURL.appendingPathComponent(".personakit")
    let packsURL = projectScopeURL.appendingPathComponent("Packs")
    let sessionsURL = projectScopeURL.appendingPathComponent("Sessions")
    let sourceURL = sessionsURL.appendingPathComponent("session-old.session.json")
    let destinationURL = sessionsURL.appendingPathComponent("session-new.session.json")

    try FileManager.default.createDirectory(
      at: packsURL,
      withIntermediateDirectories: true
    )
    try FileManager.default.createDirectory(
      at: sessionsURL,
      withIntermediateDirectories: true
    )
    try Data(
      """
      {
        "id" : "session-old",
        "personaId" : "persona-a",
        "directiveId" : "directive-a"
      }
      """.utf8
    )
    .write(to: sourceURL, options: [.atomic])

    let dependencies = WorkspaceSessionManagerDependencies(
      directoryExists: { url in
        var isDirectory: ObjCBool = false

        return FileManager.default.fileExists(atPath: url.path(), isDirectory: &isDirectory)
          && isDirectory.boolValue
      },
      createDirectory: { url in
        try FileManager.default.createDirectory(
          at: url,
          withIntermediateDirectories: true
        )
      },
      fileExists: { url in
        FileManager.default.fileExists(atPath: url.path())
      },
      readData: { url in
        try Data(contentsOf: url)
      },
      writeData: { data, url in
        try data.write(to: url, options: [.atomic])
      },
      removeItem: { url in
        if url.standardizedFileURL == sourceURL.standardizedFileURL {
          throw NSError(domain: "WorkspaceSessionManagerTests", code: 1)
        }

        try FileManager.default.removeItem(at: url)
      }
    )
    let manager = WorkspaceSessionManager(dependencies: dependencies)

    do {
      _ = try manager.saveSession(
        workspaceURL: workspaceURL,
        draft: WorkspaceSessionDraft(
          id: "session-new",
          personaId: "persona-a",
          directiveId: "directive-a",
          kitOverrides: []
        ),
        originalSessionID: "session-old",
        validPersonaIDs: Set(["persona-a"]),
        validDirectiveIDs: Set(["directive-a"]),
        validKitIDs: []
      )
      #expect(Bool(false))
    } catch let error as WorkspaceSessionManagerError {
      if case .saveFailed(let message) = error {
        #expect(message.contains("Rename cleanup failed"))
      } else {
        #expect(Bool(false))
      }
    }

    #expect(FileManager.default.fileExists(atPath: sourceURL.path()))
    #expect(!FileManager.default.fileExists(atPath: destinationURL.path()))
  }

  @Test
  func saveRejectsUnknownKitOverrideID() throws {
    let manager = WorkspaceSessionManager()

    do {
      _ = try manager.saveSession(
        workspaceURL: URL(fileURLWithPath: "/Workspace"),
        draft: WorkspaceSessionDraft(
          id: "session-a",
          personaId: "persona-a",
          directiveId: "directive-a",
          kitOverrides: ["missing-kit"]
        ),
        originalSessionID: nil,
        validPersonaIDs: Set(["persona-a"]),
        validDirectiveIDs: Set(["directive-a"]),
        validKitIDs: Set(["kit-a"])
      )
      #expect(Bool(false))
    } catch let error as WorkspaceSessionManagerError {
      if case .invalidKitOverrideID(let kitID) = error {
        #expect(kitID == "missing-kit")
      } else {
        #expect(Bool(false))
      }
    }
  }
}
