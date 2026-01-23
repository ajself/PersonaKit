import SwiftUI
import AppKit

struct PersonaPadCommands: Commands {
  @ObservedObject var store: AppStore
  @Binding var showPersonaSwitcher: Bool

  var body: some Commands {
    CommandMenu("PersonaPad") {
      Button("Switch Persona…") { showPersonaSwitcher = true }
        .keyboardShortcut("k", modifiers: [.command])

      Button("Reload Packs") { store.reloadAll() }
        .keyboardShortcut("r", modifiers: [.command])

      Button("Copy Prompt") { store.copyPromptToClipboard() }
        .keyboardShortcut("c", modifiers: [.command, .shift])
    }
  }
}
