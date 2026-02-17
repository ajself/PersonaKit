import ContextCore
import ContextWorkspaceCore
import Foundation
import StudioFoundation
import Testing

@testable import StudioFeatures

@MainActor
struct WorkspaceSessionFeatureModelMapTests {
  @Test
  func refreshPreviewSkipsDuplicateRequestForSameSession() async {
    let workspaceURL = URL(fileURLWithPath: "/Workspace")
    let session = WorkspaceSessionListItem(
      id: "session-a",
      personaId: "persona-a",
      directiveId: "directive-a",
      fileURL: URL(fileURLWithPath: "/Workspace/.personakit/Sessions/session-a.session.json"),
      sourceScope: .project
    )
    let model = WorkspaceSessionFeatureModel(
      operationRunner: makeOperationRunner(
        sessionManager: StubSessionManager { _ in
          WorkspaceSessionDraft(
            id: "unused",
            personaId: "unused",
            directiveId: "unused",
            kitOverrides: []
          )
        },
        sessionMapBuilder: StubSessionMapBuilder { _, _, _, _ in
          Self.makeMap(personaID: "unused")
        },
        sessionPreviewManager: StubSessionPreviewManager(
          loadPreviewHandler: { _, _ in
            Thread.sleep(forTimeInterval: 0.05)
            return "preview-text"
          }
        )
      ),
      previewExportDestinationPicker: StubPreviewDestinationPicker(),
      pasteboardWriter: StubPasteboardWriter()
    )

    model.refreshPreview(
      for: session,
      workspaceURL: workspaceURL
    )

    await waitFor {
      !model.isLoadingPreview && model.preview == "preview-text"
    }

    model.refreshPreview(
      for: session,
      workspaceURL: workspaceURL
    )

    #expect(model.preview == "preview-text")
    #expect(!model.isLoadingPreview)
  }

  @Test
  func refreshPreviewForceReloadBypassesCache() async {
    let workspaceURL = URL(fileURLWithPath: "/Workspace")
    let session = WorkspaceSessionListItem(
      id: "session-a",
      personaId: "persona-a",
      directiveId: "directive-a",
      fileURL: URL(fileURLWithPath: "/Workspace/.personakit/Sessions/session-a.session.json"),
      sourceScope: .project
    )
    let model = WorkspaceSessionFeatureModel(
      operationRunner: makeOperationRunner(
        sessionManager: StubSessionManager { _ in
          WorkspaceSessionDraft(
            id: "unused",
            personaId: "unused",
            directiveId: "unused",
            kitOverrides: []
          )
        },
        sessionMapBuilder: StubSessionMapBuilder { _, _, _, _ in
          Self.makeMap(personaID: "unused")
        },
        sessionPreviewManager: StubSessionPreviewManager(
          loadPreviewHandler: { _, _ in
            Thread.sleep(forTimeInterval: 0.05)
            return "preview-text"
          }
        )
      ),
      previewExportDestinationPicker: StubPreviewDestinationPicker(),
      pasteboardWriter: StubPasteboardWriter()
    )

    model.refreshPreview(
      for: session,
      workspaceURL: workspaceURL
    )

    await waitFor {
      !model.isLoadingPreview && model.preview == "preview-text"
    }

    model.refreshPreview(
      for: session,
      workspaceURL: workspaceURL,
      forceReload: true
    )

    #expect(model.isLoadingPreview)

    await waitFor {
      !model.isLoadingPreview
    }

    #expect(model.preview == "preview-text")
  }

