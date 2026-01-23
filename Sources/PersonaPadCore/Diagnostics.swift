import Foundation

public struct PersonaSource: Sendable, Hashable {
  public enum Kind: String, Sendable, Hashable {
    case builtIn
    case user
    case project
    case adhoc
  }

  public let kind: Kind
  public let url: URL?

  public init(kind: Kind, url: URL? = nil) {
    self.kind = kind
    self.url = url
  }

  public var idFallback: String {
    if let url { return url.deletingPathExtension().lastPathComponent }
    return "adhoc"
  }

  public var displayNameFallback: String {
    if let url { return url.lastPathComponent }
    return "Adhoc"
  }

  public var displayLabel: String {
    if let url {
      return "\(kind.rawValue): \(url.path)"
    }
    return kind.rawValue
  }
}

public struct Diagnostic: Sendable, Hashable {
  public enum Severity: String, Sendable, Hashable {
    case error
    case warning
  }

  public let severity: Severity
  public let source: PersonaSource
  public let message: String

  public var userFacingMessage: String {
    "\(message) [Source: \(source.displayLabel)]"
  }

  public static func error(source: PersonaSource, message: String) -> Diagnostic {
    Diagnostic(severity: .error, source: source, message: message)
  }

  public static func warning(source: PersonaSource, message: String) -> Diagnostic {
    Diagnostic(severity: .warning, source: source, message: message)
  }
}

public struct DiagnosticError: Error, Sendable {
  public let diagnostics: [Diagnostic]

  public init(_ diagnostics: [Diagnostic]) {
    self.diagnostics = diagnostics
  }
}
