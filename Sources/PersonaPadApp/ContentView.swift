import SwiftUI

struct ContentView: View {
  @Environment(AppStore.self)
  private var store
  @Binding var showPersonaSwitcher: Bool
  @Binding var showInspector: Bool
  @State private var selectedPanel: PreviewPanel = .prompt

  var body: some View {
    NavigationSplitView {
      SidebarView()
    } detail: {
      PreviewView(selectedPanel: $selectedPanel)
    }
    .task {
      store.send(.task)
    }
    .onChange(of: store.state.composerFocusRequest) { _, request in
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
        .help("Import a persona pack into PersonaPad storage.")
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

  private func handleEscape() {
    if showPersonaSwitcher {
      showPersonaSwitcher = false
      return
    }
    switch SidebarSearchEscapePolicy.action(
      searchText: store.state.searchText,
      isFocused: store.state.isSidebarSearchFocused
    ) {
    case .clearAndFocus:
      store.send(.setSearchText(""))
      store.send(.requestSidebarSearchFocus)
    case .blur:
      store.send(.requestSidebarSearchBlur)
    case .noOp:
      break
    }
  }
}