  @Test
  func refreshPreviewRestartsAfterCancellationForSameSession() async {
    let workspaceURL = URL(fileURLWithPath: "/Workspace")
    let session = WorkspaceSessionListItem(
      id: "session-a",
      personaId: "persona-a",
      directiveId: "directive-a",
      fileURL: URL(fileURLWithPath: "/Workspace/.personakit/Sessions/session-a.session.json"),
      sourceScope: .project
    )
    let model = WorkspaceSessionFeatureModel(
      operationRunner: makeOperationRunner(
        sessionManager: StubSessionManager { _ in
          WorkspaceSessionDraft(
            id: "unused",
            personaId: "unused",
            directiveId: "unused",
            kitOverrides: []
          )
        },
        sessionMapBuilder: StubSessionMapBuilder { _, _, _, _ in
          Self.makeMap(personaID: "unused")
        },
        sessionPreviewManager: StubSessionPreviewManager(
          loadPreviewHandler: { _, _ in
            Thread.sleep(forTimeInterval: 0.2)
            return "preview-text"
          }
        )
      ),
      previewExportDestinationPicker: StubPreviewDestinationPicker(),
      pasteboardWriter: StubPasteboardWriter()
    )

    model.refreshPreview(
      for: session,
      workspaceURL: workspaceURL
    )
    try? await Task.sleep(for: .milliseconds(20))

    model.cancelPreviewTask()
    #expect(model.isLoadingPreview)

    model.refreshPreview(
      for: session,
      workspaceURL: workspaceURL
    )

    await waitFor {
      !model.isLoadingPreview
    }

    #expect(model.preview == "preview-text")
    #expect(model.previewErrorMessage == nil)
  }

  @Test
  func refreshMapForSessionPublishesMap() async {
    let sessionFileURL = URL(fileURLWithPath: "/Workspace/.personakit/Sessions/session-a.session.json")
    let workspaceURL = URL(fileURLWithPath: "/Workspace")
    let model = WorkspaceSessionFeatureModel(
      operationRunner: makeOperationRunner(
        sessionManager: StubSessionManager { fileURL in
          #expect(fileURL == sessionFileURL)

          return WorkspaceSessionDraft(
            id: "session-a",
            personaId: "persona-a",
            directiveId: "directive-a",
            kitOverrides: ["kit-a"]
          )
        },
        sessionMapBuilder: StubSessionMapBuilder { _, personaId, directiveId, kitOverrides in
          #expect(personaId == "persona-a")
          #expect(directiveId == "directive-a")
          #expect(kitOverrides == ["kit-a"])

          return Self.makeMap(personaID: personaId)
        }
      ),
      previewExportDestinationPicker: StubPreviewDestinationPicker(),
      pasteboardWriter: StubPasteboardWriter()
    )

    model.refreshMap(
      for: WorkspaceSessionListItem(
        id: "session-a",
        personaId: "persona-a",
        directiveId: "directive-a",
        fileURL: sessionFileURL,
        sourceScope: .project
      ),
      workspaceURL: workspaceURL
    )

    await waitFor {
      !model.isLoadingMap && model.map != nil
    }

    #expect(model.mapErrorMessage == nil)
    #expect(model.map?.nodes.contains(where: { $0.key == "persona:persona-a" }) == true)
  }

  @Test
  func refreshMapSkipsDuplicateRequestForSameSession() async {
    let sessionFileURL = URL(fileURLWithPath: "/Workspace/.personakit/Sessions/session-a.session.json")
    let workspaceURL = URL(fileURLWithPath: "/Workspace")
    let mapBuildCount = ThreadSafeCounter()
    let model = WorkspaceSessionFeatureModel(
      operationRunner: makeOperationRunner(
        sessionManager: StubSessionManager { _ in
          WorkspaceSessionDraft(
            id: "session-a",
            personaId: "persona-a",
            directiveId: "directive-a",
            kitOverrides: ["kit-a"]
          )
        },
        sessionMapBuilder: StubSessionMapBuilder { _, _, _, _ in
          Thread.sleep(forTimeInterval: 0.05)
          let buildNumber = mapBuildCount.increment()

          return Self.makeMap(personaID: "persona-\(buildNumber)")
        }
      ),
      previewExportDestinationPicker: StubPreviewDestinationPicker(),
      pasteboardWriter: StubPasteboardWriter()
    )

    let session = WorkspaceSessionListItem(
      id: "session-a",
      personaId: "persona-a",
      directiveId: "directive-a",
      fileURL: sessionFileURL,
      sourceScope: .project
    )

    model.refreshMap(
      for: session,
      workspaceURL: workspaceURL
    )

    await waitFor {
      !model.isLoadingMap
        && model.map?.nodes.contains(where: { $0.key == "persona:persona-1" }) == true
    }

    model.refreshMap(
      for: session,
      workspaceURL: workspaceURL
    )

    #expect(!model.isLoadingMap)
    #expect(model.map?.nodes.contains(where: { $0.key == "persona:persona-1" }) == true)
    #expect(mapBuildCount.currentValue() == 1)
  }

