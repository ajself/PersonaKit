import SwiftUI

/// App command menu definitions for PersonaKit.
struct PersonaKitCommands: Commands {
  let model: AppModel
  @Binding var showPersonaSwitcher: Bool
  @Binding var showInspector: Bool

  /// Defines the PersonaKit command menu and keyboard shortcuts.
  var body: some Commands {
    CommandMenu("PersonaKit") {
      Button {
        showPersonaSwitcher = true
      } label: {
        Label("Switch Persona…", systemImage: "arrow.left.arrow.right")
      }
      .keyboardShortcut("k", modifiers: [.command])

      Button {
        model.sidebar.requestSearchFocus()
      } label: {
        Label("Focus Sidebar Search", systemImage: "magnifyingglass")
      }
      .keyboardShortcut("f", modifiers: [.command])

      Button {
        model.requestComposerFocus(sectionKey: "context")
      } label: {
        Label("Focus Context Field", systemImage: "text.cursor")
      }
      .keyboardShortcut("l", modifiers: [.command])

      Button {
        model.reloadAll()
      } label: {
        Label("Reload Packs", systemImage: "arrow.clockwise")
      }
      .keyboardShortcut("r", modifiers: [.command])

      Button {
        model.copyPromptToClipboard()
      } label: {
        Label("Copy Prompt", systemImage: "doc.on.doc")
      }
      .keyboardShortcut("c", modifiers: [.command, .shift])

      Divider()

      Button {
        showInspector.toggle()
      } label: {
        Label("Toggle Inspector", systemImage: "sidebar.right")
      }
      .keyboardShortcut("i", modifiers: [.command, .option])
    }
  }
}
