import SwiftUI
import PersonaPadCore

struct SidebarView: View {
  @EnvironmentObject private var store: AppStore
  @FocusState private var searchFocused: Bool
  @State private var showSaveFilterSheet = false
  @State private var showRenameFilterSheet = false
  @State private var pendingFilterName = ""
  @State private var renameTarget: SavedFilter?
  @State private var deleteTarget: SavedFilter?

  private var searchBinding: Binding<String> {
    Binding(
      get: { store.searchText },
      set: { store.setSearchText($0) }
    )
  }

  private var allPersonas: [ResolvedPersona] {
    store.personaIndex.values.sorted {
      PersonaMetadata.personaSortKey($0.persona) < PersonaMetadata.personaSortKey($1.persona)
    }
  }

  private var filtered: [ResolvedPersona] {
    allPersonas.filter { rp in
      let p = rp.persona
      let matchesPinned: Bool = {
        guard store.isPinnedViewActive else { return true }
        return store.pinnedPersonaIDs.contains(p.id)
      }()
      let matchesSearch = store.searchText.isEmpty
        || p.name.localizedCaseInsensitiveContains(store.searchText)
        || (p.id.localizedCaseInsensitiveContains(store.searchText))
        || (p.about?.localizedCaseInsensitiveContains(store.searchText) ?? false)
        || p.sortedTags.contains(where: { $0.localizedCaseInsensitiveContains(store.searchText) })

      let matchesTag: Bool = {
        guard !store.activeFilterTags.isEmpty else { return true }
        let tags = p.tags ?? []
        return store.activeFilterTags.allSatisfy { tags.contains($0) }
      }()

      let matchesSource: Bool = {
        guard !store.activeSourceKinds.isEmpty else { return true }
        guard let kind = store.personaSourcesByID[p.id]?.kind else { return false }
        return store.activeSourceKinds.contains(kind)
      }()

      return matchesPinned && matchesSearch && matchesTag && matchesSource
    }
  }

  private var allTags: [String] {
    PersonaMetadata.sortedUniqueTags(from: store.personaIndex.values.map { $0.persona })
  }

