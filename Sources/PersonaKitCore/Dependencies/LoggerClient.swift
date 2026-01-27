import Dependencies
import Foundation
import OSLog

/// Dependency wrapper for logging PersonaKit core events.
public struct LoggerClient: Sendable {
  public var info: @Sendable (String) -> Void
  public var warning: @Sendable (String) -> Void
  public var error: @Sendable (String) -> Void

  /// Creates a logger client from the provided closures.
  public init(
    info: @escaping @Sendable (String) -> Void,
    warning: @escaping @Sendable (String) -> Void,
    error: @escaping @Sendable (String) -> Void
  ) {
    self.info = info
    self.warning = warning
    self.error = error
  }
}

extension LoggerClient: DependencyKey {
  private static let coreLogger = Logger(subsystem: "PersonaKit", category: "Core")

  public static let liveValue = LoggerClient(
    info: { message in
      coreLogger.info("\(message, privacy: .public)")
    },
    warning: { message in
      coreLogger.warning("\(message, privacy: .public)")
    },
    error: { message in
      coreLogger.error("\(message, privacy: .public)")
    }
  )

  public static var testValue: LoggerClient { liveValue }
  public static var previewValue: LoggerClient { liveValue }
}

extension DependencyValues {
  /// Accessor for the ``LoggerClient`` dependency.
  public var logger: LoggerClient {
    get { self[LoggerClient.self] }
    set { self[LoggerClient.self] = newValue }
  }
}
