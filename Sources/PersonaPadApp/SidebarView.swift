import SwiftUI
import PersonaPadCore

struct SidebarView: View {
  @EnvironmentObject private var store: AppStore

  private var allPersonas: [ResolvedPersona] {
    store.personaIndex.values.sorted { $0.persona.name.localizedCaseInsensitiveCompare($1.persona.name) == .orderedAscending }
  }

  private var filtered: [ResolvedPersona] {
    allPersonas.filter { rp in
      let p = rp.persona
      let matchesSearch = store.searchText.isEmpty
        || p.name.localizedCaseInsensitiveContains(store.searchText)
        || (p.id.localizedCaseInsensitiveContains(store.searchText))
        || (p.tags?.contains(where: { $0.localizedCaseInsensitiveContains(store.searchText) }) ?? false)

      let matchesTag: Bool = {
        guard let tag = store.selectedTag, !tag.isEmpty else { return true }
        return p.tags?.contains(tag) ?? false
      }()

      return matchesSearch && matchesTag
    }
  }

  private var allTags: [String] {
    Array(Set(store.personaIndex.values.flatMap { $0.persona.tags ?? [] })).sorted()
  }

  var body: some View {
    VStack(spacing: 8) {
      TextField("Search personas", text: $store.searchText)
        .textFieldStyle(.roundedBorder)
        .padding([.top, .horizontal])

      if !allTags.isEmpty {
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 6) {
            TagChip(title: "All", isSelected: store.selectedTag == nil) {
              store.selectedTag = nil
            }
            ForEach(allTags, id: \.self) { tag in
              TagChip(title: tag, isSelected: store.selectedTag == tag) {
                store.selectedTag = tag
              }
            }
          }
          .padding(.horizontal)
        }
      }

      List(selection: $store.selectedPersonaID) {
        ForEach(filtered, id: \.persona.id) { rp in
          PersonaRow(persona: rp.persona)
            .tag(rp.persona.id)
        }
      }

      DiagnosticsFooter(diagnostics: store.diagnostics)
    }
  }
}

private struct PersonaRow: View {
  let persona: Persona

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(persona.name).font(.headline)
      Text(persona.id).font(.caption).foregroundStyle(.secondary)
      if let desc = persona.description, !desc.isEmpty {
        Text(desc).font(.caption).foregroundStyle(.secondary).lineLimit(2)
      }
    }
    .padding(.vertical, 4)
  }
}

private struct TagChip: View {
  let title: String
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Text(title)
        .font(.caption)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(isSelected ? Color.accentColor.opacity(0.25) : Color.secondary.opacity(0.12))
        .clipShape(Capsule())
    }
    .buttonStyle(.plain)
  }
}

private struct DiagnosticsFooter: View {
  let diagnostics: [Diagnostic]

  var body: some View {
    if diagnostics.isEmpty {
      EmptyView()
    } else {
      VStack(alignment: .leading, spacing: 4) {
        Divider()
        Text("Diagnostics").font(.caption).foregroundStyle(.secondary)
        ScrollView {
          VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(diagnostics.enumerated()), id: \.offset) { _, d in
              Text("• [\(d.severity.rawValue.uppercased())] \(d.userFacingMessage)")
                .font(.caption2)
                .foregroundStyle(d.severity == .error ? .red : .orange)
                .textSelection(.enabled)
            }
          }
          .padding(.bottom, 8)
        }
        .frame(maxHeight: 120)
      }
      .padding(.horizontal)
      .padding(.bottom, 8)
    }
  }
}
