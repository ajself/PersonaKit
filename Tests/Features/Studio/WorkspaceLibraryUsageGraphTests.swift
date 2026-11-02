import ContextCore
import ContextWorkspaceCore
import Dispatch
import Foundation
import StudioFoundation
import Synchronization
import Testing

@testable import StudioFeatures

/// "Used by" graph ownership in `WorkspaceLibraryFeatureModel`: loads after each successful
/// reload, cancels on workspace change, and keeps the last graph when a load fails. Uses stub
/// builders, a stub event source, and a manual clock; no sleeps.
@Suite(.serialized)
@MainActor
struct WorkspaceLibraryUsageGraphTests {
  private let workspaceURL = URL(fileURLWithPath: "/Workspace")
  private let otherWorkspaceURL = URL(fileURLWithPath: "/Other")
  private let personaFileURL = URL(
    fileURLWithPath: "/Workspace/.personakit/Packs/personas/solo-developer.persona.json"
  )

  @Test
  func explicitLoadPublishesUsersFromTheWorkspaceGraph() async {
    let store = makeStore { requestedURL in
      #expect(requestedURL.path() == "/Workspace")
      return makeUsageGraph(sessionIDs: ["solo-dev"])
    }

    store.workspaceURL = workspaceURL
    store.loadWorkspace()

    await waitFor { users(in: store) != nil && !store.libraryFeatureModel.isLoadingUsageGraph }

    #expect(users(in: store) == ["session:solo-dev"])
  }

  @Test
  func liveReloadRefreshesTheGraph() async {
    let source = StubFileEventSource()
    let clock = ManualTestClock()
    let buildCount = CallCounter()
    let store = makeStore(source: source, clock: clock) { _ in
      buildCount.increment()
      return makeUsageGraph(sessionIDs: buildCount.count == 1 ? [] : ["solo-dev"])
    }

    store.workspaceURL = workspaceURL
    store.loadWorkspace()
    await waitFor { users(in: store) == [] && source.watchedDirectories.count == 1 }

    source.emit([personaFileURL])
    await waitFor { clock.sleeperCount == 1 }
    clock.advance(by: WorkspaceLoadFeatureModel.defaultFileChangeDebounceInterval)

    await waitFor { users(in: store) == ["session:solo-dev"] && !store.libraryFeatureModel.isLoadingUsageGraph }
    #expect(buildCount.count == 2)
  }

  @Test
  func failedGraphLoadKeepsTheLastGraph() async {
    let buildCount = CallCounter()
    let buildFails = MutableBooleanState(value: false)
    let store = makeStore { _ in
      buildCount.increment()

      if buildFails.value {
        throw WorkspaceSnapshotBuildError(message: "Graph failed.")
      }

      return makeUsageGraph(sessionIDs: ["solo-dev"])
    }

    store.workspaceURL = workspaceURL
    store.loadWorkspace()
    await waitFor { users(in: store) == ["session:solo-dev"] && !store.libraryFeatureModel.isLoadingUsageGraph }

    buildFails.value = true
    store.loadWorkspace()

    await waitFor { buildCount.count == 2 && !store.libraryFeatureModel.isLoadingUsageGraph }
    #expect(users(in: store) == ["session:solo-dev"])
    #expect(store.libraryUsageLoadErrorMessage == nil)
  }

  @Test
  func failedFirstGraphLoadLeavesUsersUnavailable() async {
    let buildCount = CallCounter()
    let store = makeStore { _ in
      buildCount.increment()
      throw WorkspaceSnapshotBuildError(message: "Graph failed.")
    }

    store.workspaceURL = workspaceURL
    store.loadWorkspace()

    await waitFor { buildCount.count == 1 && !store.libraryFeatureModel.isLoadingUsageGraph }
    #expect(users(in: store) == nil)
    #expect(store.libraryUsageLoadErrorMessage == "Graph failed.")
  }

  @Test
  func successfulReloadClearsTheLoadFailure() async {
    let buildCount = CallCounter()
    let buildFails = MutableBooleanState(value: true)
    let store = makeStore { _ in
      buildCount.increment()

      if buildFails.value {
        throw WorkspaceSnapshotBuildError(message: "Graph failed.")
      }

      return makeUsageGraph(sessionIDs: ["solo-dev"])
    }

    store.workspaceURL = workspaceURL
    store.loadWorkspace()
    await waitFor { buildCount.count == 1 && !store.libraryFeatureModel.isLoadingUsageGraph }
    #expect(store.libraryUsageLoadErrorMessage == "Graph failed.")

    buildFails.value = false
    store.loadWorkspace()

    await waitFor { users(in: store) == ["session:solo-dev"] && !store.libraryFeatureModel.isLoadingUsageGraph }
    #expect(store.libraryUsageLoadErrorMessage == nil)
  }

