import SwiftUI

/// SwiftUI bindings that forward updates back into ``AppModel`` methods.
extension AppModel {
  /// Binds the currently selected persona identifier.
  func bindingForSelectedPersonaID() -> Binding<String?> {
    Binding(
      get: { self.composer.selectedPersonaID },
      set: { self.selectPersona(id: $0) }
    )
  }

  /// Binds a composer input field by key.
  func bindingForComposerValue(key: String) -> Binding<String> {
    composer.bindingForComposerValue(key: key)
  }

  /// Binds the JSON preview editor to ``AppModel`` JSON preview updates.
  func bindingForJSONPreview() -> Binding<String> {
    preview.bindingForJSONPreview()
  }
}
