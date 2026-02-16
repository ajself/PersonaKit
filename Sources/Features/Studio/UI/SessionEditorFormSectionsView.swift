import SwiftUI

/// Session editor form sections for identity, references, and kit overrides.
struct SessionEditorFormSectionsView: View {
  @Binding var id: String
  @Binding var personaID: String
  @Binding var directiveID: String
  let personaIDs: [String]
  let directiveIDs: [String]
  let kitIDs: [String]
  let bindingForKitOverride: (String) -> Binding<Bool>

  var body: some View {
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
  }
}
