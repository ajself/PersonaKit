import ContextCore
import ContextWorkspaceCore
import Foundation
import StudioFoundation
import Synchronization
import Testing

@MainActor
func waitFor(
  timeout: Duration = .seconds(2),
  condition: @escaping () -> Bool
) async {
  let clock = ContinuousClock()
  let deadline = clock.now + timeout

  while clock.now < deadline {
    if condition() {
      return
    }

    await Task.yield()
  }

  #expect(condition())
}

final class WorkspaceStoreInitializationState: Sendable {
  private struct State: Sendable {
    var createdDirectories: [URL] = []
    var isInitialized = false
  }

  private let state = Mutex(State())

  var createdDirectories: [URL] {
    state.withLock { $0.createdDirectories }
  }

  var isInitialized: Bool {
    state.withLock { $0.isInitialized }
  }

  func appendCreatedDirectory(_ url: URL) {
    state.withLock { state in
      state.createdDirectories.append(url)
    }
  }

  func markInitialized() {
    state.withLock { state in
      state.isInitialized = true
    }
  }
}

struct WorkspaceStoreStubSnapshotBuilder: WorkspaceSnapshotBuilding, Sendable {
  let buildHandler: @Sendable (URL) throws -> WorkspaceSnapshot

  func build(workspaceURL: URL) throws -> WorkspaceSnapshot {
    try buildHandler(workspaceURL)
  }
}

struct WorkspaceStoreStubWorkspaceValidator: WorkspaceValidating, Sendable {
  let validateHandler: @Sendable (URL) throws -> WorkspaceValidationSnapshot

  func validate(workspaceURL: URL) throws -> WorkspaceValidationSnapshot {
    try validateHandler(workspaceURL)
  }
}

struct WorkspaceStoreStubSessionManager: WorkspaceSessionManaging, Sendable {
  let loadDraftHandler: @Sendable (URL) throws -> WorkspaceSessionDraft
  let saveSessionHandler:
    @Sendable (
      URL,
      WorkspaceSessionDraft,
      String?,
      Set<String>,
      Set<String>,
      Set<String>
    ) throws -> String
  let deleteSessionHandler: @Sendable (URL, String) throws -> Void

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
    try saveSessionHandler(
      workspaceURL,
      draft,
      originalSessionID,
      validPersonaIDs,
      validDirectiveIDs,
      validKitIDs
    )
  }

  func deleteSession(
    workspaceURL: URL,
    sessionID: String
  ) throws {
    try deleteSessionHandler(workspaceURL, sessionID)
  }
}

func makeSnapshot(id: String) -> WorkspaceSnapshot {
  WorkspaceSnapshot(
    sessions: [],
    personas: [
      WorkspaceListItem(
        id: id,
        displayName: id,
        fileURL: URL(fileURLWithPath: "/\(id).persona.json"),
        sourceScope: .project
      )
    ],
    directives: [],
    kits: [],
    skills: [],
    essentials: []
  )
}

func makeSessionSnapshot(
  sessionID: String,
  fileName: String
) -> WorkspaceSnapshot {
  WorkspaceSnapshot(
    sessions: [
      WorkspaceSessionListItem(
        id: sessionID,
        personaId: "persona-\(sessionID)",
        directiveId: "directive-\(sessionID)",
        fileURL: URL(fileURLWithPath: "/\(fileName)"),
        sourceScope: .project
      )
    ],
    personas: [],
    directives: [],
    kits: [],
    skills: [],
    essentials: []
  )
}

