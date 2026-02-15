import AppKit
import Foundation
import UniformTypeIdentifiers

/// Picks a workspace URL from the local file system.
protocol WorkspacePicking {
  @MainActor
  func pickWorkspaceURL() -> URL?
}

/// Picks a markdown export destination for session preview output.
protocol PreviewExportDestinationPicking {
  @MainActor
  func pickPreviewDestination(suggestedFilename: String) -> URL?
}

/// Writes plain text to the system pasteboard.
protocol PasteboardWriting {
  @MainActor
  func writeString(_ value: String) -> Bool
}

/// Reveals a file URL in Finder.
protocol FileRevealing {
  @MainActor
  func reveal(_ url: URL)
}

/// macOS open-panel implementation for workspace selection.
struct WorkspacePickerClient: WorkspacePicking {
  @MainActor
  func pickWorkspaceURL() -> URL? {
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

/// macOS save-panel implementation for markdown export destination picking.
struct PreviewExportDestinationPickerClient: PreviewExportDestinationPicking {
  @MainActor
  func pickPreviewDestination(suggestedFilename: String) -> URL? {
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
struct PasteboardClient: PasteboardWriting {
  @MainActor
  func writeString(_ value: String) -> Bool {
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    return pasteboard.setString(value, forType: .string)
  }
}

/// macOS Finder implementation for reveal-in-file-viewer actions.
struct FileRevealerClient: FileRevealing {
  @MainActor
  func reveal(_ url: URL) {
    NSWorkspace.shared.activateFileViewerSelecting([url])
  }
}
