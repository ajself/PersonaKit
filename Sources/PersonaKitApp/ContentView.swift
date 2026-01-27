import SwiftUI

/// The root split-view shell for the PersonaKit app window.
struct ContentView: View {
  @Environment(AppStore.self)
  private var store
  @Binding var showPersonaSwitcher: Bool
  @Binding var showInspector: Bool
  @State private var selectedPanel: PreviewPanel = .prompt

  /// Builds the sidebar/detail layout and wires up global overlays.
  var body: some View {
    NavigationSplitView {
      SidebarView()
    } detail: {
      PreviewView(selectedPanel: $selectedPanel)
    }
    .task {
      store.send(.task)
    }
    .onChange(of: store.state.composer.focusRequest) { _, request in
      guard request != nil else { return }
      showInspector = true
    }
    .sheet(isPresented: $showPersonaSwitcher) {
      PersonaSwitcherView(isPresented: $showPersonaSwitcher)
        .environment(store)
    }
    .inspector(isPresented: $showInspector) {
      InspectorView()
        .environment(store)
    }
    .toolbar {
      ToolbarItemGroup(placement: .automatic) {
        Button {
          store.send(.reloadAll)
        } label: {
          Label("Reload", systemImage: "arrow.clockwise")
        }
        .help("Reload persona packs.")
        Button {
          store.send(.importPack)
        } label: {
          Label("Import Pack", systemImage: "tray.and.arrow.down")
        }
        .help("Import a persona pack into PersonaKit storage.")
        Button {
          store.send(.copyPromptToClipboard)
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

  /// Handles the escape key to dismiss sheets or clear search focus.
  private func handleEscape() {
    if showPersonaSwitcher {
      showPersonaSwitcher = false
      return
    }
    switch SidebarSearchEscapePolicy.action(
      searchText: store.sidebar.searchText,
      isFocused: store.sidebar.isSearchFocused
    ) {
    case .clearAndFocus:
      store.sidebar.setSearchText("")
      store.sidebar.requestSearchFocus()
    case .blur:
      store.sidebar.requestSearchBlur()
    case .noOp:
      break
    }
  }
}
