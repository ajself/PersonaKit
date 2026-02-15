import StudioFoundation
import SwiftUI

/// Modal editor for creating and updating session files.
struct SessionEditorView: View {
  let title: String
  let personaIDs: [String]
  let directiveIDs: [String]
  let kitIDs: [String]
  let onCancel: () -> Void
  let onSave: @Sendable (WorkspaceSessionDraft) async -> String?

  @State private var id: String
  @State private var personaID: String
  @State private var directiveID: String
  @State private var selectedKitIDs: Set<String>
  @State private var isSaving = false
  @State private var saveErrorMessage: String?

  init(
    title: String,
    initialDraft: WorkspaceSessionDraft,
    personaIDs: [String],
    directiveIDs: [String],
    kitIDs: [String],
    onCancel: @escaping () -> Void,
    onSave: @escaping @Sendable (WorkspaceSessionDraft) async -> String?
  ) {
    self.title = title
    self.personaIDs = personaIDs
    self.directiveIDs = directiveIDs
    self.kitIDs = kitIDs
    self.onCancel = onCancel
    self.onSave = onSave

    let resolvedPersonaID = Self.resolvedSelection(
      requestedID: initialDraft.personaId,
      candidates: personaIDs
    )
    let resolvedDirectiveID = Self.resolvedSelection(
      requestedID: initialDraft.directiveId,
      candidates: directiveIDs
    )

    _id = State(initialValue: initialDraft.id)
    _personaID = State(initialValue: resolvedPersonaID)
    _directiveID = State(initialValue: resolvedDirectiveID)
    _selectedKitIDs = State(initialValue: Set(initialDraft.kitOverrides))
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(title)
        .font(.title3)
        .fontWeight(.semibold)

      Form {
        Section("Session") {
          TextField("Session id", text: $id)

          Picker("Persona", selection: $personaID) {
            ForEach(personaIDs, id: \.self) { item in
              Text(item)
                .tag(item)
            }
          }

          Picker("Directive", selection: $directiveID) {
            ForEach(directiveIDs, id: \.self) { item in
              Text(item)
                .tag(item)
            }
          }
        }

        Section("Kit Overrides") {
          if kitIDs.isEmpty {
            Text("No kits available.")
              .foregroundStyle(.secondary)
          } else {
            ForEach(kitIDs, id: \.self) { kitID in
              Toggle(isOn: bindingForKitOverride(kitID)) {
                Text(kitID)
              }
            }
          }
        }
      }
      .formStyle(.grouped)

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

        Button("Cancel") {
          onCancel()
        }
        .disabled(isSaving)

        Button(isSaving ? "Saving…" : "Save") {
          save()
        }
        .disabled(!canSave)
      }
    }
    .padding()
    .frame(minWidth: 520, minHeight: 520)
    .interactiveDismissDisabled(isSaving)
  }

  private var normalizedID: String {
    id.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private var isPersonaValid: Bool {
    personaIDs.contains(personaID)
  }

  private var isDirectiveValid: Bool {
    directiveIDs.contains(directiveID)
  }

  private var validationMessage: String {
    if normalizedID.isEmpty {
      return "Session id is required."
    }

    if !isValidSessionID(normalizedID) {
      return "Use letters, numbers, hyphen, underscore, or period for session id."
    }

    if !isPersonaValid {
      return "Choose a valid persona."
    }

    if !isDirectiveValid {
      return "Choose a valid directive."
    }

    return ""
  }

  private var canSave: Bool {
    !isSaving && validationMessage.isEmpty
  }

  private func bindingForKitOverride(_ kitID: String) -> Binding<Bool> {
    Binding(
      get: {
        selectedKitIDs.contains(kitID)
      },
      set: { isSelected in
        if isSelected {
          selectedKitIDs.insert(kitID)
        } else {
          selectedKitIDs.remove(kitID)
        }
      }
    )
  }

  private func save() {
    isSaving = true
    saveErrorMessage = nil

    Task {
      let draft = WorkspaceSessionDraft(
        id: normalizedID,
        personaId: personaID,
        directiveId: directiveID,
        kitOverrides: selectedKitIDs.sorted()
      )
      let saveErrorMessage = await onSave(draft)

      await MainActor.run {
        isSaving = false

        if let saveErrorMessage {
          self.saveErrorMessage = saveErrorMessage
        } else {
          onCancel()
        }
      }
    }
  }

  private static func resolvedSelection(
    requestedID: String,
    candidates: [String]
  ) -> String {
    if candidates.contains(requestedID) {
      return requestedID
    }

    return candidates.first ?? ""
  }

  private func isValidSessionID(_ value: String) -> Bool {
    let allowedCharacters = CharacterSet(
      charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_."
    )

    if value.rangeOfCharacter(from: allowedCharacters.inverted) != nil {
      return false
    }

    if value.hasPrefix(".") {
      return false
    }

    return value != "." && value != ".."
  }
}