  var body: some View {
    VStack(spacing: 8) {
      TextField("Search personas", text: searchBinding)
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

      pinnedSection
        .padding(.horizontal)

      savedFiltersSection
        .padding(.horizontal)

      if !allTags.isEmpty {
        VStack(alignment: .leading, spacing: 6) {
          HStack {
            Menu {
              Button {
                store.setSelectedTag(nil)
              } label: {
                tagMenuRow(title: "All", isSelected: store.activeFilterTags.isEmpty)
              }
              Divider()
              ForEach(allTags, id: \.self) { tag in
                Button {
                  store.setSelectedTag(tag)
                } label: {
                  tagMenuRow(title: tag, isSelected: store.activeFilterTags.contains(tag))
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
                store.setSelectedTag(nil)
              } label: {
                Label("Clear", systemImage: "xmark.circle.fill")
              }
              .buttonStyle(.plain)
              .help("Clear tag filter.")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
          } else if store.activeFilterTags.count > 1 {
            Text("Filter: \(store.activeFilterTags.count) tags")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
        .padding(.horizontal)
      }

      List(selection: $store.selectedPersonaID) {
        ForEach(filtered, id: \.persona.id) { rp in
          PersonaRow(
            persona: rp.persona,
            isPinned: store.pinnedPersonaIDs.contains(rp.persona.id)
          ) {
            store.togglePinnedPersona(id: rp.persona.id)
          }
            .tag(rp.persona.id)
        }
      }

      DiagnosticsFooter(diagnostics: store.diagnostics)
    }
    .sheet(isPresented: $showSaveFilterSheet) {
      FilterNameSheet(
        title: "Save Current Filter",
        confirmLabel: "Save",
        name: $pendingFilterName
      ) { name in
        store.saveCurrentFilter(name: name)
        pendingFilterName = ""
      }
    }
    .sheet(isPresented: $showRenameFilterSheet) {
      FilterNameSheet(
        title: "Rename Filter",
        confirmLabel: "Rename",
        name: $pendingFilterName
      ) { name in
        guard let target = renameTarget else { return }
        store.renameSavedFilter(id: target.id, newName: name)
        renameTarget = nil
        pendingFilterName = ""
      }
    }
    .alert("Delete Saved Filter?", isPresented: Binding(
      get: { deleteTarget != nil },
      set: { if !$0 { deleteTarget = nil } }
    )) {
      Button("Delete", role: .destructive) {
        if let target = deleteTarget {
          store.deleteSavedFilter(id: target.id)
        }
        deleteTarget = nil
      }
      Button("Cancel", role: .cancel) {
        deleteTarget = nil
      }
    } message: {
      Text("This will remove \"\(deleteTarget?.name ?? "this filter")\" from saved filters.")
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

  private var pinnedSection: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("Pinned")
        .font(.caption)
        .foregroundStyle(.secondary)

      Button {
        store.setPinnedViewActive()
      } label: {
        savedFilterRow(
          title: "Pinned Personas",
          isSelected: store.isPinnedViewActive
        )
      }
      .buttonStyle(.plain)
    }
  }

  private var savedFiltersSection: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack {
        Text("Saved")
          .font(.caption)
          .foregroundStyle(.secondary)
        Spacer()
        Button {
          beginSaveFilter()
        } label: {
          Image(systemName: "plus")
        }
        .buttonStyle(.plain)
        .help("Save current filter.")
      }

      VStack(alignment: .leading, spacing: 4) {
        Button {
          store.applyAllPersonasFilter()
        } label: {
          savedFilterRow(
            title: "All Personas",
            isSelected: store.selectedSavedFilterID == AppStore.allPersonasFilterID
          )
        }
        .buttonStyle(.plain)

        ForEach(store.savedFilters) { filter in
          Button {
            store.applySavedFilter(filter)
          } label: {
            savedFilterRow(
              title: filter.name,
              isSelected: store.selectedSavedFilterID == filter.id
            )
          }
          .buttonStyle(.plain)
          .contextMenu {
            Button("Rename…") {
              beginRename(filter)
            }
            Button("Delete…") {
              deleteTarget = filter
            }
          }
        }
      }
    }
  }

  private func savedFilterRow(title: String, isSelected: Bool) -> some View {
    HStack {
      Text(title)
        .font(.callout)
      Spacer()
      if isSelected {
        Image(systemName: "checkmark")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .padding(.vertical, 2)
  }

  private func beginSaveFilter() {
    let trimmed = store.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    if !trimmed.isEmpty {
      pendingFilterName = trimmed
    } else if store.activeFilterTags.count == 1, let tag = store.activeFilterTags.first {
      pendingFilterName = tag
    } else {
      pendingFilterName = "Saved Filter"
    }
    showSaveFilterSheet = true
  }

  private func beginRename(_ filter: SavedFilter) {
    renameTarget = filter
    pendingFilterName = filter.name
    showRenameFilterSheet = true
  }
}

private struct FilterNameSheet: View {
  let title: String
  let confirmLabel: String
  @Binding var name: String
  let onConfirm: (String) -> Void

  @Environment(\.dismiss) private var dismiss

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text(title)
        .font(.headline)

      TextField("Name", text: $name)
        .textFieldStyle(.roundedBorder)

      HStack {
        Spacer()
        Button("Cancel") {
          dismiss()
        }
        Button(confirmLabel) {
          let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
          guard !trimmed.isEmpty else { return }
          onConfirm(trimmed)
          dismiss()
        }
        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      }
    }
    .padding()
    .frame(minWidth: 320)
  }
}

private struct PersonaRow: View {
  let persona: Persona
  let isPinned: Bool
  let onTogglePin: () -> Void

  var body: some View {
    HStack(alignment: .top, spacing: 8) {
      VStack(alignment: .leading, spacing: 2) {
        Text(persona.name).font(.headline)
        Text(persona.id).font(.caption).foregroundStyle(.secondary)
        if let about = persona.about, !about.isEmpty {
          Text(about).font(.caption).foregroundStyle(.secondary).lineLimit(2)
        }
      }
      Spacer()
      Button(action: onTogglePin) {
        Image(systemName: isPinned ? "pin.fill" : "pin")
          .foregroundStyle(.secondary)
      }
      .buttonStyle(.borderless)
      .help(isPinned ? "Unpin persona" : "Pin persona")
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
