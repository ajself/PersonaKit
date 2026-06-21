import ContextWorkspaceCore
import Foundation
import Synchronization
import Testing

/// Coverage for the late-bindable global-scope provider seam shared by the workspace
/// builders/validator (Tranche 4, S1).
struct WorkspaceGlobalScopeProviderTests {
  @Test
  func validatorResolvesGlobalOnlyReferencesThroughProvider() throws {
    let (workspaceURL, _, globalScopeURL) = try makeGlobalOnlyReferenceWorkspace()

    // Project scope only: the session's persona/directive are missing → false positives.
    let projectOnly = try WorkspaceValidator(globalScopeProvider: { nil })
      .validate(workspaceURL: workspaceURL)
    #expect(!projectOnly.issues.isEmpty)

    // Granted global scope: the same references resolve → clean.
    let merged = try WorkspaceValidator(globalScopeProvider: { globalScopeURL })
      .validate(workspaceURL: workspaceURL)
    #expect(merged.issues.isEmpty)
  }

  @Test
  func providerIsReadAtValidationTimeNotFrozenAtInit() throws {
    let (workspaceURL, _, globalScopeURL) = try makeGlobalOnlyReferenceWorkspace()
    let backing = Mutex<URL?>(nil)
    let validator = WorkspaceValidator(
      globalScopeProvider: { backing.withLock { $0 } }
    )

    let before = try validator.validate(workspaceURL: workspaceURL)
    #expect(!before.issues.isEmpty)

    // Late-bind the grant: the same validator instance must re-resolve against it.
    backing.withLock { $0 = globalScopeURL }
    let after = try validator.validate(workspaceURL: workspaceURL)
    #expect(after.issues.isEmpty)
  }

  @Test
  func urlAndProviderInitsProduceIdenticalResults() throws {
    let (workspaceURL, _, globalScopeURL) = try makeGlobalOnlyReferenceWorkspace()

    let viaURL = try WorkspaceValidator(globalScopeURL: globalScopeURL)
      .validate(workspaceURL: workspaceURL)
    let viaProvider = try WorkspaceValidator(globalScopeProvider: { globalScopeURL })
      .validate(workspaceURL: workspaceURL)

    #expect(viaURL == viaProvider)
  }
}
