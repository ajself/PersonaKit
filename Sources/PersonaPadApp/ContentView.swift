import SwiftUI
import AppKit
import PersonaPadCore

struct ContentView: View {
  @EnvironmentObject private var store: AppStore
  @Binding var showPersonaSwitcher: Bool
  @State private var keyMonitor: Any?

  var body: some View {
    NavigationSplitView {
      SidebarView()
    } content: {
      ComposerView()
    } detail: {
      PreviewView()
    }
    .onAppear {
      store.reloadAll()
      installKeyMonitorIfNeeded()
    }
    .onDisappear {
      removeKeyMonitor()
    }
    .onChange(of: store.selectedPersonaID) { _ in
      store.recomputePreview()
    }
    .sheet(isPresented: $showPersonaSwitcher) {
      PersonaSwitcherView(isPresented: $showPersonaSwitcher)
        .environmentObject(store)
    }
    .toolbar {
      ToolbarItemGroup(placement: .automatic) {
        Button("Reload") { store.reloadAll() }
        Button("Copy Prompt") { store.copyPromptToClipboard() }
      }
    }
  }

  private func installKeyMonitorIfNeeded() {
    guard keyMonitor == nil else { return }
    keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
      let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
      guard modifiers == [.command],
            let characters = event.charactersIgnoringModifiers?.lowercased() else {
        return event
      }
      switch characters {
      case "k":
        showPersonaSwitcher = true
        return nil
      case "f":
        store.requestSidebarSearchFocus()
        return nil
      default:
        return event
      }
    }
  }

  private func removeKeyMonitor() {
    if let keyMonitor {
      NSEvent.removeMonitor(keyMonitor)
      self.keyMonitor = nil
    }
  }
}
