import ContextCore
import Foundation

/// Package-scoped state container for workspace validation results.
package struct WorkspaceValidationState: Sendable {
  package private(set) var snapshot: WorkspaceValidationSnapshot
  package private(set) var errorMessage: String?

  package init(
    snapshot: WorkspaceValidationSnapshot = .empty,
    errorMessage: String? = nil
  ) {
    self.snapshot = snapshot
    self.errorMessage = errorMessage
  }

  package mutating func setSnapshot(_ snapshot: WorkspaceValidationSnapshot) {
    self.snapshot = snapshot
  }

  package mutating func setErrorMessage(_ message: String?) {
    errorMessage = message
  }
}
