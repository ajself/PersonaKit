import PersonaKitCore
import SwiftUI

struct PersonaSwitcherView: View {
  @Environment(AppStore.self)
  private var store
  @Binding var isPresented: Bool
  @State private var query: String = ""
  @State private var selection: String?
  @FocusState private var searchFocused: Bool

  private var filtered: [ResolvedPersona] {
    let all = store.state.personaIndex.values.sorted {
      PersonaMetadata.personaSortKey($0.persona) < PersonaMetadata.personaSortKey($1.persona)
    }
    let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return all }
    let needle = trimmed.lowercased()
    return all.filter { rp in
      let persona = rp.persona
      if persona.name.lowercased().contains(needle) { return true }
      if persona.id.lowercased().contains(needle) { return true }
      if let tags = persona.tags?.joined(separator: " ").lowercased(), tags.contains(needle) {
        return true
      }
      if let about = persona.about?.lowercased(), about.contains(needle) { return true }
      return false
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Switch Persona").font(.headline)

      TextField("Search personas", text: $query)
        .textFieldStyle(.roundedBorder)
        .focused($searchFocused)
        .onSubmit { commitSelection() }
        .onChange(of: query) { _, _ in syncSelection() }
        .help("Search by name, id, tags, or description.")

      List(selection: $selection) {
        ForEach(filtered, id: \.persona.id) { rp in
          PersonaSwitchRow(persona: rp.persona)
            .tag(rp.persona.id)
            .onTapGesture {
              selectPersona(id: rp.persona.id)
            }
        }
      }
      .frame(minHeight: 260)

      Button {
        commitSelection()
      } label: {
        Label("Select", systemImage: "checkmark")
      }
      .keyboardShortcut(.defaultAction)
      .frame(width: 0, height: 0)
      .opacity(0)
    }
    .padding()
    .frame(width: 420, height: 360)
    .onAppear {
      searchFocused = true
      selection = store.state.selectedPersonaID
      syncSelection()
    }
    .onChange(of: store.state.personaIndex) { _, _ in
      syncSelection()
    }
    .onMoveCommand { direction in
      moveSelection(direction)
    }
    .onExitCommand {
      isPresented = false
    }
  }

  private func syncSelection() {
    let available = filtered
    guard !available.isEmpty else {
      selection = nil
      return
    }
    if let selection, available.contains(where: { $0.persona.id == selection }) {
      return
    }
    selection = available.first?.persona.id
  }

  private func moveSelection(_ direction: MoveCommandDirection) {
    let available = filtered
    guard !available.isEmpty else { return }
    let currentIndex = available.firstIndex { $0.persona.id == selection } ?? 0
    let nextIndex: Int
    switch direction {
    case .down:
      nextIndex = min(currentIndex + 1, available.count - 1)
    case .up:
      nextIndex = max(currentIndex - 1, 0)
    default:
      return
    }
    selection = available[nextIndex].persona.id
  }

  private func commitSelection() {
    guard let selection else { return }
    selectPersona(id: selection)
  }

  private func selectPersona(id: String) {
    store.send(.setSelectedPersonaID(id))
    isPresented = false
  }
}

private struct PersonaSwitchRow: View {
  let persona: Persona

  private var tagsSummary: String? {
    let tags = persona.sortedTags
    guard !tags.isEmpty else { return nil }
    return tags.joined(separator: ", ")
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(persona.name).font(.headline)
      Text(persona.id).font(.caption).foregroundStyle(.secondary)
      if let tagsSummary {
        Text("Tags: \(tagsSummary)")
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
      if let about = persona.about, !about.isEmpty {
        Text(about)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(2)
      }
    }
    .padding(.vertical, 4)
  }
}
