import SwiftUI
import PersonaPadCore

struct SidebarView: View {
  @EnvironmentObject private var store: AppStore
  @FocusState private var searchFocused: Bool

  private var allPersonas: [ResolvedPersona] {
    store.personaIndex.values.sorted {
      PersonaMetadata.personaSortKey($0.persona) < PersonaMetadata.personaSortKey($1.persona)
    }
  }

  private var filtered: [ResolvedPersona] {
    allPersonas.filter { rp in
      let p = rp.persona
      let matchesSearch = store.searchText.isEmpty
        || p.name.localizedCaseInsensitiveContains(store.searchText)
        || (p.id.localizedCaseInsensitiveContains(store.searchText))
        || (p.about?.localizedCaseInsensitiveContains(store.searchText) ?? false)
        || p.sortedTags.contains(where: { $0.localizedCaseInsensitiveContains(store.searchText) })

      let matchesTag: Bool = {
        guard let tag = store.selectedTag, !tag.isEmpty else { return true }
        return p.tags?.contains(tag) ?? false
      }()

      return matchesSearch && matchesTag
    }
  }

  private var allTags: [String] {
    PersonaMetadata.sortedUniqueTags(from: store.personaIndex.values.map { $0.persona })
  }

  var body: some View {
    VStack(spacing: 8) {
      TextField("Search personas", text: $store.searchText)
        .textFieldStyle(.roundedBorder)
        .focused($searchFocused)
        .padding([.top, .horizontal])
        .onChange(of: store.sidebarSearchFocusRequest) { _, request in
          searchFocused = request.shouldFocus
        }
        .onChange(of: searchFocused) { _, newValue in
          store.isSidebarSearchFocused = newValue
        }
        .help("Search by name, id, description, or tag.")

      if !allTags.isEmpty {
        VStack(alignment: .leading, spacing: 6) {
          HStack {
            Menu {
              Button {
                store.selectedTag = nil
              } label: {
                tagMenuRow(title: "All", isSelected: store.selectedTag == nil)
              }
              Divider()
              ForEach(allTags, id: \.self) { tag in
                Button {
                  store.selectedTag = tag
                } label: {
                  tagMenuRow(title: tag, isSelected: store.selectedTag == tag)
                }
              }
            } label: {
              Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
            }
            .help("Filter personas by tag.")

            Spacer()
          }

          if let selectedTag = store.selectedTag, !selectedTag.isEmpty {
            HStack(spacing: 6) {
              Text("Filter: \(selectedTag)")
              Button {
                store.selectedTag = nil
              } label: {
                Label("Clear", systemImage: "xmark.circle.fill")
              }
              .buttonStyle(.plain)
              .help("Clear tag filter.")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
          }
        }
        .padding(.horizontal)
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

  private func tagMenuRow(title: String, isSelected: Bool) -> some View {
    HStack {
      Text(title)
      Spacer()
      if isSelected {
        Image(systemName: "checkmark")
      }
    }
  }
}

private struct PersonaRow: View {
  let persona: Persona

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(persona.name).font(.headline)
      Text(persona.id).font(.caption).foregroundStyle(.secondary)
      if let about = persona.about, !about.isEmpty {
        Text(about).font(.caption).foregroundStyle(.secondary).lineLimit(2)
      }
    }
    .padding(.vertical, 4)
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
