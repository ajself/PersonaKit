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

/// Text for a terminal: strips the characters that let `.personakit` content steer one.
///
/// A repo's entity text could otherwise retitle or clear the terminal, write the clipboard, or hide or
/// reorder text so a person reviewing output does not see what an agent reads.
enum TerminalText {
  /// Removes C0 controls other than tab and newline, DEL, C1 controls, line and paragraph separators,
  /// bidirectional marks, overrides and isolates, invisible formatting and filler characters, Unicode tag
  /// characters, and the supplementary variation selectors. The last two render as nothing but a model still
  /// reads them. ZWJ, ZWNJ and the basic variation selectors stay, since emoji and many scripts need them.
  static func sanitized(_ text: String) -> String {
    String(String.UnicodeScalarView(text.unicodeScalars.filter(isAllowed)))
  }

  /// Escapes the same characters as `\uXXXX` in a JSON document, so it stays exact but prints safely. A JSON
  /// encoder escapes only C0 controls, and outside strings a document holds only ASCII structure and
  /// whitespace, so every character escaped here sits inside a string.
  static func escapingJSON(_ json: String) -> String {
    var result = String.UnicodeScalarView()
    for scalar in json.unicodeScalars {
      guard !isAllowed(scalar) else {
        result.append(scalar)
        continue
      }
      for unit in String(scalar).utf16 {
        result.append(contentsOf: String(format: "\\u%04x", unit).unicodeScalars)
      }
    }
    return String(result)
  }

  private static func isAllowed(_ scalar: Unicode.Scalar) -> Bool {
    switch scalar.value {
    case 0x09, 0x0A:
      return true
    case 0x00...0x1F, 0x7F...0x9F, 0x00AD, 0x034F, 0x061C, 0x115F, 0x1160, 0x180E, 0x200B, 0x200E, 0x200F,
      0x2028, 0x2029, 0x202A...0x202E, 0x2060...0x2069, 0x3164, 0xFEFF, 0xFFF9...0xFFFB, 0xE0000...0xE007F,
      0xE0100...0xE01EF:
      return false
    default:
      return true
    }
  }
}

/// `stderr` text stream used by ArgumentParser command implementations. Every message is terminal text,
/// so it is sanitized.
struct StandardError: TextOutputStream {
  mutating func write(_ string: String) {
    guard let data = TerminalText.sanitized(string).data(using: .utf8) else { return }
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
        // The throwing read: `readDataToEndOfFile()` raises an Objective-C exception on a read error,
        // which aborts the process instead of reaching the caller's catch.
        let data = try FileHandle.standardInput.readToEnd() ?? Data()

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
