import ContextCore
import ContextWorkspaceCore
import Foundation
import StudioFoundation
import Testing

@testable import StudioFeatures

/// Live reload: debounced file watching in `WorkspaceLoadFeatureModel` and the store's
/// reload on change. Uses a stub event source and a manual clock; no FSEvents, no sleeps.
@Suite(.serialized)
@MainActor
struct WorkspaceLiveReloadTests {
  private let watchedDirectory = URL(fileURLWithPath: "/Workspace/.personakit", isDirectory: true)
  private let personaFileURL = URL(
    fileURLWithPath: "/Workspace/.personakit/Packs/personas/solo.persona.json"
  )
  private let kitFileURL = URL(fileURLWithPath: "/Workspace/.personakit/Packs/kits/core.kit.json")

  @Test
  func burstOfChangesDeliversOneBatchAfterTheQuietPeriod() async {
    let source = StubFileEventSource()
    let clock = ManualTestClock()
    let loadModel = makeStore(source: source, clock: clock).loadFeatureModel
    var deliveredBatches: [Set<URL>] = []

    loadModel.startWatching(directories: [watchedDirectory]) { changes in
      deliveredBatches.append(changes)
    }

    source.emit([personaFileURL])
    await waitFor { clock.sleeperDeadlines == [.milliseconds(300)] }

    clock.advance(by: .milliseconds(200))
    source.emit([kitFileURL])
    // The second change restarts the quiet period.
    await waitFor { clock.sleeperDeadlines == [.milliseconds(500)] }

    clock.advance(by: .milliseconds(299))
    await yieldTasks()
    #expect(deliveredBatches.isEmpty)

    clock.advance(by: .milliseconds(1))
    await waitFor { deliveredBatches.count == 1 }

    #expect(deliveredBatches == [[personaFileURL, kitFileURL]])
  }

  @Test
  func finderMetadataChangesAreIgnored() async {
    let source = StubFileEventSource()
    let clock = ManualTestClock()
    let loadModel = makeStore(source: source, clock: clock).loadFeatureModel
    var deliveredBatches: [Set<URL>] = []

    loadModel.startWatching(directories: [watchedDirectory]) { changes in
      deliveredBatches.append(changes)
    }

    source.emit([watchedDirectory.appendingPathComponent(".DS_Store")])
    await yieldTasks()

    #expect(clock.sleeperCount == 0)

    clock.advance(by: .seconds(1))
    await yieldTasks()

    #expect(deliveredBatches.isEmpty)
  }

  @Test
  func stopWatchingDropsPendingChangesAndEndsTheStream() async {
    let source = StubFileEventSource()
    let clock = ManualTestClock()
    let loadModel = makeStore(source: source, clock: clock).loadFeatureModel
    var deliveredBatches: [Set<URL>] = []

    loadModel.startWatching(directories: [watchedDirectory]) { changes in
      deliveredBatches.append(changes)
    }

    source.emit([personaFileURL])
    await waitFor { clock.sleeperCount == 1 }

    loadModel.stopWatching()
    await waitFor { source.terminationCount == 1 && clock.sleeperCount == 0 }

    clock.advance(by: .seconds(1))
    await yieldTasks()

    #expect(deliveredBatches.isEmpty)
    #expect(loadModel.watchedDirectories.isEmpty)
  }

  @Test
  func aWatchWhoseStreamEndsIsStartedAgainOnTheNextWatch() async {
    let source = StubFileEventSource()
    let loadModel = makeStore(source: source, clock: ManualTestClock()).loadFeatureModel

    loadModel.startWatching(directories: [watchedDirectory]) { _ in }
    source.finish()
    await waitFor { loadModel.watchedDirectories.isEmpty }

    loadModel.startWatching(directories: [watchedDirectory]) { _ in }

    #expect(source.watchedDirectories == [[watchedDirectory], [watchedDirectory]])
    #expect(loadModel.watchedDirectories == [watchedDirectory])
  }

  @Test
  func rewatchingTheSameDirectoriesKeepsTheRunningWatch() async {
    let source = StubFileEventSource()
    let loadModel = makeStore(source: source, clock: ManualTestClock()).loadFeatureModel
    let otherDirectory = URL(fileURLWithPath: "/Other/.personakit", isDirectory: true)

    loadModel.startWatching(directories: [watchedDirectory]) { _ in }
    loadModel.startWatching(directories: [watchedDirectory]) { _ in }

    #expect(source.watchedDirectories.count == 1)

    loadModel.startWatching(directories: [otherDirectory]) { _ in }
    await waitFor { source.terminationCount == 1 }

    #expect(source.watchedDirectories == [[watchedDirectory], [otherDirectory]])
  }

  @Test
  func loadedWorkspaceWatchesProjectAndGlobalLibraryAndReloadsOnChange() async {
    let source = StubFileEventSource()
    let clock = ManualTestClock()
    let globalURL = URL(fileURLWithPath: "/Global/.personakit", isDirectory: true)
    let buildCount = CallCounter()
    let validateCount = CallCounter()
    let store = makeStore(
      source: source,
      clock: clock,
      globalScopeURL: globalURL,
      buildCount: buildCount,
      validateCount: validateCount
    )

    store.workspaceURL = URL(fileURLWithPath: "/Workspace")
    store.loadWorkspace()

    await waitFor { source.watchedDirectories.count == 1 && validateCount.count == 1 }

    #expect(source.watchedDirectories == [[globalURL, watchedDirectory]])
    #expect(buildCount.count == 1)

    source.emit([personaFileURL])
    await waitFor { clock.sleeperCount == 1 }
    clock.advance(by: WorkspaceLoadFeatureModel.defaultFileChangeDebounceInterval)

    await waitFor { buildCount.count == 2 && validateCount.count == 2 }

    // Reloading the same workspace keeps the existing watch.
    #expect(source.watchedDirectories.count == 1)
  }

