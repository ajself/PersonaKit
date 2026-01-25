import AppKit
import Dependencies
import Foundation
import UniformTypeIdentifiers

public struct AppClient: Sendable {
  public var selectPackURL: @MainActor @Sendable () -> URL?
  public var confirmRemovePack: @MainActor @Sendable () -> Bool
  public var presentError: @MainActor @Sendable (_ title: String, _ message: String) -> Void
  public var openURL: @MainActor @Sendable (URL) -> Void
  public var copyToClipboard: @MainActor @Sendable (String) -> Void

  public init(
    selectPackURL: @escaping @MainActor @Sendable () -> URL?,
    confirmRemovePack: @escaping @MainActor @Sendable () -> Bool,
    presentError: @escaping @MainActor @Sendable (_ title: String, _ message: String) -> Void,
    openURL: @escaping @MainActor @Sendable (URL) -> Void,
    copyToClipboard: @escaping @MainActor @Sendable (String) -> Void
  ) {
    self.selectPackURL = selectPackURL
    self.confirmRemovePack = confirmRemovePack
    self.presentError = presentError
    self.openURL = openURL
    self.copyToClipboard = copyToClipboard
  }
}

extension AppClient: DependencyKey {
  public static let liveValue = AppClient(
    selectPackURL: {
      let panel = NSOpenPanel()
      panel.title = "Import Pack"
      panel.canChooseDirectories = true
      panel.canChooseFiles = true
      panel.allowsMultipleSelection = false
      panel.allowedContentTypes = [.json]
      panel.prompt = "Import"
      return panel.runModal() == .OK ? panel.url : nil
    },
    confirmRemovePack: {
      let alert = NSAlert()
      alert.messageText = "Remove Pack?"
      alert.informativeText =
        "This will delete the pack folder from disk. This action cannot be undone."
      alert.addButton(withTitle: "Remove")
      alert.addButton(withTitle: "Cancel")
      alert.alertStyle = .warning
      return alert.runModal() == .alertFirstButtonReturn
    },
    presentError: { title, message in
      let alert = NSAlert()
      alert.messageText = title
      alert.informativeText = message
      alert.addButton(withTitle: "OK")
      alert.alertStyle = .warning
      alert.runModal()
    },
    openURL: { url in
      NSWorkspace.shared.open(url)
    },
    copyToClipboard: { text in
      let pb = NSPasteboard.general
      pb.clearContents()
      pb.setString(text, forType: .string)
    }
  )

  public static var testValue: AppClient { liveValue }
  public static var previewValue: AppClient { liveValue }
}

extension DependencyValues {
  public var appClient: AppClient {
    get { self[AppClient.self] }
    set { self[AppClient.self] = newValue }
  }
}
