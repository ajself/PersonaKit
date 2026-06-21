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
