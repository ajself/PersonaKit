import SwiftUI
import PersonaPadCore

struct PersonaSwitcherView: View {
  @EnvironmentObject private var store: AppStore
  @Binding var isPresented: Bool
  @State private var query: String = ""

  private var filtered: [ResolvedPersona] {
    let all = store.personaIndex.values.sorted {
      $0.persona.name.localizedCaseInsensitiveCompare($1.persona.name) == .orderedAscending
    }
    let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return all }
    let needle = trimmed.lowercased()
    return all.filter { rp in
      let persona = rp.persona
      if persona.name.lowercased().contains(needle) { return true }
      if persona.id.lowercased().contains(needle) { return true }
      if let tags = persona.tags?.joined(separator: " ").lowercased(), tags.contains(needle) { return true }
      return false
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Switch Persona").font(.headline)

      TextField("Search personas", text: $query)
        .textFieldStyle(.roundedBorder)

      List(filtered, id: \.persona.id) { rp in
        Button {
          store.selectedPersonaID = rp.persona.id
          isPresented = false
        } label: {
          VStack(alignment: .leading, spacing: 2) {
            Text(rp.persona.name)
            Text(rp.persona.id).font(.caption).foregroundStyle(.secondary)
          }
        }
        .buttonStyle(.plain)
      }
      .frame(minHeight: 260)
    }
    .padding()
    .frame(width: 420, height: 360)
  }
}
