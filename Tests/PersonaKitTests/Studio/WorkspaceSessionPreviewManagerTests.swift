import Foundation
import PersonaKitCore
import Testing

@testable import PersonaKitStudio

struct WorkspaceSessionPreviewManagerTests {
  @Test
  func loadPreviewBuildsUsingResolvedScopesAndDraft() throws {
    let workspaceURL = URL(fileURLWithPath: "/Workspace")
    let session = WorkspaceSessionListItem(
      id: "session-a",
      personaId: "unused",
      directiveId: "unused",
      fileURL: URL(fileURLWithPath: "/Workspace/.personakit/Sessions/session-a.session.json"),
      sourceScope: .project
    )

    let manager = WorkspaceSessionPreviewManager(
      sessionManager: StubPreviewSessionManager(
        loadDraftHandler: { _ in
          WorkspaceSessionDraft(
            id: "session-a",
            personaId: "persona-a",
            directiveId: "directive-a",
            kitOverrides: ["kit-b", "kit-a"]
          )
        }
      ),
      previewBuilder: StubPreviewBuilder { projectScopeURL, globalScopeURL, personaId, directiveId, kitOverrides in
        [
          projectScopeURL.path(),
          globalScopeURL?.path() ?? "nil",
          personaId,
          directiveId,
          kitOverrides.joined(separator: ","),
        ]
        .joined(separator: "|")
      },
      dependencies: WorkspaceSessionPreviewManagerDependencies(
        directoryExists: { url in
          url.path() == "/Workspace/.personakit/Packs"
        },
        defaultGlobalScopeURL: {
          URL(fileURLWithPath: "/Users/test/.personakit")
        },
        createDirectory: { _ in },
        writeData: { _, _ in }
      )
    )

    let preview = try manager.loadPreview(
      workspaceURL: workspaceURL,
      session: session
    )

    #expect(
      preview
        == "/Workspace/.personakit|/Users/test/.personakit|persona-a|directive-a|kit-b,kit-a"
    )
  }

  @Test
  func loadPreviewFailsWhenProjectPersonaKitDirectoryMissing() throws {
    let workspaceURL = URL(fileURLWithPath: "/Workspace")
    let session = WorkspaceSessionListItem(
      id: "session-a",
      personaId: "unused",
      directiveId: "unused",
      fileURL: URL(fileURLWithPath: "/Workspace/.personakit/Sessions/session-a.session.json"),
      sourceScope: .project
    )

    let manager = WorkspaceSessionPreviewManager(
      sessionManager: StubPreviewSessionManager(
        loadDraftHandler: { _ in
          WorkspaceSessionDraft(
            id: "session-a",
            personaId: "persona-a",
            directiveId: "directive-a",
            kitOverrides: []
          )
        }
      ),
      previewBuilder: StubPreviewBuilder { _, _, _, _, _ in
        "unused"
      },
      dependencies: WorkspaceSessionPreviewManagerDependencies(
        directoryExists: { _ in
          false
        },
        defaultGlobalScopeURL: {
          nil
        },
        createDirectory: { _ in },
        writeData: { _, _ in }
      )
    )

    do {
      _ = try manager.loadPreview(
        workspaceURL: workspaceURL,
        session: session
      )
      #expect(Bool(false))
    } catch let error as WorkspaceSnapshotBuildError {
      #expect(error.message.contains("Missing PersonaKit directory"))
    }
  }

  @Test
  func exportPreviewWritesMarkdownUsingInjectedDependencies() throws {
    let destinationURL = URL(fileURLWithPath: "/Exports/session-a.md")
    let previewText = "preview-body"

    let manager = WorkspaceSessionPreviewManager(
      sessionManager: StubPreviewSessionManager(
        loadDraftHandler: { _ in
          WorkspaceSessionDraft(
            id: "session-a",
            personaId: "persona-a",
            directiveId: "directive-a",
            kitOverrides: []
          )
        }
      ),
      previewBuilder: StubPreviewBuilder { _, _, _, _, _ in
        previewText
      },
      dependencies: WorkspaceSessionPreviewManagerDependencies(
        directoryExists: { _ in
          true
        },
        defaultGlobalScopeURL: {
          nil
        },
        createDirectory: { url in
          guard url == destinationURL.deletingLastPathComponent() else {
            throw NSError(domain: "WorkspaceSessionPreviewManagerTests", code: 1)
          }
        },
        writeData: { data, url in
          guard url == destinationURL else {
            throw NSError(domain: "WorkspaceSessionPreviewManagerTests", code: 2)
          }

          guard data == Data(previewText.utf8) else {
            throw NSError(domain: "WorkspaceSessionPreviewManagerTests", code: 3)
          }
        }
      )
    )

    try manager.exportPreview(previewText, to: destinationURL)
  }

  @Test
  func exportPreviewWrapsWriteFailures() throws {
    let destinationURL = URL(fileURLWithPath: "/Exports/session-a.md")

    let manager = WorkspaceSessionPreviewManager(
      sessionManager: StubPreviewSessionManager(
        loadDraftHandler: { _ in
          WorkspaceSessionDraft(
            id: "session-a",
            personaId: "persona-a",
            directiveId: "directive-a",
            kitOverrides: []
          )
        }
      ),
      previewBuilder: StubPreviewBuilder { _, _, _, _, _ in
        "unused"
      },
      dependencies: WorkspaceSessionPreviewManagerDependencies(
        directoryExists: { _ in
          true
        },
        defaultGlobalScopeURL: {
          nil
        },
        createDirectory: { _ in },
        writeData: { _, _ in
          throw NSError(domain: "WorkspaceSessionPreviewManagerTests", code: 42)
        }
      )
    )

    do {
      try manager.exportPreview("preview", to: destinationURL)
      #expect(Bool(false))
    } catch let error as WorkspaceSnapshotBuildError {
      #expect(error.message.contains("Failed to export preview"))
    }
  }
}

private struct StubPreviewSessionManager: WorkspaceSessionManaging, Sendable {
  let loadDraftHandler: @Sendable (URL) throws -> WorkspaceSessionDraft

  func loadDraft(fileURL: URL) throws -> WorkspaceSessionDraft {
    try loadDraftHandler(fileURL)
  }

  func saveSession(
    workspaceURL: URL,
    draft: WorkspaceSessionDraft,
    originalSessionID: String?,
    validPersonaIDs: Set<String>,
    validDirectiveIDs: Set<String>,
    validKitIDs: Set<String>
  ) throws -> String {
    "unused"
  }

  func deleteSession(
    workspaceURL: URL,
    sessionID: String
  ) throws {}
}

private struct StubPreviewBuilder: WorkspaceSessionPreviewBuilding, Sendable {
  let buildHandler: @Sendable (URL, URL?, String, String, [String]) throws -> String

  func build(
    projectScopeURL: URL,
    globalScopeURL: URL?,
    personaId: String,
    directiveId: String,
    kitOverrides: [String]
  ) throws -> String {
    try buildHandler(
      projectScopeURL,
      globalScopeURL,
      personaId,
      directiveId,
      kitOverrides
    )
  }
}
