import Foundation
import Logging

enum AppOpsLog {
  private final class State: @unchecked Sendable {
    let lock = NSLock()
    var didBootstrap = false
    var level: Logger.Level = .info
  }

  private static let state = State()

  static func configure(level: Logger.Level) {
    bootstrapIfNeeded()
    state.lock.lock()
    state.level = level
    state.lock.unlock()
  }

  static var logger: Logger {
    bootstrapIfNeeded()
    state.lock.lock()
    let level = state.level
    state.lock.unlock()
    var logger = Logger(label: "PersonaKit.AppOps")
    logger.logLevel = level
    return logger
  }

  static func resolveLevel(_ value: String?) throws -> Logger.Level {
    guard let value else { return .info }
    if let level = parseLevel(value) {
      return level
    }
    throw AppOpsCLI.AppOpsError(
      "Invalid log level '\(value)'. Use trace|debug|info|notice|warning|error|critical."
    )
  }

  static func formatSeconds(_ seconds: Double) -> String {
    String(format: "%.3f", seconds)
  }

  private static func bootstrapIfNeeded() {
    state.lock.lock()
    defer { state.lock.unlock() }
    guard !state.didBootstrap else { return }
    LoggingSystem.bootstrap { label in
      StreamLogHandler.standardError(label: label)
    }
    state.didBootstrap = true
  }

  private static func parseLevel(_ value: String) -> Logger.Level? {
    switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
    case "trace":
      return .trace
    case "debug":
      return .debug
    case "info":
      return .info
    case "notice":
      return .notice
    case "warning", "warn":
      return .warning
    case "error":
      return .error
    case "critical", "fatal":
      return .critical
    default:
      return nil
    }
  }
}
