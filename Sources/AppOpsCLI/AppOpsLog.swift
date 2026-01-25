import Foundation
import Logging

enum AppOpsLog {
  private static var didBootstrap = false
  private static let bootstrapLock = NSLock()

  static var logger = Logger(label: "PersonaKit.AppOps")

  static func configure(level: Logger.Level) {
    bootstrapIfNeeded()
    logger.logLevel = level
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
    bootstrapLock.lock()
    defer { bootstrapLock.unlock() }
    guard !didBootstrap else { return }
    LoggingSystem.bootstrap { label in
      StreamLogHandler.standardError(label: label)
    }
    didBootstrap = true
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
