import PersonaKitCore
import SwiftUI

struct SidebarView: View {
  @Environment(AppStore.self)
  private var store
  @FocusState private var searchFocused: Bool
  @State private var showSaveFilterSheet = false
  @State private var showRenameFilterSheet = false
  @State private var pendingFilterName = ""
  @State private var renameTarget: SavedFilter?
  @State private var deleteTarget: SavedFilter?

  var body: some View {
    VStack(spacing: 8) {
      searchField

      pinnedSection
        .padding(.horizontal)

      savedFiltersSection
        .padding(.horizontal)

      tagFilterSection

      personaList

      DiagnosticsFooter(diagnostics: store.state.diagnostics)
    }
    .sheet(isPresented: $showSaveFilterSheet) {
      FilterNameSheet(
        title: "Save Current Filter",
        confirmLabel: "Save",
        name: $pendingFilterName
      ) { name in
        store.send(.saveCurrentFilter(name: name))
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
        store.send(.renameSavedFilter(id: target.id, newName: name))
        renameTarget = nil
        pendingFilterName = ""
      }
    }
    .alert(
      "Delete Saved Filter?",
      isPresented: Binding(
        get: { deleteTarget != nil },
        set: { if !$0 { deleteTarget = nil } }
      )
    ) {
      Button("Delete", role: .destructive) {
        if let target = deleteTarget {
          store.send(.deleteSavedFilter(id: target.id))
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

}

extension SidebarView {
  fileprivate var searchBinding: Binding<String> {
    store.bindingForSearchText()
  }

  fileprivate var allPersonas: [ResolvedPersona] {
    store.state.personaIndex.values.sorted {
      PersonaMetadata.personaSortKey($0.persona) < PersonaMetadata.personaSortKey($1.persona)
    }
  }

  fileprivate var filtered: [ResolvedPersona] {
    allPersonas.filter { rp in
      let persona = rp.persona
      let matchesPinned: Bool = {
        guard store.state.isPinnedViewActive else { return true }
        return store.state.pinnedPersonaIDs.contains(persona.id)
      }()
      let matchesSearch =
        store.state.searchText.isEmpty
        || persona.name.localizedCaseInsensitiveContains(store.state.searchText)
        || (persona.id.localizedCaseInsensitiveContains(store.state.searchText))
        || (persona.about?.localizedCaseInsensitiveContains(store.state.searchText) ?? false)
        || persona.sortedTags.contains(where: {
          $0.localizedCaseInsensitiveContains(store.state.searchText)
        })

      let matchesTag: Bool = {
        guard !store.state.activeFilterTags.isEmpty else { return true }
        let tags = persona.tags ?? []
        return store.state.activeFilterTags.allSatisfy { tags.contains($0) }
      }()

      let matchesSource: Bool = {
        guard !store.state.activeSourceKinds.isEmpty else { return true }
        guard let kind = store.state.personaSourcesByID[persona.id]?.kind else { return false }
        return store.state.activeSourceKinds.contains(kind)
      }()

      return matchesPinned && matchesSearch && matchesTag && matchesSource
    }
  }

  fileprivate var allTags: [String] {
    PersonaMetadata.sortedUniqueTags(from: store.state.personaIndex.values.map { $0.persona })
  }

  fileprivate var searchField: some View {
    TextField("Search personas", text: searchBinding)
      .textFieldStyle(.roundedBorder)
      .focused($searchFocused)
      .padding([.top, .horizontal])
      .onChange(of: store.state.sidebarSearchFocusRequest) { _, request in
        searchFocused = request.shouldFocus
      }
      .onChange(of: searchFocused) { _, newValue in
        store.send(.setSidebarSearchFocused(newValue))
      }
      .help("Search by name, id, description, or tag.")
  }

  fileprivate var pinnedSection: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("Pinned")
        .font(.caption)
        .foregroundStyle(.secondary)

      Button {
        store.send(.setPinnedViewActive)
      } label: {
        savedFilterRow(
          title: "Pinned Personas",
          isSelected: store.state.isPinnedViewActive
        )
      }
      .buttonStyle(.plain)
    }
  }

  fileprivate var savedFiltersSection: some View {
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
          store.send(.applyAllPersonasFilter)
        } label: {
          savedFilterRow(
            title: "All Personas",
            isSelected: store.state.selectedSavedFilterID == AppStore.allPersonasFilterID
          )
        }
        .buttonStyle(.plain)

        ForEach(store.state.savedFilters) { filter in
          Button {
            store.send(.applySavedFilter(filter))
          } label: {
            savedFilterRow(
              title: filter.name,
              isSelected: store.state.selectedSavedFilterID == filter.id
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

  @ViewBuilder fileprivate var tagFilterSection: some View {
    if !allTags.isEmpty {
      VStack(alignment: .leading, spacing: 6) {
        HStack {
          Menu {
            Button {
              store.send(.setSelectedTag(nil))
            } label: {
              tagMenuRow(title: "All", isSelected: store.state.activeFilterTags.isEmpty)
            }
            Divider()
            ForEach(allTags, id: \.self) { tag in
              Button {
                store.send(.setSelectedTag(tag))
              } label: {
                tagMenuRow(title: tag, isSelected: store.state.activeFilterTags.contains(tag))
              }
            }
          } label: {
            Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
          }
          .help("Filter personas by tag.")

          Spacer()
        }

        if let selectedTag = store.state.selectedTag, !selectedTag.isEmpty {
          HStack(spacing: 6) {
            Text("Filter: \(selectedTag)")
            Button {
              store.send(.setSelectedTag(nil))
            } label: {
              Label("Clear", systemImage: "xmark.circle.fill")
            }
            .buttonStyle(.plain)
            .help("Clear tag filter.")
          }
          .font(.caption)
          .foregroundStyle(.secondary)
        } else if store.state.activeFilterTags.count > 1 {
          Text("Filter: \(store.state.activeFilterTags.count) tags")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
      .padding(.horizontal)
    }
  }

  fileprivate var personaList: some View {
    List(selection: store.bindingForSelectedPersonaID()) {
      ForEach(filtered, id: \.persona.id) { rp in
        PersonaRow(
          persona: rp.persona,
          isPinned: store.state.pinnedPersonaIDs.contains(rp.persona.id)
        ) {
          store.send(.togglePinnedPersona(id: rp.persona.id))
        }
        .tag(rp.persona.id)
      }
    }
  }

  fileprivate func tagMenuRow(title: String, isSelected: Bool) -> some View {
    HStack {
      Text(title)
      Spacer()
      if isSelected {
        Image(systemName: "checkmark")
      }
    }
  }

  fileprivate func savedFilterRow(title: String, isSelected: Bool) -> some View {
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

  fileprivate func beginSaveFilter() {
    let trimmed = store.state.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    if !trimmed.isEmpty {
      pendingFilterName = trimmed
    } else if store.state.activeFilterTags.count == 1 {
      pendingFilterName = store.state.activeFilterTags.first ?? "Saved Filter"
    } else {
      pendingFilterName = "Saved Filter"
    }
    showSaveFilterSheet = true
  }

  fileprivate func beginRename(_ filter: SavedFilter) {
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

  @Environment(\.dismiss)
  private var dismiss

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
            ForEach(Array(diagnostics.enumerated()), id: \.offset) { _, diagnostic in
              Text(
                "• [\(diagnostic.severity.rawValue.uppercased())] \(diagnostic.userFacingMessage)"
              )
              .font(.caption2)
              .foregroundStyle(diagnostic.severity == .error ? .red : .orange)
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