  @Test
  func refreshMapForceReloadBypassesCache() async {
    let sessionFileURL = URL(fileURLWithPath: "/Workspace/.personakit/Sessions/session-a.session.json")
    let workspaceURL = URL(fileURLWithPath: "/Workspace")
    let mapBuildCount = ThreadSafeCounter()
    let model = WorkspaceSessionFeatureModel(
      operationRunner: makeOperationRunner(
        sessionManager: StubSessionManager { _ in
          WorkspaceSessionDraft(
            id: "session-a",
            personaId: "persona-a",
            directiveId: "directive-a",
            kitOverrides: ["kit-a"]
          )
        },
        sessionMapBuilder: StubSessionMapBuilder { _, _, _, _ in
          Thread.sleep(forTimeInterval: 0.05)
          let buildNumber = mapBuildCount.increment()

          return Self.makeMap(personaID: "persona-\(buildNumber)")
        }
      ),
      previewExportDestinationPicker: StubPreviewDestinationPicker(),
      pasteboardWriter: StubPasteboardWriter()
    )

    let session = WorkspaceSessionListItem(
      id: "session-a",
      personaId: "persona-a",
      directiveId: "directive-a",
      fileURL: sessionFileURL,
      sourceScope: .project
    )

    model.refreshMap(
      for: session,
      workspaceURL: workspaceURL
    )

    await waitFor {
      !model.isLoadingMap
        && model.map?.nodes.contains(where: { $0.key == "persona:persona-1" }) == true
    }

    model.refreshMap(
      for: session,
      workspaceURL: workspaceURL,
      forceReload: true
    )

    #expect(model.isLoadingMap)

    await waitFor {
      !model.isLoadingMap
        && model.map?.nodes.contains(where: { $0.key == "persona:persona-2" }) == true
    }

    #expect(mapBuildCount.currentValue() == 2)
  }

  @Test
  func newerSessionMapRequestWinsWhenRequestsOverlap() async {
    let workspaceURL = URL(fileURLWithPath: "/Workspace")
    let slowSessionFileURL = URL(fileURLWithPath: "/Workspace/.personakit/Sessions/session-slow.session.json")
    let fastSessionFileURL = URL(fileURLWithPath: "/Workspace/.personakit/Sessions/session-fast.session.json")
    let model = WorkspaceSessionFeatureModel(
      operationRunner: makeOperationRunner(
        sessionManager: StubSessionManager { fileURL in
          if fileURL == slowSessionFileURL {
            return WorkspaceSessionDraft(
              id: "session-slow",
              personaId: "persona-slow",
              directiveId: "directive",
              kitOverrides: []
            )
          }

          return WorkspaceSessionDraft(
            id: "session-fast",
            personaId: "persona-fast",
            directiveId: "directive",
            kitOverrides: []
          )
        },
        sessionMapBuilder: StubSessionMapBuilder { _, personaId, _, _ in
          if personaId == "persona-slow" {
            Thread.sleep(forTimeInterval: 0.3)
          }

          return Self.makeMap(personaID: personaId)
        }
      ),
      previewExportDestinationPicker: StubPreviewDestinationPicker(),
      pasteboardWriter: StubPasteboardWriter()
    )

    model.refreshMap(
      for: WorkspaceSessionListItem(
        id: "session-slow",
        personaId: "persona-slow",
        directiveId: "directive",
        fileURL: slowSessionFileURL,
        sourceScope: .project
      ),
      workspaceURL: workspaceURL
    )

    try? await Task.sleep(for: .milliseconds(20))

    model.refreshMap(
      for: WorkspaceSessionListItem(
        id: "session-fast",
        personaId: "persona-fast",
        directiveId: "directive",
        fileURL: fastSessionFileURL,
        sourceScope: .project
      ),
      workspaceURL: workspaceURL
    )

    await waitFor {
      model.map?.nodes.contains(where: { $0.key == "persona:persona-fast" }) == true
    }

    try? await Task.sleep(for: .milliseconds(350))

    #expect(model.map?.nodes.contains(where: { $0.key == "persona:persona-fast" }) == true)
    #expect(model.map?.nodes.contains(where: { $0.key == "persona:persona-slow" }) == false)
  }

