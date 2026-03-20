import ArgumentParser
import ContextCore
import Foundation

/// Generates or checks committed operator docs derived from workstream metadata.
struct WorkstreamDocsCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "workstream-docs",
    abstract: "Generate or check workstream operator docs."
  )

  @OptionGroup
  var root: ExplicitProjectRootOptions

  @Flag(name: .customLong("write"), help: "Regenerate committed workstream docs.")
  var shouldWrite = false

  @Flag(name: .customLong("check"), help: "Fail when committed workstream docs drift.")
  var shouldCheck = false

  func run() throws {
    guard shouldWrite != shouldCheck else {
      throw CLIError.failure(
        "workstream-docs requires exactly one of --write or --check."
      )
    }

    let rootURL = try CLIHelpers.resolveExplicitProjectRoot(path: root.rootPath)
    let projectRootURL = rootURL.deletingLastPathComponent()
    let workstreamDirectoryURL = projectRootURL.appendingPathComponent(
      WorkstreamDocsBuilder.workstreamDirectoryRelativePath
    )
    let sessionDirectoryURL = projectRootURL.appendingPathComponent(
      WorkstreamDocsBuilder.sessionDirectoryRelativePath
    )

    guard FileManager.default.fileExists(atPath: workstreamDirectoryURL.path) else {
      throw CLIError.failure(
        "Missing expected operator doc: \(workstreamDirectoryURL.path)"
      )
    }

    guard FileManager.default.fileExists(atPath: sessionDirectoryURL.path) else {
      throw CLIError.failure(
        "Missing expected operator doc: \(sessionDirectoryURL.path)"
      )
    }

    let validation = try Validator.validate(root: rootURL)
    if !validation.errors.isEmpty {
      print(validation.summary)
      for error in validation.errors {
        print(error.lineDescription())
      }
      throw ExitCode.failure
    }

    let currentWorkstreamDirectory = try String(
      contentsOf: workstreamDirectoryURL,
      encoding: .utf8
    )
    let currentSessionDirectory = try String(
      contentsOf: sessionDirectoryURL,
      encoding: .utf8
    )
    let output = try WorkstreamDocsBuilder.buildOutput(
      root: rootURL,
      currentSessionDirectory: currentSessionDirectory
    )

    if shouldCheck {
      var driftedPaths: [String] = []

      if currentWorkstreamDirectory != output.workstreamDirectory {
        driftedPaths.append(WorkstreamDocsBuilder.workstreamDirectoryRelativePath)
      }

      if currentSessionDirectory != output.sessionDirectory {
        driftedPaths.append(WorkstreamDocsBuilder.sessionDirectoryRelativePath)
      }

      if !driftedPaths.isEmpty {
        var stderrStream = StandardError()
        for path in driftedPaths {
          stderrStream.write("Drift detected: \(path)\n")
        }
        throw ExitCode.failure
      }

      return
    }

    if currentWorkstreamDirectory != output.workstreamDirectory {
      try AtomicFileWriter().write(
        contents: output.workstreamDirectory,
        to: workstreamDirectoryURL
      )
    }

    if currentSessionDirectory != output.sessionDirectory {
      try AtomicFileWriter().write(
        contents: output.sessionDirectory,
        to: sessionDirectoryURL
      )
    }
  }
}

/// Imports legacy markdown operational records into canonical JSONL streams.
struct MigrateLogRecordsCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "migrate-log-records",
    abstract: "Bootstrap canonical operational-record JSONL files from legacy markdown ledgers."
  )

  @OptionGroup
  var root: ExplicitProjectRootOptions

  @Flag(name: .customLong("write"), help: "Write imported canonical JSONL bootstrap output.")
  var shouldWrite = false

  @Flag(name: .customLong("check"), help: "Check legacy bootstrap output against committed canonical JSONL files.")
  var shouldCheck = false

  func run() throws {
    guard shouldWrite != shouldCheck else {
      throw CLIError.failure(
        "migrate-log-records requires exactly one of --write or --check."
      )
    }

    let rootURL = try CLIHelpers.resolveExplicitProjectRoot(path: root.rootPath)
    let projectRootURL = rootURL.deletingLastPathComponent()
    let validation = try Validator.validate(root: rootURL)
    if !validation.errors.isEmpty {
      print(validation.summary)
      for error in validation.errors {
        print(error.lineDescription())
      }
      throw ExitCode.failure
    }

    let output = try OperationalRecordBuilder.buildMigrationOutput(root: rootURL)
    let currentFiles = try loadCurrentFiles(
      relativePaths: output.files.keys.sorted(),
      projectRootURL: projectRootURL
    )

    if shouldCheck {
      let driftedPaths = output.files.keys.sorted().filter { relativePath in
        currentFiles[relativePath] != output.files[relativePath]
      }

      if !driftedPaths.isEmpty {
        var stderrStream = StandardError()
        for path in driftedPaths {
          stderrStream.write("Drift detected: \(path)\n")
        }
        throw ExitCode.failure
      }

      return
    }

    try writeChangedFiles(
      output.files,
      currentFiles: currentFiles,
      projectRootURL: projectRootURL
    )
  }
}

/// Generates or checks markdown companion docs for canonical operational records.
struct LogDocsCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "log-docs",
    abstract: "Generate or check operational-record markdown companion docs."
  )

  @OptionGroup
  var root: ExplicitProjectRootOptions

  @Flag(name: .customLong("write"), help: "Regenerate operational-record companion docs.")
  var shouldWrite = false

  @Flag(name: .customLong("check"), help: "Fail when operational-record companion docs drift.")
  var shouldCheck = false

  func run() throws {
    guard shouldWrite != shouldCheck else {
      throw CLIError.failure(
        "log-docs requires exactly one of --write or --check."
      )
    }

    let rootURL = try CLIHelpers.resolveExplicitProjectRoot(path: root.rootPath)
    let projectRootURL = rootURL.deletingLastPathComponent()
    let validation = try Validator.validate(root: rootURL)
    if !validation.errors.isEmpty {
      print(validation.summary)
      for error in validation.errors {
        print(error.lineDescription())
      }
      throw ExitCode.failure
    }

    let output = try OperationalRecordBuilder.buildDocsOutput(root: rootURL)
    let currentFiles = try loadCurrentFiles(
      relativePaths: output.files.keys.sorted(),
      projectRootURL: projectRootURL
    )

    if shouldCheck {
      let driftedPaths = output.files.keys.sorted().filter { relativePath in
        currentFiles[relativePath] != output.files[relativePath]
      }

      if !driftedPaths.isEmpty {
        var stderrStream = StandardError()
        for path in driftedPaths {
          stderrStream.write("Drift detected: \(path)\n")
        }
        throw ExitCode.failure
      }

      return
    }

    try writeChangedFiles(
      output.files,
      currentFiles: currentFiles,
      projectRootURL: projectRootURL
    )
  }
}
