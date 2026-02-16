import SwiftUI

/// Footer status and action row for session editing.
struct SessionEditorFooterView: View {
  let saveErrorMessage: String?
  let validationMessage: String
  let isSaving: Bool
  let canSave: Bool
  let onCancel: () -> Void
  let onSave: () -> Void

  var body: some View {
    if let saveErrorMessage {
      Text(saveErrorMessage)
        .font(.footnote)
        .foregroundStyle(.red)
    }

    if !validationMessage.isEmpty {
      Text(validationMessage)
        .font(.footnote)
        .foregroundStyle(.secondary)
    }

    HStack {
      Spacer()

      Button("Cancel", role: .cancel) {
        onCancel()
      }
      .disabled(isSaving)

      Button(isSaving ? "Saving…" : "Save") {
        onSave()
      }
      .disabled(isSaving || !canSave)
    }
  }
}