  @Test
  func refreshMapForDraftUpdatesWithLatestDraft() async {
    let workspaceURL = URL(fileURLWithPath: "/Workspace")
    let model = WorkspaceSessionFeatureModel(
      operationRunner: makeOperationRunner(
        sessionManager: StubSessionManager { _ in
          WorkspaceSessionDraft(
            id: "unused",
            personaId: "unused",
            directiveId: "unused",
            kitOverrides: []
          )
        },
        sessionMapBuilder: StubSessionMapBuilder { _, personaId, _, kitOverrides in
          var map = Self.makeMap(personaID: personaId)

          if let personaNode = map.nodes.first(where: { $0.key == "persona:\(personaId)" }) {
            let kitNodes = kitOverrides.map { kitID in
              WorkspaceSessionMapNode(
                key: "kit:\(kitID)",
                id: kitID,
                displayName: kitID,
                kind: .kit,
                isMissing: false,
                badges: []
              )
            }

            map = WorkspaceSessionMap(
              nodes: [personaNode] + kitNodes,
              edges: [],
              resolutionErrors: [],
              isFullyResolved: true
            )
          }

          return map
        }
      ),
      previewExportDestinationPicker: StubPreviewDestinationPicker(),
      pasteboardWriter: StubPasteboardWriter()
    )

    model.refreshMap(
      for: WorkspaceSessionDraft(
        id: "draft",
        personaId: "persona-a",
        directiveId: "directive-a",
        kitOverrides: ["kit-a"]
      ),
      workspaceURL: workspaceURL
    )

    await waitFor {
      model.draftMap?.nodes.contains(where: { $0.key == "persona:persona-a" }) == true
    }

    model.refreshMap(
      for: WorkspaceSessionDraft(
        id: "draft",
        personaId: "persona-b",
        directiveId: "directive-b",
        kitOverrides: ["kit-b"]
      ),
      workspaceURL: workspaceURL
    )

    await waitFor {
      model.draftMap?.nodes.contains(where: { $0.key == "persona:persona-b" }) == true
    }

    #expect(model.draftMap?.nodes.contains(where: { $0.key == "kit:kit-b" }) == true)
    #expect(model.draftMap?.nodes.contains(where: { $0.key == "persona:persona-a" }) == false)
  }

