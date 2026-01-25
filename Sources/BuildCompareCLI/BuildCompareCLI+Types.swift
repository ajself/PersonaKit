import Foundation

/// Captures the outcome of running a command-line tool.
struct CommandResult {
  let exitCode: Int32
  let output: String
  let duration: TimeInterval
}

/// User-facing errors surfaced by the CLI.
enum ToolError: Error, CustomStringConvertible {
  case usage(String)
  case commandFailed(String)
  case notFound(String)

  var description: String {
    switch self {
    case .usage(let message):
      return message
    case .commandFailed(let message):
      return message
    case .notFound(let message):
      return message
    }
  }
}

/// Parsed command-line options for a build-compare run.
struct Options {
  let baseSha: String
  let headSha: String
  let outputRoot: URL
  let worktreeRoot: URL
  let workspace: String?
  let scheme: String
  let schemeIsDefault: Bool
  let configuration: String
  let configPath: String?
  let allowTestFailures: Bool
  let keepWorktrees: Bool
  let runTests: Bool
  let runIncremental: Bool
}
