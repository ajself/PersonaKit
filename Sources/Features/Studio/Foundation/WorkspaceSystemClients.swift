import AppKit
import Foundation
import UniformTypeIdentifiers

/// Picks a workspace URL from the local file system.
public protocol WorkspacePicking {
  @MainActor
  func pickWorkspaceURL() -> URL?
}

/// Picks the global PersonaKit library folder to grant Studio read access to.
public protocol GlobalLibraryDirectoryPicking {
  @MainActor
  func pickGlobalLibraryURL() -> URL?
}

/// Picks a markdown export destination for session preview output.
public protocol PreviewExportDestinationPicking {
  @MainActor
  func pickPreviewDestination(suggestedFilename: String) -> URL?
}

/// Writes plain text to the system pasteboard.
public protocol PasteboardWriting {
  @MainActor
  func writeString(_ value: String) -> Bool
}

/// Reveals a file URL in Finder.
public protocol FileRevealing {
  @MainActor
  func reveal(_ url: URL)
}

/// Performs install-related file operations for Studio.
public protocol WorkspaceInstallFileOperating {
  @MainActor
  func copyItem(
    at sourceURL: URL,
    to destinationURL: URL
  ) throws

  @MainActor
  func createDirectory(at url: URL) throws

  @MainActor
  func fileExists(at url: URL) -> Bool

  @MainActor
  func isExecutableFile(at url: URL) -> Bool

  @MainActor
  func moveItem(
    at sourceURL: URL,
    to destinationURL: URL
  ) throws

  @MainActor
  func removeItem(at url: URL) throws

  @MainActor
  func replaceItem(
    at targetURL: URL,
    with sourceURL: URL
  ) throws

  @MainActor
  func setExecutableFile(at url: URL) throws
}

/// Reads and writes OpenCode configuration files for Studio install actions.
public protocol OpenCodeConfigurationFileAccessing {
  @MainActor
  func configExists(at url: URL) -> Bool

  @MainActor
  func readConfigData(at url: URL) throws -> Data

  @MainActor
  func writeConfigData(
    _ data: Data,
    to url: URL
  ) throws
}

/// macOS open-panel implementation for workspace selection.
public struct WorkspacePickerClient: WorkspacePicking {
  public init() {}

  @MainActor
  public func pickWorkspaceURL() -> URL? {
    let panel = NSOpenPanel()
    panel.canChooseDirectories = true
    panel.canChooseFiles = false
    panel.allowsMultipleSelection = false
    panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser
    panel.message = "Choose a folder to use as the PersonaKit workspace."
    panel.prompt = "Open Workspace"

    guard panel.runModal() == .OK else {
      return nil
    }

    return panel.url
  }
}

/// macOS open-panel implementation for granting the global PersonaKit library.
///
/// Defaults to `~/.personakit` but accepts any folder, mirroring the project-workspace
/// open-panel pattern. The folder is sanity-checked for a `Packs/` directory by the
/// caller (a non-blocking warning), not here.
public struct GlobalLibraryDirectoryPickerClient: GlobalLibraryDirectoryPicking {
  public init() {}

  @MainActor
  public func pickGlobalLibraryURL() -> URL? {
    let panel = NSOpenPanel()
    panel.canChooseDirectories = true
    panel.canChooseFiles = false
    panel.allowsMultipleSelection = false
    panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent(".personakit")
    panel.message = "Choose the global PersonaKit library folder to connect."
    panel.prompt = "Connect Library"

    guard panel.runModal() == .OK else {
      return nil
    }

    return panel.url
  }
}

/// macOS save-panel implementation for markdown export destination picking.
public struct PreviewExportDestinationPickerClient: PreviewExportDestinationPicking {
  public init() {}

  @MainActor
  public func pickPreviewDestination(suggestedFilename: String) -> URL? {
    let savePanel = NSSavePanel()

    if let markdownType = UTType(filenameExtension: "md") {
      savePanel.allowedContentTypes = [markdownType]
    } else {
      savePanel.allowedContentTypes = [.plainText]
    }

    savePanel.canCreateDirectories = true
    savePanel.nameFieldStringValue = suggestedFilename
    savePanel.prompt = "Export Preview"
    savePanel.title = "Export Session Preview"

    guard savePanel.runModal() == .OK else {
      return nil
    }

    return savePanel.url
  }
}

/// macOS pasteboard implementation for copy actions.
public struct PasteboardClient: PasteboardWriting {
  public init() {}

  @MainActor
  public func writeString(_ value: String) -> Bool {
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    return pasteboard.setString(value, forType: .string)
  }
}

/// macOS Finder implementation for reveal-in-file-viewer actions.
public struct FileRevealerClient: FileRevealing {
  public init() {}

  @MainActor
  public func reveal(_ url: URL) {
    NSWorkspace.shared.activateFileViewerSelecting([url])
  }
}

/// FileManager-backed install file client.
public struct WorkspaceInstallFileSystemClient: WorkspaceInstallFileOperating {
  private let fileManager: FileManager

  public init(fileManager: FileManager = .default) {
    self.fileManager = fileManager
  }

  @MainActor
  public func copyItem(
    at sourceURL: URL,
    to destinationURL: URL
  ) throws {
    try fileManager.copyItem(
      at: sourceURL,
      to: destinationURL
    )
  }

  @MainActor
  public func createDirectory(at url: URL) throws {
    try fileManager.createDirectory(
      at: url,
      withIntermediateDirectories: true
    )
  }

  @MainActor
  public func fileExists(at url: URL) -> Bool {
    fileManager.fileExists(atPath: url.path())
  }

  @MainActor
  public func isExecutableFile(at url: URL) -> Bool {
    fileManager.isExecutableFile(atPath: url.path())
  }

  @MainActor
  public func moveItem(
    at sourceURL: URL,
    to destinationURL: URL
  ) throws {
    try fileManager.moveItem(
      at: sourceURL,
      to: destinationURL
    )
  }

  @MainActor
  public func removeItem(at url: URL) throws {
    try fileManager.removeItem(at: url)
  }

  @MainActor
  public func replaceItem(
    at targetURL: URL,
    with sourceURL: URL
  ) throws {
    _ = try fileManager.replaceItemAt(
      targetURL,
      withItemAt: sourceURL
    )
  }

  @MainActor
  public func setExecutableFile(at url: URL) throws {
    try fileManager.setAttributes(
      [.posixPermissions: 0o755],
      ofItemAtPath: url.path()
    )
  }
}

/// Data-backed OpenCode configuration file client.
public struct OpenCodeConfigurationFileClient: OpenCodeConfigurationFileAccessing {
  private let fileManager: FileManager

  public init(fileManager: FileManager = .default) {
    self.fileManager = fileManager
  }

  @MainActor
  public func configExists(at url: URL) -> Bool {
    fileManager.fileExists(atPath: url.path())
  }

  @MainActor
  public func readConfigData(at url: URL) throws -> Data {
    try Data(contentsOf: url)
  }

  @MainActor
  public func writeConfigData(
    _ data: Data,
    to url: URL
  ) throws {
    try data.write(
      to: url,
      options: Data.WritingOptions.atomic
    )
  }
}
