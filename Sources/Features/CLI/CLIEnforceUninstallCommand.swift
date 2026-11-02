import ArgumentParser
import ContextCore
import Foundation

/// Removes host enforcement from a project — the reverse of `enforce install`, and as explicit.
///
/// For Claude Code, removes the PersonaKit `PreToolUse` hook from `.claude/settings.json` and the frozen
/// manifests in `.claude/personakit/`. For OpenCode, removes the frozen manifests in `.opencode/personakit/`
/// and never touches OpenCode config. A folder, settings file or `.claude`/`.opencode` directory the removal
/// leaves empty is removed too, so an install into a bare project uninstalls to nothing. Refuses, before
/// changing anything, where install refuses: a symbolic link on the path, or a `*.checks.json` entry that is
/// not a regular file.
struct EnforceUninstallCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "uninstall",
    abstract: "Remove Claude Code or OpenCode enforcement from a project (explicit, idempotent)."
  )

  @Option(name: .customLong("host"), help: "Host to remove enforcement for: claude (default) or opencode.")
  var host: HookCheckHost = .claude

  @Option(
    name: .customLong("project-dir"),
    help: "Project directory that owns .claude/ (.opencode/ with --host opencode; defaults to CWD)."
  )
  var projectDir: String?

  @Flag(name: .customLong("dry-run"), help: "Print what would be removed without changing anything.")
  var dryRun = false

  func run() throws {
    let projectRoot = RootPathResolver().resolve(path: projectDir)
    switch host {
    case .claude:
      try uninstallClaude(projectRoot: projectRoot)
    case .opencode:
      try uninstallOpenCode(projectRoot: projectRoot)
    }
  }

  private func uninstallClaude(projectRoot: URL) throws {
    let claudeDir = projectRoot.appendingPathComponent(".claude")
    let manifestDirectory = claudeDir.appendingPathComponent("personakit")
    let settingsURL = claudeDir.appendingPathComponent("settings.json")

    // A link would point the removal at another tree's settings or manifests, such as ~/.claude.
    try EnforceInstallCommand.refuseSymbolicLinks([claudeDir, manifestDirectory, settingsURL], action: "uninstall")
    let manifests = try Self.manifestNames(in: manifestDirectory)

    let removal: ClaudeCodeSettingsMerger.Removal
    do {
      removal = try ClaudeCodeSettingsMerger.removingPersonaKitEntries(
        from: try EnforceInstallCommand.existingSettings(at: settingsURL, action: "uninstall")
      )
    } catch ClaudeCodeSettingsMerger.MergeError.invalidExistingSettings {
      throw CLIError.failure(
        "Refusing to uninstall: \(settingsURL.path) is not a JSON object, so the PersonaKit hook cannot be "
          + "found in it. Fix it, then run uninstall again."
      )
    }

    guard removal != .nothingToRemove || !manifests.isEmpty else {
      print("No Claude Code enforcement installed in \(projectRoot.path).")
      return
    }

    if dryRun {
      print("# Dry run — nothing written.")
      switch removal {
      case .nothingToRemove:
        break
      case .deleteFile:
        print("# Would remove → \(settingsURL.path)")
      case .write(let settings):
        print("# Settings without the PersonaKit hook → \(settingsURL.path)")
        print(TerminalText.escapingJSON(String(decoding: settings, as: UTF8.self)))
      }
      for name in manifests {
        print(TerminalText.sanitized("# Would remove → \(manifestDirectory.appendingPathComponent(name).path)"))
      }
      return
    }

    // Settings first: a hook left behind with no manifest blocks every call, while a manifest left behind
    // with no hook does nothing.
    switch removal {
    case .nothingToRemove:
      break
    case .deleteFile:
      try Self.unlinkFile(settingsURL.path)
    case .write(let settings):
      try AtomicFileWriter().write(contents: String(decoding: settings, as: UTF8.self) + "\n", to: settingsURL)
    }
    let removed = try Self.removeManifests(manifests, in: manifestDirectory)
    Self.removeIfEmpty([manifestDirectory, claudeDir])

    print("Uninstalled Claude Code enforcement from \(projectRoot.path).")
    if removal != .nothingToRemove {
      print("  removed the PersonaKit hook from \(settingsURL.path)")
    }
    for name in removed {
      print(TerminalText.sanitized("  removed manifest \(manifestDirectory.appendingPathComponent(name).path)"))
    }
    if removal != .nothingToRemove {
      print(EnforceInstallCommand.claudeCodeReloadNote)
    }
  }

  private func uninstallOpenCode(projectRoot: URL) throws {
    let openCodeDir = projectRoot.appendingPathComponent(OpenCodeEnforcement.protectedDirectoryName)
    let manifestDirectory = openCodeDir.appendingPathComponent("personakit")

    try EnforceInstallCommand.refuseSymbolicLinks([openCodeDir, manifestDirectory], action: "uninstall")
    let manifests = try Self.manifestNames(in: manifestDirectory)

    guard !manifests.isEmpty else {
      print("No OpenCode enforcement installed in \(projectRoot.path).")
      return
    }

    if dryRun {
      print("# Dry run — nothing written.")
      for name in manifests {
        print(TerminalText.sanitized("# Would remove → \(manifestDirectory.appendingPathComponent(name).path)"))
      }
      return
    }

    let removed = try Self.removeManifests(manifests, in: manifestDirectory)
    Self.removeIfEmpty([manifestDirectory, openCodeDir])

    print("Uninstalled OpenCode enforcement from \(projectRoot.path).")
    for name in removed {
      print(TerminalText.sanitized("  removed manifest \(manifestDirectory.appendingPathComponent(name).path)"))
    }
    print("Restart OpenCode: until then the plugin blocks the calls it checks, since its manifest is gone.")
  }

  /// The `*.checks.json` names in `directory`, as install lists them, failing when it exists but cannot be
  /// listed: reading that as no manifests would report enforcement removed while one is still in force.
  private static func manifestNames(in directory: URL) throws -> [String] {
    if FileManager.default.fileExists(atPath: directory.path) {
      do {
        _ = try FileManager.default.contentsOfDirectory(atPath: directory.path)
      } catch {
        throw CLIError.failure(
          "Refusing to uninstall: could not list \(directory.path): \(error.localizedDescription) "
            + "Make it a readable folder, then run uninstall again."
        )
      }
    }
    return try EnforceInstallCommand.regularManifestEntryNames(in: directory, action: "uninstall")
  }

  /// Removes each of `names` from `directory` that is still a regular file, returning the names removed.
  private static func removeManifests(_ names: [String], in directory: URL) throws -> [String] {
    var removed: [String] = []
    for name in names {
      let path = directory.appendingPathComponent(name).path
      guard EnforceInstallCommand.isRegularFile(path) else {
        continue
      }
      try unlinkFile(path)
      removed.append(name)
    }
    return removed
  }

  /// Removes one file with `unlink(2)`, which removes a link rather than its target and refuses a directory, so a
  /// directory swapped in after the checks is never deleted recursively.
  private static func unlinkFile(_ path: String) throws {
    guard unlink(path) == 0 else {
      throw CLIError.failure(
        "Uninstall could not remove \(path): \(String(cString: strerror(errno))). Check the folder, then run "
          + "uninstall again."
      )
    }
  }

  /// Removes each directory in `directories`, in order, that is empty. `rmdir(2)` refuses a non-empty directory
  /// and a symbolic link, so nothing else is ever removed.
  private static func removeIfEmpty(_ directories: [URL]) {
    for directory in directories {
      _ = rmdir(directory.path)
    }
  }
}