  @Test
  func refreshMapSurfacesBuilderErrors() async {
    let workspaceURL = URL(fileURLWithPath: "/Workspace")
    let sessionFileURL = URL(fileURLWithPath: "/Workspace/.personakit/Sessions/session-a.session.json")
    let model = WorkspaceSessionFeatureModel(
      operationRunner: makeOperationRunner(
        sessionManager: StubSessionManager { _ in
          WorkspaceSessionDraft(
            id: "session-a",
            personaId: "persona-a",
            directiveId: "directive-a",
            kitOverrides: []
          )
        },
        sessionMapBuilder: StubSessionMapBuilder { _, _, _, _ in
          throw WorkspaceSnapshotBuildError(message: "Map load failed.")
        }
      ),
      previewExportDestinationPicker: StubPreviewDestinationPicker(),
      pasteboardWriter: StubPasteboardWriter()
    )

    model.refreshMap(
      for: WorkspaceSessionListItem(
        id: "session-a",
        personaId: "persona-a",
        directiveId: "directive-a",
        fileURL: sessionFileURL,
        sourceScope: .project
      ),
      workspaceURL: workspaceURL
    )

    await waitFor {
      !model.isLoadingMap && model.mapErrorMessage != nil
    }

    #expect(model.map == nil)
    #expect(model.mapErrorMessage == "Map load failed.")
  }

