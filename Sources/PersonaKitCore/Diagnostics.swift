import Foundation

/// Describes where a persona was loaded from.
public struct PersonaSource: Sendable, Hashable {
  /// The origin classification for a persona source.
  public enum Kind: String, Sendable, Hashable {
    case builtIn
    case user
    case project
    case adhoc
  }

  public let kind: Kind
  public let url: URL?

  /// Creates a source with an optional backing URL.
  public init(kind: Kind, url: URL? = nil) {
    self.kind = kind
    self.url = url
  }

  /// A fallback identifier derived from the source when pack metadata is missing.
  public var idFallback: String {
    if let url { return url.deletingPathExtension().lastPathComponent }
    return "adhoc"
  }

  /// A fallback display name derived from the source when pack metadata is missing.
  public var displayNameFallback: String {
    if let url { return url.lastPathComponent }
    return "Adhoc"
  }

  /// A label combining the source kind and URL for diagnostics.
  public var displayLabel: String {
    if let url {
      return "\(kind.rawValue): \(url.path)"
    }
    return kind.rawValue
  }
}

/// A structured validation or loading diagnostic.
public struct Diagnostic: Sendable, Hashable {
  /// The severity of a diagnostic.
  public enum Severity: String, Sendable, Hashable {
    case error
    case warning
  }

  public let severity: Severity
  public let source: PersonaSource
  public let message: String

  /// A formatted diagnostic message including source context.
  public var userFacingMessage: String {
    "\(message) [Source: \(source.displayLabel)]"
  }

  /// Creates an error diagnostic for the given source.
  public static func error(source: PersonaSource, message: String) -> Diagnostic {
    Diagnostic(severity: .error, source: source, message: message)
  }

  /// Creates a warning diagnostic for the given source.
  public static func warning(source: PersonaSource, message: String) -> Diagnostic {
    Diagnostic(severity: .warning, source: source, message: message)
  }
}

/// Error wrapper for one or more diagnostics.
public struct DiagnosticError: Error, Sendable {
  public let diagnostics: [Diagnostic]

  /// Creates an error that carries diagnostics for higher-level handling.
  public init(_ diagnostics: [Diagnostic]) {
    self.diagnostics = diagnostics
  }
}
