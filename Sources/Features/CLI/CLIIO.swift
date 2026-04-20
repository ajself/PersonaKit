import AppKit
import Darwin
import Foundation

/// CLI-specific error type for user-facing failures.
enum CLIError: LocalizedError {
  case failure(String)

  /// User-facing error description.
  var errorDescription: String? {
    switch self {
    case .failure(let message):
      return message
    }
  }
}

/// `stderr` text stream used by ArgumentParser command implementations.
struct StandardError: TextOutputStream {
  mutating func write(_ string: String) {
    guard let data = string.data(using: .utf8) else { return }
    FileHandle.standardError.write(data)
  }
}

/// Injectable interactive CLI IO used by prompt-driven commands and stdin reads.
struct CLIInteractiveIO: Sendable {
  let isInteractive: @Sendable () -> Bool
  let readLine: @Sendable () -> String?
  let readStdinToEnd: @Sendable () throws -> String

  static func live() -> CLIInteractiveIO {
    CLIInteractiveIO(
      isInteractive: {
        isatty(STDIN_FILENO) != 0
      },
      readLine: {
        Swift.readLine(strippingNewline: true)
      },
      readStdinToEnd: {
        let data = FileHandle.standardInput.readDataToEndOfFile()

        guard let text = String(data: data, encoding: .utf8) else {
          throw CLIError.failure("Failed to read UTF-8 text from stdin.")
        }

        return text
      }
    )
  }
}

/// Injectable clipboard IO used by copy-oriented CLI commands.
struct CLIClipboardIO: Sendable {
  let writeString: @Sendable (String) -> Bool

  static func live() -> CLIClipboardIO {
    CLIClipboardIO(
      writeString: { value in
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        return pasteboard.setString(value, forType: .string)
      }
    )
  }
}

/// Normalized resolved session identifiers used by export and graph commands.
struct SessionInput {
  let personaId: String
  let directiveId: String
  let kitOverrides: [String]
}

/// Resolves CLI path inputs into standardized absolute URLs.
struct RootPathResolver {
  private let fileManager = FileManager.default

  /// Expands and resolves an optional path.
  ///
  /// - Parameter path: Optional path input; defaults to current directory.
  /// - Returns: Standardized absolute file URL.
  func resolve(path: String?) -> URL {
    let inputPath = path ?? fileManager.currentDirectoryPath
    let expanded = (inputPath as NSString).expandingTildeInPath
    let absolutePath: String
    if expanded.hasPrefix("/") {
      absolutePath = expanded
    } else {
      absolutePath = (fileManager.currentDirectoryPath as NSString)
        .appendingPathComponent(expanded)
    }
    return URL(fileURLWithPath: absolutePath).standardizedFileURL
  }
}

/// Writes UTF-8 files atomically, creating parent directories as needed.
struct AtomicFileWriter {
  /// Writes string content to disk using UTF-8 encoding and atomic replacement.
  func write(contents: String, to url: URL) throws {
    guard let data = contents.data(using: .utf8) else {
      throw CLIError.failure("Failed to encode export output as UTF-8.")
    }
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try data.write(to: url, options: .atomic)
  }
}

enum CLIFileIO {
  static func loadCurrentFiles(
    relativePaths: [String],
    projectRootURL: URL
  ) throws -> [String: String] {
    var currentFiles: [String: String] = [:]

    for relativePath in relativePaths {
      let url = projectRootURL.appendingPathComponent(relativePath)
      if FileManager.default.fileExists(atPath: url.path) {
        currentFiles[relativePath] = try String(contentsOf: url, encoding: .utf8)
      } else {
        currentFiles[relativePath] = nil
      }
    }

    return currentFiles
  }

  static func writeChangedFiles(
    _ files: [String: String],
    currentFiles: [String: String],
    projectRootURL: URL
  ) throws {
    for relativePath in files.keys.sorted() {
      guard let contents = files[relativePath] else {
        continue
      }

      if currentFiles[relativePath] != contents {
        try AtomicFileWriter().write(
          contents: contents,
          to: projectRootURL.appendingPathComponent(relativePath)
        )
      }
    }
  }
}
