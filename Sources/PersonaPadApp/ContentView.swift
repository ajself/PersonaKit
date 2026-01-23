import SwiftUI

struct ContentView: View {
  @EnvironmentObject private var store: AppStore
  @Binding var showPersonaSwitcher: Bool
  @Binding var showInspector: Bool
  @State private var selectedPanel: PreviewPanel = .prompt

  var body: some View {
    NavigationSplitView {
      SidebarView()
    } detail: {
      PreviewView(selectedPanel: $selectedPanel)
    }
    .onAppear {
      store.reloadAll()
    }
    .onChange(of: store.selectedPersonaID) { _, _ in
      store.recomputePreview()
    }
    .onChange(of: store.composerFocusRequest) { _, request in
      guard request != nil else { return }
      showInspector = true
    }
    .sheet(isPresented: $showPersonaSwitcher) {
      PersonaSwitcherView(isPresented: $showPersonaSwitcher)
        .environmentObject(store)
    }
    .inspector(isPresented: $showInspector) {
      InspectorView()
        .environmentObject(store)
    }
    .toolbar {
      ToolbarItemGroup(placement: .automatic) {
        Button {
          store.reloadAll()
        } label: {
          Label("Reload", systemImage: "arrow.clockwise")
        }
        .help("Reload persona packs.")
        Button {
          store.copyPromptToClipboard()
        } label: {
          Label("Copy Prompt", systemImage: "doc.on.doc")
        }
        .help("Copy the composed prompt to the clipboard.")
        Button {
          showInspector.toggle()
        } label: {
          Label("Inspector", systemImage: "sidebar.right")
        }
        .labelStyle(.iconOnly)
        .help("Toggle the inspector.")
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
