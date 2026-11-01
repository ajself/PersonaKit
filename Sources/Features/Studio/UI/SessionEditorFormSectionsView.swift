import SwiftUI

/// Session editor form sections for identity, references, and kit overrides.
struct SessionEditorFormSectionsView: View {
  @Binding var id: String
  @Binding var personaID: String
  @Binding var directiveID: String
  let personaOptions: SessionEditorReferenceOptions
  let directiveOptions: SessionEditorReferenceOptions
  let kitIDs: [String]
  let bindingForKitOverride: (String) -> Binding<Bool>

  var body: some View {
    Form {
      Section("Session") {
        TextField("Session id", text: $id)

        referencePicker("Persona", selection: $personaID, options: personaOptions)

        referencePicker("Directive", selection: $directiveID, options: directiveOptions)
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
  }

  private func referencePicker(
    _ title: String,
    selection: Binding<String>,
    options: SessionEditorReferenceOptions
  ) -> some View {
    Picker(title, selection: selection) {
      ForEach(options.loadedIDs, id: \.self) { item in
        Text(item)
          .tag(item)
      }

      if let unloadedID = options.unloadedID {
        Text(SessionEditorReferenceOptions.unloadedTitle(for: unloadedID))
          .tag(unloadedID)
      }
    }
  }
}
