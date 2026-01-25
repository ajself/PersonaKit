import SwiftUI

extension AppStore {
  func bindingForSearchText() -> Binding<String> {
    Binding(
      get: { self.state.searchText },
      set: { self.send(.setSearchText($0)) }
    )
  }

  func bindingForSelectedPersonaID() -> Binding<String?> {
    Binding(
      get: { self.state.selectedPersonaID },
      set: { self.send(.setSelectedPersonaID($0)) }
    )
  }

  func bindingForComposerValue(key: String) -> Binding<String> {
    Binding(
      get: { self.state.composerValues[key] ?? "" },
      set: { self.send(.setComposerValue(key: key, value: $0)) }
    )
  }

  func bindingForJSONPreview() -> Binding<String> {
    Binding(
      get: { self.state.jsonPreview },
      set: { self.send(.setJSONPreview($0)) }
    )
  }
}
