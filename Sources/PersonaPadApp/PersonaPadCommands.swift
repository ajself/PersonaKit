import SwiftUI

struct PersonaPadCommands: Commands {
  @ObservedObject var store: AppStore
  @Binding var showPersonaSwitcher: Bool

  var body: some Commands {
    CommandMenu("PersonaPad") {
      Button("Switch Persona…") { showPersonaSwitcher = true }
        .keyboardShortcut("k", modifiers: [.command])

      Button("Focus Sidebar Search") { store.requestSidebarSearchFocus() }
        .keyboardShortcut("f", modifiers: [.command])

      Button("Focus Context Field") { store.requestComposerFocus(sectionKey: "context") }
        .keyboardShortcut("l", modifiers: [.command])

      Button("Reload Packs") { store.reloadAll() }
        .keyboardShortcut("r", modifiers: [.command])

      Button("Copy Prompt") { store.copyPromptToClipboard() }
        .keyboardShortcut("c", modifiers: [.command, .shift])
    }
  }
}
