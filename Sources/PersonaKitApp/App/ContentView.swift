import SwiftUI

/// The root split-view shell for the PersonaKit app window.
struct ContentView: View {
  @Environment(AppModel.self)
  private var model
  @Binding var showPersonaSwitcher: Bool
  @Binding var showInspector: Bool
  @State private var selectedPanel: PreviewPanel = .prompt

  /// Builds the sidebar/detail layout and wires up global overlays.
  var body: some View {
    NavigationSplitView {
      SidebarView(
        personaIndex: model.personaIndex,
        personaSourcesByID: model.personaSourcesByID,
        diagnostics: model.diagnostics,
        selectedPersonaID: model.bindingForSelectedPersonaID()
      )
      .environment(model.sidebar)
    } detail: {
      PreviewView(selectedPanel: $selectedPanel)
        .environment(model.preview)
    }
    .task {
      model.reloadAll()
    }
    .onChange(of: model.composer.focusRequest) { _, request in
      guard request != nil else { return }
      showInspector = true
    }
    .sheet(isPresented: $showPersonaSwitcher) {
      PersonaSwitcherView(isPresented: $showPersonaSwitcher)
        .environment(model)
    }
    .inspector(isPresented: $showInspector) {
      InspectorView()
        .environment(model)
        .environment(model.composer)
    }
    .toolbar {
      ToolbarItemGroup(placement: .automatic) {
        Button {
          model.reloadAll()
        } label: {
          Label("Reload", systemImage: "arrow.clockwise")
        }
        .help("Reload persona packs.")
        Button {
          model.importPack()
        } label: {
          Label("Import Pack", systemImage: "tray.and.arrow.down")
        }
        .help("Import a persona pack into PersonaKit storage.")
        Button {
          model.copyPromptToClipboard()
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
      searchText: model.sidebar.searchText,
      isFocused: model.sidebar.isSearchFocused
    ) {
    case .clearAndFocus:
      model.sidebar.setSearchText("")
      model.sidebar.requestSearchFocus()
    case .blur:
      model.sidebar.requestSearchBlur()
    case .noOp:
      break
    }
  }
}
