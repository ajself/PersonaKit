import SwiftUI

/// SwiftUI bindings that forward updates back into ``AppStore`` actions.
extension AppStore {
  /// Binds the sidebar search text to ``Action.setSearchText``.
  func bindingForSearchText() -> Binding<String> {
    Binding(
      get: { self.state.searchText },
      set: { self.send(.setSearchText($0)) }
    )
  }

  /// Binds the currently selected persona identifier.
  func bindingForSelectedPersonaID() -> Binding<String?> {
    Binding(
      get: { self.state.selectedPersonaID },
      set: { self.send(.setSelectedPersonaID($0)) }
    )
  }

  /// Binds a composer input field by key.
  func bindingForComposerValue(key: String) -> Binding<String> {
    Binding(
      get: { self.state.composerValues[key] ?? "" },
      set: { self.send(.setComposerValue(key: key, value: $0)) }
    )
  }

  /// Binds the JSON preview editor to ``Action.setJSONPreview``.
  func bindingForJSONPreview() -> Binding<String> {
    Binding(
      get: { self.state.jsonPreview },
      set: { self.send(.setJSONPreview($0)) }
    )
  }
}
