import ContextWorkspaceCore
import Foundation
import StudioFoundation
import Testing

@testable import StudioFeatures

/// Coverage for how a store resolves the global library: environment override, the
/// user's `~/.personakit`, or project-only when neither exists.
@MainActor
struct WorkspaceStoreGlobalScopeTests {
  @Test
  func projectOnlyStoreReportsUnresolvedReferencesAsErrors() async throws {
    let (workspaceURL, _, _) = try makeGlobalOnlyReferenceWorkspace()

    // No global library: references to shared entities can't resolve and are real errors.
    let provider = WorkspaceGlobalScopeProvider(initialURL: nil, fallback: { nil })
    let store = WorkspaceStore(globalScopeProvider: provider)

    store.workspaceURL = workspaceURL
    store.loadWorkspace()

    await waitFor { !store.validation.issues.isEmpty }

    let report = StudioValidationReportState(
      snapshot: store.snapshot,
      validation: store.validation,
      validationErrorMessage: store.validationErrorMessage
    )
    #expect(report.issues == store.validation.issues)
    #expect(report.status == .issues(store.validation.issues.count))
  }

  @Test
  func providerFallbackPicksUpLibraryCreatedAfterLaunch() throws {
    let globalScopeURL = try makeTempDirectory().appendingPathComponent(".personakit")
    let provider = WorkspaceGlobalScopeProvider(
      initialURL: nil,
      fallback: {
        WorkspaceScopeResolver.directoryExists(globalScopeURL) ? globalScopeURL : nil
      }
    )

    #expect(provider.current() == nil)

    try FileManager.default.createDirectory(at: globalScopeURL, withIntermediateDirectories: true)

    #expect(provider.current() == globalScopeURL)
  }

  @Test
  func launchConfiguredPrefersEnvironmentOverride() {
    let envPath = "/env/.personakit"
    let store = WorkspaceStore.launchConfigured(
      environment: [StudioLaunchConfiguration.globalScopePathEnvironmentKey: envPath],
      fileEventSource: nil
    )

    #expect(
      store.globalScopeProvider?.current()
        == URL(fileURLWithPath: envPath, isDirectory: true).standardizedFileURL
    )
  }

  @Test
  func launchConfiguredWiresProviderIntoValidation() async throws {
    let (workspaceURL, _, globalScopeURL) = try makeGlobalOnlyReferenceWorkspace()

    // Env override seeds the provider with the fixture global, so the builders never read
    // the real home. This locks the launch path: the wired builders must use the box.
    let store = WorkspaceStore.launchConfigured(
      environment: [
        StudioLaunchConfiguration.globalScopePathEnvironmentKey: globalScopeURL.path()
      ],
      fileEventSource: nil
    )

    store.workspaceURL = workspaceURL
    store.loadWorkspace()

    await waitFor {
      store.validation.issues.isEmpty
        && store.validation.summary.contains("errors=0")
    }
  }
}
