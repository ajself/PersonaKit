import SwiftUI

extension PreviewModel {
  /// Binds the JSON preview editor to update through the model callback.
  func bindingForJSONPreview() -> Binding<String> {
    Binding(
      get: { self.jsonPreview },
      set: { [weak self] newValue in
        guard let self else { return }
        self.onJSONChange?(newValue)
      }
    )
  }
}
