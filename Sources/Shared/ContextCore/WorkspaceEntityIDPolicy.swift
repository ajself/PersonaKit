import Foundation

/// Shared identifier policy used for workspace-managed file-backed entities.
public enum WorkspaceEntityIDPolicy {
  /// Returns an identifier trimmed of surrounding whitespace and newlines.
  public static func normalized(_ value: String) -> String {
    value.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  /// Validates a normalized identifier for safe file-backed usage.
  public static func isValid(_ value: String) -> Bool {
    let allowedCharacters = CharacterSet(
      charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_."
    )

    if value.isEmpty {
      return false
    }

    if value.rangeOfCharacter(from: allowedCharacters.inverted) != nil {
      return false
    }

    if value.hasPrefix(".") {
      return false
    }

    return value != "." && value != ".."
  }
}