  @Test
  func refreshWorkspaceRelationshipMapPublishesMap() async {
    let workspaceURL = URL(fileURLWithPath: "/Workspace")
    let model = WorkspaceSessionFeatureModel(
      operationRunner: makeOperationRunner(
        sessionManager: StubSessionManager { _ in
          WorkspaceSessionDraft(
            id: "unused",
            personaId: "unused",
            directiveId: "unused",
            kitOverrides: []
          )
        },
        sessionMapBuilder: StubSessionMapBuilder { _, _, _, _ in
          Self.makeMap(personaID: "unused")
        },
        workspaceRelationshipMapBuilder: StubWorkspaceRelationshipMapBuilder(
          buildHandler: { workspaceURL in
            #expect(workspaceURL.path() == "/Workspace")
            return Self.makeWorkspaceRelationshipMap(personaID: "persona-a")
          }
        )
      ),
      previewExportDestinationPicker: StubPreviewDestinationPicker(),
      pasteboardWriter: StubPasteboardWriter()
    )

    model.refreshWorkspaceRelationshipMap(workspaceURL: workspaceURL)

    await waitFor {
      !model.isLoadingWorkspaceRelationshipMap && model.workspaceRelationshipMap != nil
    }

    #expect(model.workspaceRelationshipMapErrorMessage == nil)
    #expect(
      model.workspaceRelationshipMap?.nodes.contains(where: { $0.key == "persona:persona-a" }) == true
    )
  }

  @Test
  func refreshWorkspaceRelationshipMapSurfacesBuilderErrors() async {
    let workspaceURL = URL(fileURLWithPath: "/Workspace")
    let model = WorkspaceSessionFeatureModel(
      operationRunner: makeOperationRunner(
        sessionManager: StubSessionManager { _ in
          WorkspaceSessionDraft(
            id: "unused",
            personaId: "unused",
            directiveId: "unused",
            kitOverrides: []
          )
        },
        sessionMapBuilder: StubSessionMapBuilder { _, _, _, _ in
          Self.makeMap(personaID: "unused")
        },
        workspaceRelationshipMapBuilder: StubWorkspaceRelationshipMapBuilder(
          buildHandler: { _ in
            throw WorkspaceSnapshotBuildError(message: "Relationship map failed.")
          }
        )
      ),
      previewExportDestinationPicker: StubPreviewDestinationPicker(),
      pasteboardWriter: StubPasteboardWriter()
    )

    model.refreshWorkspaceRelationshipMap(workspaceURL: workspaceURL)

    await waitFor {
      !model.isLoadingWorkspaceRelationshipMap && model.workspaceRelationshipMapErrorMessage != nil
    }

    #expect(model.workspaceRelationshipMap == nil)
    #expect(model.workspaceRelationshipMapErrorMessage == "Relationship map failed.")
  }

  @Test
  func refreshWorkspaceRelationshipMapIgnoresStaleResultAfterWorkspaceClear() async {
    let workspaceURL = URL(fileURLWithPath: "/Workspace")
    let model = WorkspaceSessionFeatureModel(
      operationRunner: makeOperationRunner(
        sessionManager: StubSessionManager { _ in
          WorkspaceSessionDraft(
            id: "unused",
            personaId: "unused",
            directiveId: "unused",
            kitOverrides: []
          )
        },
        sessionMapBuilder: StubSessionMapBuilder { _, _, _, _ in
          Self.makeMap(personaID: "unused")
        },
        workspaceRelationshipMapBuilder: StubWorkspaceRelationshipMapBuilder(
          buildHandler: { _ in
            Thread.sleep(forTimeInterval: 0.3)
            return Self.makeWorkspaceRelationshipMap(personaID: "persona-slow")
          }
        )
      ),
      previewExportDestinationPicker: StubPreviewDestinationPicker(),
      pasteboardWriter: StubPasteboardWriter()
    )

    model.refreshWorkspaceRelationshipMap(workspaceURL: workspaceURL)
    try? await Task.sleep(for: .milliseconds(20))

    model.refreshWorkspaceRelationshipMap(workspaceURL: nil)

    #expect(model.workspaceRelationshipMap == nil)
    #expect(model.workspaceRelationshipMapErrorMessage == nil)
    #expect(!model.isLoadingWorkspaceRelationshipMap)

    try? await Task.sleep(for: .milliseconds(350))

    #expect(model.workspaceRelationshipMap == nil)
    #expect(model.workspaceRelationshipMapErrorMessage == nil)
    #expect(!model.isLoadingWorkspaceRelationshipMap)
  }

  private func waitFor(
    timeout: Duration = .seconds(2),
    condition: @escaping () -> Bool
  ) async {
    let clock = ContinuousClock()
    let deadline = clock.now + timeout

    while clock.now < deadline {
      if condition() {
        return
      }

      try? await Task.sleep(for: .milliseconds(10))
    }

    #expect(condition())
  }

  nonisolated private static func makeMap(personaID: String) -> WorkspaceSessionMap {
    WorkspaceSessionMap(
      nodes: [
        WorkspaceSessionMapNode(
          key: "persona:\(personaID)",
          id: personaID,
          displayName: personaID,
          kind: .persona,
          isMissing: false,
          badges: []
        )
      ],
      edges: [],
      resolutionErrors: [],
      isFullyResolved: true
    )
  }

  nonisolated private static func makeWorkspaceRelationshipMap(personaID: String) -> WorkspaceSessionMap {
    WorkspaceSessionMap(
      nodes: [
        WorkspaceSessionMapNode(
          key: "persona:\(personaID)",
          id: personaID,
          displayName: personaID,
          kind: .persona,
          isMissing: false,
          badges: []
        )
      ],
      edges: [],
      resolutionErrors: [],
      isFullyResolved: true
    )
  }

  private func makeOperationRunner(
    sessionManager: StubSessionManager,
    sessionMapBuilder: StubSessionMapBuilder,
    sessionPreviewManager: any WorkspaceSessionPreviewManaging = StubSessionPreviewManager(),
    workspaceRelationshipMapBuilder: StubWorkspaceRelationshipMapBuilder =
      StubWorkspaceRelationshipMapBuilder()
  ) -> WorkspaceOperationRunner {
    WorkspaceOperationRunner(
      snapshotBuilder: StubSnapshotBuilder { _ in
        .empty
      },
      workspaceValidator: StubWorkspaceValidator { _ in
        .empty
      },
      sessionManager: sessionManager,
      essentialManager: StubEssentialManager(),
      libraryEntityManager: StubLibraryEntityManager(),
      sessionPreviewManager: sessionPreviewManager,
      sessionMapBuilder: sessionMapBuilder,
      workspaceRelationshipMapBuilder: workspaceRelationshipMapBuilder
    )
  }
}

private final class ThreadSafeCounter: @unchecked Sendable {
  private let lock = NSLock()
  private var value = 0

  func increment() -> Int {
    lock.lock()
    defer {
      lock.unlock()
    }

    value += 1
    return value
  }

  func currentValue() -> Int {
    lock.lock()
    defer {
      lock.unlock()
    }

    return value
  }
}