func makeWorkspaceRelationshipMap(personaID: String) -> WorkspaceSessionMap {
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

func makeValidation(entityID: String) -> WorkspaceValidationSnapshot {
  WorkspaceValidationSnapshot(
    summary: "Validation summary: personas=1 kits=0 directives=0 references=0 skills=0 essentials=0 errors=1",
    issues: [
      WorkspaceValidationIssue(
        entityType: .persona,
        entityId: entityID,
        field: "schema",
        filePath: "Packs/personas/\(entityID).persona.json",
        message: "Synthetic test issue.",
        severity: .error
      )
    ]
  )
}

struct WorkspaceStoreStubSessionPreviewManager: WorkspaceSessionPreviewManaging, Sendable {
  let loadPreviewHandler: @Sendable (URL, WorkspaceSessionListItem) throws -> String
  let exportPreviewHandler: @Sendable (String, URL) throws -> Void

  func loadPreview(
    workspaceURL: URL,
    session: WorkspaceSessionListItem
  ) throws -> String {
    try loadPreviewHandler(workspaceURL, session)
  }

  func exportPreview(
    _ preview: String,
    to destinationURL: URL
  ) throws {
    try exportPreviewHandler(preview, destinationURL)
  }
}

struct WorkspaceStoreStubSessionMapBuilder: WorkspaceSessionMapBuilding, Sendable {
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

struct WorkspaceStoreStubWorkspaceRelationshipMapBuilder: WorkspaceRelationshipMapBuilding, Sendable {
  let buildHandler: @Sendable (URL) throws -> WorkspaceSessionMap

  func build(workspaceURL: URL) throws -> WorkspaceSessionMap {
    try buildHandler(workspaceURL)
  }
}

struct WorkspaceStoreStubLibraryEntityManager: WorkspaceLibraryEntityManaging, Sendable {
  let loadRawJSONHandler: @Sendable (URL) throws -> String
  let validateRawJSONHandler: @Sendable (String, WorkspaceLibraryEntityType, String) throws -> Void
  let saveRawJSONHandler: @Sendable (URL, String, String, WorkspaceLibraryEntityType) throws -> Void
  let copyGlobalItemToProjectHandler: @Sendable (URL, WorkspaceListItem, WorkspaceLibraryEntityType) throws -> Void

  func loadRawJSON(fileURL: URL) throws -> String {
    try loadRawJSONHandler(fileURL)
  }

  func validateRawJSON(
    _ rawJSON: String,
    entityType: WorkspaceLibraryEntityType,
    expectedID: String
  ) throws {
    try validateRawJSONHandler(rawJSON, entityType, expectedID)
  }

  func saveRawJSON(
    workspaceURL: URL,
    itemID: String,
    rawJSON: String,
    entityType: WorkspaceLibraryEntityType
  ) throws {
    try saveRawJSONHandler(workspaceURL, itemID, rawJSON, entityType)
  }

  func copyGlobalItemToProject(
    workspaceURL: URL,
    item: WorkspaceListItem,
    entityType: WorkspaceLibraryEntityType
  ) throws {
    try copyGlobalItemToProjectHandler(workspaceURL, item, entityType)
  }
}

struct WorkspaceStoreStubInstallEnvironment: WorkspaceInstallEnvironmentProviding, Sendable {
  let rootHomeDirectoryURL: URL
  let resolvedBundledCLIURL: URL?
  let resolvedBundledCLISupportBundleURL: URL?

  @MainActor
  func homeDirectoryURL() -> URL {
    rootHomeDirectoryURL.standardizedFileURL
  }

  @MainActor
  func bundledCLIURL() -> URL? {
    resolvedBundledCLIURL?.standardizedFileURL
  }

  @MainActor
  func bundledCLISupportBundleURL() -> URL? {
    resolvedBundledCLISupportBundleURL?.standardizedFileURL
  }
}

struct WorkspaceStoreStubEssentialManager: WorkspaceEssentialManaging, Sendable {
  let loadMarkdownHandler: @Sendable (URL) throws -> String
  let saveMarkdownHandler: @Sendable (URL, String, String) throws -> Void
  let copyGlobalEssentialToProjectHandler: @Sendable (URL, WorkspaceListItem) throws -> Void

  func loadMarkdown(fileURL: URL) throws -> String {
    try loadMarkdownHandler(fileURL)
  }

  func saveMarkdown(
    workspaceURL: URL,
    itemID: String,
    markdown: String
  ) throws {
    try saveMarkdownHandler(workspaceURL, itemID, markdown)
  }

  func copyGlobalEssentialToProject(
    workspaceURL: URL,
    item: WorkspaceListItem
  ) throws {
    try copyGlobalEssentialToProjectHandler(workspaceURL, item)
  }
}

struct WorkspaceStoreStubWorkspacePicker: WorkspacePicking {
  let selectedURL: URL?

  @MainActor
  func pickWorkspaceURL() -> URL? {
    selectedURL
  }
}

struct WorkspaceStoreStubGlobalLibraryPicker: GlobalLibraryDirectoryPicking {
  let selectedURL: URL?

  @MainActor
  func pickGlobalLibraryURL() -> URL? {
    selectedURL
  }
}

struct WorkspaceStoreStubPreviewExportDestinationPicker: PreviewExportDestinationPicking {
  let destinationURL: URL?

  @MainActor
  func pickPreviewDestination(suggestedFilename: String) -> URL? {
    destinationURL
  }
}

struct WorkspaceStoreStubPasteboardWriter: PasteboardWriting {
  let expectedValue: String
  let shouldSucceed: Bool

  @MainActor
  func writeString(_ value: String) -> Bool {
    guard value == expectedValue else {
      return false
    }

    return shouldSucceed
  }
}

final class MutableBooleanState: Sendable {
  private let state: Mutex<Bool>

  init(value: Bool) {
    state = Mutex(value)
  }

  var value: Bool {
    get {
      state.withLock { $0 }
    }

    set {
      state.withLock { value in
        value = newValue
      }
    }
  }
}

final class BlockingCallGate: Sendable {
  private struct State: Sendable {
    var startedCount = 0
    var isReleased = false
    var hasFinished = false
  }

  private let state = Mutex(State())

  func markStarted() -> Int {
    state.withLock { state in
      state.startedCount += 1
      return state.startedCount
    }
  }

  var hasStarted: Bool {
    state.withLock { $0.startedCount > 0 }
  }

  var hasFinished: Bool {
    state.withLock { $0.hasFinished }
  }

  func waitUntilReleased() {
    while true {
      if state.withLock({ $0.isReleased }) {
        return
      }

      // Keep test gates deterministic without busy-spinning the whole process.
      Thread.sleep(forTimeInterval: 0.001)
    }
  }

  func release() {
    state.withLock { state in
      state.isReleased = true
    }
  }

  func markFinished() {
    state.withLock { state in
      state.hasFinished = true
    }
  }

  func currentStartCount() -> Int {
    state.withLock { $0.startedCount }
  }
}
