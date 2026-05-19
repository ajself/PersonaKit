import StudioFoundation
import SwiftUI

/// Minimal form fields for common library entity JSON edits.
struct RawJSONEditorMinimalFormView: View {
  let formDescriptor: WorkspaceLibraryEntityFormDescriptor
  let formSyncErrorMessage: String?
  let idBinding: Binding<String>
  let primaryTextBinding: Binding<String>
  let firstArrayLinesBinding: Binding<String>
  let secondArrayLinesBinding: Binding<String>

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("Edit a minimal subset of fields. Raw JSON remains the full editor.")
        .font(.footnote)
        .foregroundStyle(.secondary)

      if let formSyncErrorMessage {
        Text(formSyncErrorMessage)
          .font(.footnote)
          .foregroundStyle(.red)
      }

      Group {
        TextField("ID", text: idBinding)
          .textFieldStyle(.roundedBorder)

        TextField(formDescriptor.primaryFieldLabel, text: primaryTextBinding)
          .textFieldStyle(.roundedBorder)

        multiLineListField(
          title: formDescriptor.firstArrayLabel,
          text: firstArrayLinesBinding
        )

        multiLineListField(
          title: formDescriptor.secondArrayLabel,
          text: secondArrayLinesBinding
        )
      }
      .disabled(formSyncErrorMessage != nil)
    }
    .frame(minHeight: 320, alignment: .top)
    .padding(12)
    .background(
      RoundedRectangle(cornerRadius: 8)
        .fill(.quaternary.opacity(0.2))
    )
  }

  private func multiLineListField(
    title: String,
    text: Binding<String>
  ) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(title)
        .font(.caption)
        .foregroundStyle(.secondary)

      TextEditor(text: text)
        .font(.body.monospaced())
        .frame(minHeight: 84)
        .padding(6)
        .background(
          RoundedRectangle(cornerRadius: 6)
            .fill(.background)
        )
    }
  }
}
