import SwiftUI

extension ComposerModel {
  /// Binds a composer input field by key.
  func bindingForComposerValue(key: String) -> Binding<String> {
    Binding(
      get: { self.composerValues[key] ?? "" },
      set: { [weak self] newValue in
        guard let self else { return }
        self.composerValues[key] = newValue
        self.onValuesChange?()
      }
    )
  }
}