private struct StubSnapshotBuilder: WorkspaceSnapshotBuilding, Sendable {
  let buildHandler: @Sendable (URL) throws -> WorkspaceSnapshot

  func build(workspaceURL: URL) throws -> WorkspaceSnapshot {
    try buildHandler(workspaceURL)
  }
}

private struct StubWorkspaceValidator: WorkspaceValidating, Sendable {
  let validateHandler: @Sendable (URL) throws -> WorkspaceValidationSnapshot

  func validate(workspaceURL: URL) throws -> WorkspaceValidationSnapshot {
    try validateHandler(workspaceURL)
  }
}

private struct StubSessionManager: WorkspaceSessionManaging, Sendable {
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

private struct StubEssentialManager: WorkspaceEssentialManaging, Sendable {
  func loadMarkdown(fileURL: URL) throws -> String {
    ""
  }

  func saveMarkdown(
    workspaceURL: URL,
    itemID: String,
    markdown: String
  ) throws {}

  func copyGlobalEssentialToProject(
    workspaceURL: URL,
    item: WorkspaceListItem
  ) throws {}
}

private struct StubLibraryEntityManager: WorkspaceLibraryEntityManaging, Sendable {
  func loadRawJSON(fileURL: URL) throws -> String {
    "{}"
  }

  func validateRawJSON(
    _ rawJSON: String,
    entityType: WorkspaceLibraryEntityType,
    expectedID: String
  ) throws {}

  func saveRawJSON(
    workspaceURL: URL,
    itemID: String,
    rawJSON: String,
    entityType: WorkspaceLibraryEntityType
  ) throws {}

  func copyGlobalItemToProject(
    workspaceURL: URL,
    item: WorkspaceListItem,
    entityType: WorkspaceLibraryEntityType
  ) throws {}
}

private struct StubSessionPreviewManager: WorkspaceSessionPreviewManaging, Sendable {
  let loadPreviewHandler: @Sendable (URL, WorkspaceSessionListItem) throws -> String

  init(
    loadPreviewHandler: @escaping @Sendable (URL, WorkspaceSessionListItem) throws -> String = { _, _ in
      ""
    }
  ) {
    self.loadPreviewHandler = loadPreviewHandler
  }

  func loadPreview(
    workspaceURL: URL,
    session: WorkspaceSessionListItem
  ) throws -> String {
    try loadPreviewHandler(workspaceURL, session)
  }

  func exportPreview(
    _ preview: String,
    to destinationURL: URL
  ) throws {}
}

private struct StubSessionMapBuilder: WorkspaceSessionMapBuilding, Sendable {
  let buildHandler: @Sendable (URL, String, String, [String]) throws -> WorkspaceSessionMap

  func build(
    workspaceURL: URL,
    personaId: String,
    directiveId: String,
    kitOverrides: [String]
  ) throws -> WorkspaceSessionMap {
    try buildHandler(
      workspaceURL,
      personaId,
      directiveId,
      kitOverrides
    )
  }
}

private struct StubWorkspaceRelationshipMapBuilder: WorkspaceRelationshipMapBuilding, Sendable {
  let buildHandler: @Sendable (URL) throws -> WorkspaceSessionMap

  init(
    buildHandler: @escaping @Sendable (URL) throws -> WorkspaceSessionMap = { _ in
      WorkspaceSessionMap(
        nodes: [],
        edges: [],
        resolutionErrors: [],
        isFullyResolved: true
      )
    }
  ) {
    self.buildHandler = buildHandler
  }

  func build(workspaceURL: URL) throws -> WorkspaceSessionMap {
    try buildHandler(workspaceURL)
  }
}

private struct StubPreviewDestinationPicker: PreviewExportDestinationPicking {
  func pickPreviewDestination(suggestedFilename: String) -> URL? {
    nil
  }
}

private struct StubPasteboardWriter: PasteboardWriting {
  func writeString(_ value: String) -> Bool {
    true
  }
}
