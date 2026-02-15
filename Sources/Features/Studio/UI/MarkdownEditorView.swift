import SwiftUI

/// Modal markdown editor with save action.
struct MarkdownEditorView: View {
  let title: String
  let onCancel: () -> Void
  let onRevealInFinder: (() -> Void)?
  let onSave: @Sendable (String) async -> String?

  @State private var markdown: String
  @State private var isSaving = false
  @State private var message: String?

  init(
    title: String,
    initialMarkdown: String,
    onCancel: @escaping () -> Void,
    onRevealInFinder: (() -> Void)? = nil,
    onSave: @escaping @Sendable (String) async -> String?
  ) {
    self.title = title
    self.onCancel = onCancel
    self.onRevealInFinder = onRevealInFinder
    self.onSave = onSave

    _markdown = State(initialValue: initialMarkdown)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(title)
        .font(.title3)
        .fontWeight(.semibold)

      TextEditor(text: $markdown)
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
          .foregroundStyle(.red)
      }

      HStack {
        Button("Reveal in Finder") {
          onRevealInFinder?()
        }
        .disabled(isSaving || onRevealInFinder == nil)

        Spacer()

        Button("Cancel") {
          onCancel()
        }
        .disabled(isSaving)

        Button(isSaving ? "Saving…" : "Save") {
          save()
        }
        .disabled(isSaving)
      }
    }
    .padding()
    .frame(minWidth: 720, minHeight: 600)
    .interactiveDismissDisabled(isSaving)
  }

  private func save() {
    isSaving = true
    message = nil

    Task {
      let saveError = await onSave(markdown)

      await MainActor.run {
        isSaving = false

        if let saveError {
          message = saveError
        } else {
          onCancel()
        }
      }
    }
  }
}
