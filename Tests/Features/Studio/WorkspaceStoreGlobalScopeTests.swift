import ContextWorkspaceCore
import Foundation
import StudioFoundation
import Testing

@testable import StudioFeatures

/// Coverage for applying a global-library grant to a live store (Tranche 4, S1).
@MainActor
struct WorkspaceStoreGlobalScopeTests {
  @Test
  func setGlobalScopeReloadsAndRevalidatesOpenWorkspace() async throws {
    let (workspaceURL, _, globalScopeURL) = try makeGlobalOnlyReferenceWorkspace()

    // Launch-configured-style store with no grant: builders read the late-bindable box.
    let provider = WorkspaceGlobalScopeProvider(initialURL: nil, fallback: { nil })
    let store = WorkspaceStore(globalScopeProvider: provider)

    store.workspaceURL = workspaceURL
    store.loadWorkspace()

    // Without the global scope, the session's references read as missing.
    await waitFor {
      !store.validation.issues.isEmpty
    }

    // Granting the global library flips the previously-failing references clean.
    // A completed clean run reports `errors=0` (distinct from the `.empty` reset state).
    store.setGlobalScope(globalScopeURL)

    await waitFor {
      store.validation.issues.isEmpty
        && store.validation.summary.contains("errors=0")
        && store.loadErrorMessage == nil
    }
  }

  @Test
  func connectGlobalLibraryGrantsRevalidatesAndClearsBanner() async throws {
    let (workspaceURL, _, globalScopeURL) = try makeGlobalOnlyReferenceWorkspace()

    // No grant yet, and the fallback resolves nothing — the global library is unconnected.
    let provider = WorkspaceGlobalScopeProvider(initialURL: nil, fallback: { nil })
    let store = WorkspaceStore(
      globalScopeProvider: provider,
      globalLibraryPicker: WorkspaceStoreStubGlobalLibraryPicker(selectedURL: globalScopeURL)
    )

    store.workspaceURL = workspaceURL
    store.loadWorkspace()

    await waitFor { !store.validation.issues.isEmpty }

    // Disconnected: the unresolved references fold into the Connect banner.
    #expect(!store.isGlobalLibraryConnected)
    let beforeReport = StudioValidationReportState(
      snapshot: store.snapshot,
      validation: store.validation,
      validationErrorMessage: store.validationErrorMessage,
      globalLibraryConnected: store.isGlobalLibraryConnected
    )
    #expect(beforeReport.showsGlobalLibraryBanner)
    #expect(beforeReport.issues.isEmpty)

    // Connecting picks the global library, applies it, and revalidates clean.
    store.connectGlobalLibrary()

    await waitFor {
      store.validation.issues.isEmpty
        && store.validation.summary.contains("errors=0")
    }

    #expect(store.isGlobalLibraryConnected)
    #expect(store.globalLibraryConnectWarning == nil)
    let afterReport = StudioValidationReportState(
      snapshot: store.snapshot,
      validation: store.validation,
      validationErrorMessage: store.validationErrorMessage,
      globalLibraryConnected: store.isGlobalLibraryConnected
    )
    #expect(!afterReport.showsGlobalLibraryBanner)
  }

  @Test
  func connectGlobalLibraryWarnsWhenPickedFolderHasNoPacks() async throws {
    let (workspaceURL, _, _) = try makeGlobalOnlyReferenceWorkspace()
    // A folder that exists but is not a PersonaKit root (no `Packs/`).
    let emptyFolder = try makeTempDirectory().appendingPathComponent("not-a-library")
    try FileManager.default.createDirectory(at: emptyFolder, withIntermediateDirectories: true)

    let provider = WorkspaceGlobalScopeProvider(initialURL: nil, fallback: { nil })
    let store = WorkspaceStore(
      globalScopeProvider: provider,
      globalLibraryPicker: WorkspaceStoreStubGlobalLibraryPicker(selectedURL: emptyFolder)
    )

    store.workspaceURL = workspaceURL
    store.loadWorkspace()
    await waitFor { !store.validation.issues.isEmpty }

    store.connectGlobalLibrary()

    // The grant still applies (non-blocking), but the mismatch is flagged.
    #expect(store.globalLibraryConnectWarning != nil)
    #expect(store.isGlobalLibraryConnected)
  }

  @Test
  func launchConfiguredWiresProviderIntoValidation() async throws {
    let (workspaceURL, _, globalScopeURL) = try makeGlobalOnlyReferenceWorkspace()

    // Env override seeds the provider with the fixture global, so the builders never read
    // the real home. This locks the launch path: the wired builders must use the box.
    let store = WorkspaceStore.launchConfigured(
      environment: [
        StudioLaunchConfiguration.globalScopePathEnvironmentKey: globalScopeURL.path()
      ]
    )

    store.workspaceURL = workspaceURL
    store.loadWorkspace()

    await waitFor {
      store.validation.issues.isEmpty
        && store.validation.summary.contains("errors=0")
    }
  }

  @Test
  func setGlobalScopeWithoutProviderIsNoOp() async throws {
    let (workspaceURL, _, globalScopeURL) = try makeGlobalOnlyReferenceWorkspace()

    // A store built without a late-bindable provider cannot late-bind a grant.
    // Fixed `{ nil }` providers keep this project-scope-only and off the real home.
    let store = WorkspaceStore(
      snapshotBuilder: WorkspaceSnapshotBuilder(globalScopeProvider: { nil }),
      workspaceValidator: WorkspaceValidator(globalScopeProvider: { nil })
    )

    store.workspaceURL = workspaceURL
    store.loadWorkspace()

    await waitFor {
      !store.validation.issues.isEmpty
    }

    let issuesBefore = store.validation.issues
    store.setGlobalScope(globalScopeURL)

    // No reload/revalidate happens, so the issues are unchanged.
    #expect(store.validation.issues == issuesBefore)
  }
}
