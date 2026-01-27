import SwiftUI

/// SwiftUI bindings that forward updates back into ``AppStore`` actions.
extension AppStore {
  /// Binds the sidebar search text to ``SidebarFeature.Action.setSearchText``.
  func bindingForSearchText() -> Binding<String> {
    Binding(
      get: { self.state.sidebar.searchText },
      set: { self.send(.sidebar(.setSearchText($0))) }
    )
  }

  /// Binds the currently selected persona identifier.
  func bindingForSelectedPersonaID() -> Binding<String?> {
    Binding(
      get: { self.state.composer.selectedPersonaID },
      set: { self.send(.composer(.setSelectedPersonaID($0))) }
    )
  }

  /// Binds a composer input field by key.
  func bindingForComposerValue(key: String) -> Binding<String> {
    Binding(
      get: { self.state.composer.composerValues[key] ?? "" },
      set: { self.send(.composer(.setComposerValue(key: key, value: $0))) }
    )
  }

  /// Binds the JSON preview editor to ``PreviewFeature.Action.setJSONPreview``.
  func bindingForJSONPreview() -> Binding<String> {
    Binding(
      get: { self.state.preview.jsonPreview },
      set: { self.send(.preview(.setJSONPreview($0))) }
    )
  }
}
