import AppOpsCore
import Foundation

extension AppOpsCLI {
  /// Runs a tool via `/usr/bin/env`, capturing combined output and elapsed time.
  private static func runTool(_ tool: String, _ args: [String], cwd: URL? = nil) throws -> CommandResult {
    AppOpsLog.logger.debug("Build run: executing \(tool) \(args.joined(separator: " ")).")
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = [tool] + args
    process.currentDirectoryURL = cwd
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe
    let start = Date()
    try process.run()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    let end = Date()
    let output = String(data: data, encoding: .utf8) ?? ""
    let result = CommandResult(
      exitCode: process.terminationStatus,
      output: output,
      duration: end.timeIntervalSince(start)
    )
    AppOpsLog.logger.debug(
      "Build run: \(tool) exited \(result.exitCode) in \(AppOpsLog.formatSeconds(result.duration))s."
    )
    return result
  }

  private static func resolveRevisionSha(repo: URL) throws -> String {
    let result = try runTool("git", ["rev-parse", "HEAD"], cwd: repo)
    if result.exitCode != 0 {
      throw BuildRunError.commandFailed("git rev-parse failed:\n\(result.output)")
    }
    let sha = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
    if sha.isEmpty {
      throw BuildRunError.commandFailed("git rev-parse returned an empty SHA.")
    }
    return sha
  }

  /// Calculates the total size of a directory tree in bytes.
  private static func directorySize(at url: URL) -> Int64 {
    let fm = FileManager.default
    guard let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) else {
      return 0
    }
    var total: Int64 = 0
    for case let fileURL as URL in enumerator {
      guard let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
        let size = values.fileSize
      else {
        continue
      }
      total += Int64(size)
    }
    return total
  }

  /// Returns the size of a single file in bytes.
  private static func fileSize(at url: URL) -> Int64 {
    let fm = FileManager.default
    guard let attrs = try? fm.attributesOfItem(atPath: url.path),
      let size = attrs[.size] as? NSNumber
    else {
      return 0
    }
    return size.int64Value
  }

  /// Ensures a directory exists, creating intermediate directories as needed.
  private static func ensureDirectory(_ url: URL) throws {
    try FileManager.default.createDirectory(
      at: url,
      withIntermediateDirectories: true,
      attributes: nil
    )
  }

  /// Writes log text to disk using UTF-8 encoding.
  private static func writeLog(_ text: String, to url: URL) throws {
    try text.write(to: url, atomically: true, encoding: .utf8)
  }

  /// Adds a git worktree at the requested path for the given revision.
  private static func addWorktree(repo: URL, path: URL, revision: String) throws {
    let result = try runTool("git", ["worktree", "add", path.path, revision], cwd: repo)
    if result.exitCode != 0 {
      throw BuildRunError.commandFailed("git worktree add failed:\n\(result.output)")
    }
  }

  /// Removes a git worktree at the requested path.
  private static func removeWorktree(repo: URL, path: URL) throws {
    let result = try runTool("git", ["worktree", "remove", path.path], cwd: repo)
    if result.exitCode != 0 {
      throw BuildRunError.commandFailed("git worktree remove failed:\n\(result.output)")
    }
  }

  /// Detects the workspace name in a repo, honoring an explicit override.
  private static func detectWorkspace(in repo: URL, override: String?) throws -> String {
    if let override {
      return override
    }
    let fm = FileManager.default
    let preferred = ["PersonaKit.xcworkspace"]
    for name in preferred {
      let path = repo.appendingPathComponent(name)
      if fm.fileExists(atPath: path.path) {
        return name
      }
    }

    let contents = try fm.contentsOfDirectory(atPath: repo.path)
    if let workspace = contents.first(where: { $0.hasSuffix(".xcworkspace") }) {
      return workspace
    }

    throw BuildRunError.notFound(
      "No .xcworkspace found in \(repo.path). Use --build-workspace to override."
    )
  }

  /// Selects the scheme, honoring the caller's default.
  private static func resolveScheme(
    defaultScheme: String
  ) -> String {
    return defaultScheme
  }

  /// Provides the fallback app build recipes when no config is supplied.
  private static func defaultAppRecipes() -> [AppBuildRecipe] {
    [
      AppBuildRecipe(name: "default", workspace: nil, scheme: nil, xcodebuildArgs: []),
      AppBuildRecipe(
        name: "legacy-driver",
        workspace: nil,
        scheme: nil,
        xcodebuildArgs: ["SWIFT_USE_INTEGRATED_DRIVER=NO"]
      ),
      AppBuildRecipe(
        name: "legacy-explicit-modules-off",
        workspace: nil,
        scheme: nil,
        xcodebuildArgs: ["SWIFT_ENABLE_EXPLICIT_MODULES=NO"]
      ),
      AppBuildRecipe(
        name: "legacy-build-system",
        workspace: nil,
        scheme: nil,
        xcodebuildArgs: ["-UseNewBuildSystem=NO"]
      ),
      AppBuildRecipe(
        name: "legacy-build-system-driver",
        workspace: nil,
        scheme: nil,
        xcodebuildArgs: ["-UseNewBuildSystem=NO", "SWIFT_USE_INTEGRATED_DRIVER=NO"]
      ),
    ]
  }

  /// Loads a build-run configuration JSON from disk when available.
  private static func loadConfig(repo: URL, overridePath: String?) throws -> BuildRunConfig? {
    let fm = FileManager.default
    let configURL: URL?
    if let overridePath {
      configURL = URL(fileURLWithPath: overridePath)
    } else {
      let defaultPath = repo.appendingPathComponent("Scripts/build-run.json")
      configURL = fm.fileExists(atPath: defaultPath.path) ? defaultPath : nil
    }

    guard let url = configURL else { return nil }
    let data = try Data(contentsOf: url)
    let decoder = JSONDecoder()
    return try decoder.decode(BuildRunConfig.self, from: data)
  }
}
