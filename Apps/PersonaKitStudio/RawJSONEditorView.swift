import SwiftUI

/// Modal raw JSON editor with validate and save actions.
struct RawJSONEditorView: View {
  let title: String
  let entityDisplayName: String
  let onCancel: () -> Void
  let onValidate: @Sendable (String) async -> String?
  let onSave: @Sendable (String) async -> String?

  @State private var rawJSON: String
  @State private var isValidating = false
  @State private var isSaving = false
  @State private var message: String?
  @State private var isErrorMessage = false

  init(
    title: String,
    entityDisplayName: String,
    initialRawJSON: String,
    onCancel: @escaping () -> Void,
    onValidate: @escaping @Sendable (String) async -> String?,
    onSave: @escaping @Sendable (String) async -> String?
  ) {
    self.title = title
    self.entityDisplayName = entityDisplayName
    self.onCancel = onCancel
    self.onValidate = onValidate
    self.onSave = onSave

    _rawJSON = State(initialValue: initialRawJSON)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(title)
        .font(.title3)
        .fontWeight(.semibold)

      Text("\(entityDisplayName) JSON")
        .font(.subheadline)
        .foregroundStyle(.secondary)

      TextEditor(text: $rawJSON)
        .font(.body.monospaced())
        .padding(8)
        .frame(minHeight: 420)
        .background(
          RoundedRectangle(cornerRadius: 8)
            .fill(.quaternary.opacity(0.2))
        )

      if let message {
        Text(message)
          .font(.footnote)
          .foregroundStyle(isErrorMessage ? .red : .secondary)
      }

      HStack {
        Spacer()

        Button("Cancel") {
          onCancel()
        }
        .disabled(isSaving || isValidating)

        Button(isValidating ? "Validating…" : "Validate") {
          validate()
        }
        .disabled(isSaving || isValidating)

        Button(isSaving ? "Saving…" : "Save") {
          save()
        }
        .disabled(isSaving || isValidating)
      }
    }
    .padding()
    .frame(minWidth: 720, minHeight: 600)
    .interactiveDismissDisabled(isSaving || isValidating)
  }

  private func validate() {
    isValidating = true
    message = nil

    Task {
      let validationError = await onValidate(rawJSON)

      await MainActor.run {
        isValidating = false

        if let validationError {
          message = validationError
          isErrorMessage = true
        } else {
          message = "JSON is valid."
          isErrorMessage = false
        }
      }
    }
  }

  private func save() {
    isSaving = true
    message = nil

    Task {
      let saveError = await onSave(rawJSON)

      await MainActor.run {
        isSaving = false

        if let saveError {
          message = saveError
          isErrorMessage = true
        } else {
          onCancel()
        }
      }
    }
  }
}
