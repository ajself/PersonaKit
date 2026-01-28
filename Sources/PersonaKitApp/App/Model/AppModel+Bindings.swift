import SwiftUI

/// SwiftUI bindings that forward updates back into ``AppModel`` methods.
extension AppModel {
  /// Binds the currently selected persona identifier.
  func bindingForComposerValue(key: String) -> Binding<String> {
    composer.bindingForComposerValue(key: key)
  }
}