  @Test
  func switchingWorkspacesCancelsTheInFlightLoad() async {
    let gate = UsageGraphGate()
    let store = makeStore { requestedURL in
      if requestedURL.path() == "/Workspace" {
        gate.enterAndWait()
        return makeUsageGraph(sessionIDs: ["stale-session"])
      }

      return makeUsageGraph(sessionIDs: ["other-session"])
    }

    store.workspaceURL = workspaceURL
    store.loadWorkspace()
    await waitFor { gate.hasEntered }
    #expect(store.libraryFeatureModel.isLoadingUsageGraph)

    store.workspaceURL = otherWorkspaceURL

    // Until the new workspace loads, the inspector shows loading rather than a failure.
    #expect(users(in: store) == nil)
    #expect(!store.libraryFeatureModel.isLoadingUsageGraph)
    #expect(store.libraryUsageLoadErrorMessage == nil)

    store.loadWorkspace()
    gate.release()

    await waitFor { users(in: store) == ["session:other-session"] && !store.libraryFeatureModel.isLoadingUsageGraph }
    await yieldTasks()
    #expect(users(in: store) == ["session:other-session"])
  }

  @Test
  func closingTheWorkspaceDropsTheInFlightLoad() async {
    let gate = UsageGraphGate()
    let finished = MutableBooleanState(value: false)
    let store = makeStore { _ in
      gate.enterAndWait()
      finished.value = true
      return makeUsageGraph(sessionIDs: ["stale-session"])
    }

    store.workspaceURL = workspaceURL
    store.loadWorkspace()
    await waitFor { gate.hasEntered }

    store.workspaceURL = nil
    gate.release()

    await waitFor { finished.value }
    await yieldTasks()

    #expect(store.libraryFeatureModel.usageGraph == nil)
    #expect(!store.libraryFeatureModel.isLoadingUsageGraph)
  }

  private func users(in store: WorkspaceStore) -> [String]? {
    store.libraryItemUsers(kind: .persona, id: "solo-developer")?.map(\.key)
  }

  private func makeStore(
    source: StubFileEventSource? = nil,
    clock: ManualTestClock = ManualTestClock(),
    graphBuilder: @escaping @Sendable (URL) throws -> WorkspaceSessionMap
  ) -> WorkspaceStore {
    WorkspaceStore(
      snapshotBuilder: WorkspaceStoreStubSnapshotBuilder { _ in
        makeSnapshot(id: "solo-developer")
      },
      workspaceValidator: WorkspaceStoreStubWorkspaceValidator { _ in
        WorkspaceValidationSnapshot(summary: "ok", issues: [])
      },
      workspaceRelationshipMapBuilder: WorkspaceStoreStubWorkspaceRelationshipMapBuilder(
        buildHandler: graphBuilder
      ),
      globalScopeProvider: WorkspaceGlobalScopeProvider(initialURL: nil, fallback: { nil }),
      fileEventSource: source,
      liveReloadClock: clock
    )
  }

  private func yieldTasks(_ iterations: Int = 50) async {
    for _ in 0..<iterations {
      await Task.yield()
    }
  }
}

/// A graph where `persona:solo-developer` is used by one session per id.
private func makeUsageGraph(sessionIDs: [String]) -> WorkspaceSessionMap {
  let persona = WorkspaceSessionMapNode(
    key: "persona:solo-developer",
    id: "solo-developer",
    displayName: "Solo Developer",
    kind: .persona,
    isMissing: false,
    badges: []
  )
  let sessions = sessionIDs.map { id in
    WorkspaceSessionMapNode(
      key: "session:\(id)",
      id: id,
      displayName: id,
      kind: .session,
      isMissing: false,
      badges: []
    )
  }

  return WorkspaceSessionMap(
    nodes: sessions + [persona],
    edges: sessions.map { session in
      WorkspaceSessionMapEdge(
        fromKey: session.key,
        toKey: persona.key,
        reason: "session.personaId"
      )
    },
    resolutionErrors: [],
    isFullyResolved: true
  )
}

/// Holds a builder call until the test releases it. Blocks on a semaphore, not a sleep.
private final class UsageGraphGate: Sendable {
  private let entered = Mutex(false)
  private let semaphore = DispatchSemaphore(value: 0)

  var hasEntered: Bool {
    entered.withLock { $0 }
  }

  func enterAndWait() {
    entered.withLock { $0 = true }
    semaphore.wait()
  }

  func release() {
    semaphore.signal()
  }
}