  @Test
  func switchingWorkspacesWatchesTheNewOne() async {
    let source = StubFileEventSource()
    let store = makeStore(source: source, clock: ManualTestClock())
    let otherDirectory = URL(fileURLWithPath: "/Other/.personakit", isDirectory: true)

    store.workspaceURL = URL(fileURLWithPath: "/Workspace")
    store.loadWorkspace()
    await waitFor { source.watchedDirectories.count == 1 }

    store.workspaceURL = URL(fileURLWithPath: "/Other")
    store.loadWorkspace()

    await waitFor { source.watchedDirectories.count == 2 && source.terminationCount == 1 }
    #expect(source.watchedDirectories.last == [otherDirectory])
  }

  @Test
  func failedReloadKeepsWatchingSoAFixReloads() async {
    let source = StubFileEventSource()
    let clock = ManualTestClock()
    let buildCount = CallCounter()
    let buildFails = MutableBooleanState(value: false)
    let store = WorkspaceStore(
      snapshotBuilder: WorkspaceStoreStubSnapshotBuilder { _ in
        buildCount.increment()

        if buildFails.value {
          throw WorkspaceSnapshotBuildError(message: "Failed to load workspace registry.")
        }

        return makeSnapshot(id: "solo")
      },
      workspaceValidator: WorkspaceStoreStubWorkspaceValidator { _ in
        WorkspaceValidationSnapshot(summary: "ok", issues: [])
      },
      globalScopeProvider: WorkspaceGlobalScopeProvider(initialURL: nil, fallback: { nil }),
      fileEventSource: source,
      liveReloadClock: clock
    )

    store.workspaceURL = URL(fileURLWithPath: "/Workspace")
    store.loadWorkspace()
    await waitFor { source.watchedDirectories.count == 1 }

    buildFails.value = true
    source.emit([personaFileURL])
    await waitFor { clock.sleeperCount == 1 }
    clock.advance(by: WorkspaceLoadFeatureModel.defaultFileChangeDebounceInterval)
    await waitFor { buildCount.count == 2 }
    await yieldTasks()

    #expect(source.terminationCount == 0)
    #expect(store.snapshot.personas.map(\.id) == ["solo"])

    buildFails.value = false
    source.emit([personaFileURL])
    await waitFor { clock.sleeperCount == 1 }
    clock.advance(by: WorkspaceLoadFeatureModel.defaultFileChangeDebounceInterval)

    await waitFor { buildCount.count == 3 }
  }

  @Test
  func closingTheWorkspaceStopsWatching() async {
    let source = StubFileEventSource()
    let store = makeStore(source: source, clock: ManualTestClock())

    store.workspaceURL = URL(fileURLWithPath: "/Workspace")
    store.loadWorkspace()
    await waitFor { source.watchedDirectories.count == 1 }

    store.workspaceURL = nil

    await waitFor { source.terminationCount == 1 }
    #expect(store.loadFeatureModel.watchedDirectories.isEmpty)
  }

  @Test
  func externalReloadKeepsValidationResultsOnScreenUntilNewOnesArrive() async {
    let gate = BlockingCallGate()
    let validateCount = CallCounter()
    let store = WorkspaceStore(
      snapshotBuilder: WorkspaceStoreStubSnapshotBuilder { _ in makeSnapshot(id: "solo") },
      workspaceValidator: WorkspaceStoreStubWorkspaceValidator { _ in
        validateCount.increment()

        if validateCount.count > 1 {
          _ = gate.markStarted()
          gate.waitUntilReleased()
        }

        return makeValidation(entityID: "solo")
      }
    )

    store.workspaceURL = URL(fileURLWithPath: "/Workspace")
    store.loadWorkspace()
    await waitFor { store.validation.issues.count == 1 }

    store.reloadWorkspaceAfterExternalChange(changedFileURLs: [personaFileURL])
    await waitFor { gate.hasStarted }

    #expect(store.validation.issues.count == 1)
    #expect(store.validation.summary != "Validating workspace…")

    gate.release()
  }

  private func makeStore(
    source: StubFileEventSource,
    clock: ManualTestClock,
    globalScopeURL: URL? = nil,
    buildCount: CallCounter = CallCounter(),
    validateCount: CallCounter = CallCounter()
  ) -> WorkspaceStore {
    WorkspaceStore(
      snapshotBuilder: WorkspaceStoreStubSnapshotBuilder { _ in
        buildCount.increment()
        return makeSnapshot(id: "solo")
      },
      workspaceValidator: WorkspaceStoreStubWorkspaceValidator { _ in
        validateCount.increment()
        return WorkspaceValidationSnapshot(summary: "ok", issues: [])
      },
      globalScopeProvider: WorkspaceGlobalScopeProvider(
        initialURL: globalScopeURL,
        fallback: { nil }
      ),
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
