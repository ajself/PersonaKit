import SwiftUI

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
    .onExitCommand {
      handleEscape()
    }
  }

  private func handleEscape() {
    if showPersonaSwitcher {
      showPersonaSwitcher = false
      return
    }
    switch SidebarSearchEscapePolicy.action(
      searchText: store.searchText,
      isFocused: store.isSidebarSearchFocused
    ) {
    case .clearAndFocus:
      store.searchText = ""
      store.requestSidebarSearchFocus()
    case .blur:
      store.requestSidebarSearchBlur()
    case .noOp:
      break
    }
  }
}
