import SwiftUI
import AppKit
import PersonaPadCore

struct ContentView: View {
  @EnvironmentObject private var store: AppStore
  @Binding var showPersonaSwitcher: Bool

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
}
