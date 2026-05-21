import Foundation

/// Stable automation identifiers for Relationship Map visual review tooling.
enum RelationshipMapAutomationIdentifier {
  static let mapCanvas = "relationship-map-canvas"
  static let refresh = "relationship-map-refresh"
  static let resetLayout = "relationship-map-reset-layout"
  static let searchField = "relationship-map-search"
  static let focusSelectedSession = "relationship-map-focus-selected-session"

  static func node(
    key: String
  ) -> String {
    "relationship-map-node-\(sanitizedToken(key))-\(stableHashToken(key))"
  }

  static func sanitizedToken(
    _ rawValue: String
  ) -> String {
    var result = ""
    var lastAppendedSeparator = false

    for scalar in rawValue.lowercased().unicodeScalars {
      if isAllowedIdentifierScalar(scalar) {
        result.unicodeScalars.append(scalar)
        lastAppendedSeparator = false
      } else if !lastAppendedSeparator {
        result.append("-")
        lastAppendedSeparator = true
      }
    }

    let trimmedResult = result.trimmingCharacters(in: CharacterSet(charactersIn: "-"))

    if trimmedResult.isEmpty {
      return "unknown"
    }

    return trimmedResult
  }

  private static func isAllowedIdentifierScalar(
    _ scalar: UnicodeScalar
  ) -> Bool {
    switch scalar.value {
    case 48...57, 97...122:
      return true
    default:
      return false
    }
  }

  private static func stableHashToken(
    _ rawValue: String
  ) -> String {
    let offsetBasis = UInt32(2_166_136_261)
    let prime = UInt32(16_777_619)
    let hash = rawValue.utf8.reduce(offsetBasis) { partialResult, byte in
      (partialResult ^ UInt32(byte)) &* prime
    }

    return String(format: "%08x", hash)
  }
}
