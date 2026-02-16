import SwiftUI

/// Footer actions for raw JSON editor validation, save, and navigation.
struct RawJSONEditorActionFooterView: View {
  let canRevealInFinder: Bool
  let isSaving: Bool
  let isValidating: Bool
  let onRevealInFinder: () -> Void
  let onCancel: () -> Void
  let onValidate: () -> Void
  let onSave: () -> Void

  var body: some View {
    HStack {
      Button("Reveal in Finder") {
        onRevealInFinder()
      }
      .disabled(isSaving || isValidating || !canRevealInFinder)

      Spacer()

      Button("Cancel", role: .cancel) {
        onCancel()
      }
      .disabled(isSaving || isValidating)

      Button(isValidating ? "Validating…" : "Validate") {
        onValidate()
      }
      .disabled(isSaving || isValidating)

      Button(isSaving ? "Saving…" : "Save") {
        onSave()
      }
      .disabled(isSaving || isValidating)
    }
  }
}
