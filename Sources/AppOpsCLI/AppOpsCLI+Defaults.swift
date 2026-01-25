import Foundation
import PersonaKitCore
import PersonaKitResources

extension AppOpsCLI {
  struct AppOpsError: Error, CustomStringConvertible {
    let message: String

    init(_ message: String) {
      self.message = message
    }

    var description: String {
      message
    }
  }

  static func defaultRepoRoot() throws -> URL {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = ["git", "rev-parse", "--show-toplevel"]
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe
    try process.run()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    let output = String(data: data, encoding: .utf8) ?? ""
    if process.terminationStatus != 0 {
      throw AppOpsError("Failed to locate repo root:\n\(output)")
    }
    let path = output.trimmingCharacters(in: .whitespacesAndNewlines)
    if path.isEmpty {
      throw AppOpsError("Empty repo root from git.")
    }
    return URL(fileURLWithPath: path)
  }

  static func defaultRunCommand(_ args: [String]) -> String? {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = args
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe
    do {
      try process.run()
    } catch {
      return nil
    }
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else { return nil }
    let output = String(data: data, encoding: .utf8) ?? ""
    let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }

  static func defaultBuiltInPackURLs(repoRoot: URL) -> [URL] {
    var urls = PersonaPackLocator.builtInPackURLs(bundle: PersonaKitResources.bundle)
    if urls.isEmpty {
      urls = PersonaPackLocator.builtInPackURLs(repoRoot: repoRoot)
    }
    return urls
  }
}
