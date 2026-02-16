import ContextCore
import StudioFoundation
import SwiftUI

/// Modal editor with minimal form fields and full-fidelity raw JSON editing.
struct RawJSONEditorView: View {
  private enum EditorMode: String, CaseIterable, Identifiable {
    case form = "Form"
    case rawJSON = "Raw JSON"

    var id: EditorMode {
      self
    }
  }

  let title: String
  let entityType: WorkspaceLibraryEntityType
  let onCancel: () -> Void
  let onRevealInFinder: (() -> Void)?
  let onValidate: @Sendable (String) async -> String?
  let onSave: @Sendable (String) async -> String?

  private let formAdapter: WorkspaceLibraryEntityFormAdapter
  private let formDescriptor: WorkspaceLibraryEntityFormDescriptor

  @State private var rawJSON: String
  @State private var editorMode: EditorMode
  @State private var formState: WorkspaceLibraryEntityFormState
  @State private var formSyncErrorMessage: String?
  @State private var isValidating = false
  @State private var isSaving = false
  @State private var message: String?
  @State private var isErrorMessage = false

  init(
    title: String,
    entityType: WorkspaceLibraryEntityType,
    initialRawJSON: String,
    onCancel: @escaping () -> Void,
    onRevealInFinder: (() -> Void)? = nil,
    onValidate: @escaping @Sendable (String) async -> String?,
    onSave: @escaping @Sendable (String) async -> String?
  ) {
    let formAdapter = WorkspaceLibraryEntityFormAdapter(entityType: entityType)

    self.title = title
    self.entityType = entityType
    self.onCancel = onCancel
    self.onRevealInFinder = onRevealInFinder
    self.onValidate = onValidate
    self.onSave = onSave
    self.formAdapter = formAdapter
    self.formDescriptor = formAdapter.descriptor

    _rawJSON = State(initialValue: initialRawJSON)

    do {
      let initialFormState = try formAdapter.parseFormState(from: initialRawJSON)

      _editorMode = State(initialValue: .form)
      _formState = State(initialValue: initialFormState)
      _formSyncErrorMessage = State(initialValue: nil)
    } catch {
      _editorMode = State(initialValue: .rawJSON)
      _formState = State(initialValue: .empty)
      _formSyncErrorMessage = State(initialValue: error.localizedDescription)
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(title)
        .font(.title3)
        .fontWeight(.semibold)

      Text("\(entityType.displayName) JSON")
        .font(.subheadline)
        .foregroundStyle(.secondary)

      Picker("Editor", selection: $editorMode) {
        ForEach(EditorMode.allCases) { mode in
          Text(mode.rawValue)
            .tag(mode)
        }
      }
      .pickerStyle(.segmented)

      if editorMode == .form {
        RawJSONEditorMinimalFormView(
          formDescriptor: formDescriptor,
          formSyncErrorMessage: formSyncErrorMessage,
          idBinding: idBinding,
          primaryTextBinding: primaryTextBinding,
          firstArrayLinesBinding: firstArrayLinesBinding,
          secondArrayLinesBinding: secondArrayLinesBinding
        )
      } else {
        rawJSONTextEditor
      }

      if let message {
        Text(message)
          .font(.footnote)
          .foregroundStyle(isErrorMessage ? .red : .secondary)
      }

      RawJSONEditorActionFooterView(
        canRevealInFinder: onRevealInFinder != nil,
        isSaving: isSaving,
        isValidating: isValidating,
        onRevealInFinder: {
          onRevealInFinder?()
        },
        onCancel: onCancel,
        onValidate: validate,
        onSave: save
      )
    }
    .padding()
    .frame(minWidth: 720, minHeight: 600)
    .interactiveDismissDisabled(isSaving || isValidating)
    .onChange(of: editorMode) { _, newValue in
      guard newValue == .form else {
        return
      }

      syncFormStateFromRawJSON()
    }
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

  private var rawJSONTextEditor: some View {
    TextEditor(text: $rawJSON)
      .font(.body.monospaced())
      .padding(8)
      .frame(minHeight: 420)
      .background(
        RoundedRectangle(cornerRadius: 8)
          .fill(.quaternary.opacity(0.2))
      )
  }

  private var idBinding: Binding<String> {
    Binding(
      get: { formState.id },
      set: { updatedID in
        formState.id = updatedID
        syncRawJSONFromFormState()
      }
    )
  }

  private var primaryTextBinding: Binding<String> {
    Binding(
      get: { formState.primaryText },
      set: { updatedText in
        formState.primaryText = updatedText
        syncRawJSONFromFormState()
      }
    )
  }

  private var firstArrayLinesBinding: Binding<String> {
    Binding(
      get: { formState.firstArrayLines },
      set: { updatedText in
        formState.firstArrayLines = updatedText
        syncRawJSONFromFormState()
      }
    )
  }

  private var secondArrayLinesBinding: Binding<String> {
    Binding(
      get: { formState.secondArrayLines },
      set: { updatedText in
        formState.secondArrayLines = updatedText
        syncRawJSONFromFormState()
      }
    )
  }

  private func syncFormStateFromRawJSON() {
    do {
      formState = try formAdapter.parseFormState(from: rawJSON)
      formSyncErrorMessage = nil
    } catch {
      formSyncErrorMessage = error.localizedDescription
    }
  }

  private func syncRawJSONFromFormState() {
    do {
      rawJSON = try formAdapter.applyFormState(
        formState,
        to: rawJSON
      )
      formSyncErrorMessage = nil
    } catch {
      formSyncErrorMessage = error.localizedDescription
    }
  }
}
