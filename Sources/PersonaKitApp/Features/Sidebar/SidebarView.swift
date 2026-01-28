import PersonaKitCore
import SwiftUI

/// Sidebar showing search, filters, and the persona list.
struct SidebarView: View {
  @Environment(SidebarModel.self)
  private var sidebar
  let personaIndex: [String: ResolvedPersona]
  let personaSourcesByID: [String: PersonaSource]
  let diagnostics: [Diagnostic]
  let selectedPersonaID: Binding<String?>
  @FocusState private var searchFocused: Bool
  @State private var showSaveFilterSheet = false
  @State private var showRenameFilterSheet = false
  @State private var pendingFilterName = ""
  @State private var renameTarget: SavedFilter?
  @State private var deleteTarget: SavedFilter?

  /// Builds the sidebar stack including filters and diagnostics.
  var body: some View {
    VStack(spacing: 8) {
      searchField

      pinnedSection
        .padding(.horizontal)

      savedFiltersSection
        .padding(.horizontal)

      tagFilterSection

      personaList

      DiagnosticsFooter(diagnostics: diagnostics)
    }
    .sheet(isPresented: $showSaveFilterSheet) {
      FilterNameSheet(
        title: "Save Current Filter",
        confirmLabel: "Save",
        name: $pendingFilterName
      ) { name in
        sidebar.saveCurrentFilter(name: name)
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
        sidebar.renameSavedFilter(id: target.id, newName: name)
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
          sidebar.deleteSavedFilter(id: target.id)
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
  /// Binding for the search field text.
  fileprivate var searchBinding: Binding<String> {
    Binding(
      get: { sidebar.searchText },
      set: { sidebar.setSearchText($0) }
    )
  }

  /// All personas sorted by the canonical metadata sort key.
  fileprivate var allPersonas: [ResolvedPersona] {
    personaIndex.values.sorted {
      PersonaMetadata.personaSortKey($0.persona) < PersonaMetadata.personaSortKey($1.persona)
    }
  }

  /// Personas filtered by search, tags, pins, and source kind.
  fileprivate var filtered: [ResolvedPersona] {
    allPersonas.filter { rp in
      let persona = rp.persona
      let matchesPinned: Bool = {
        guard sidebar.isPinnedViewActive else { return true }
        return sidebar.pinnedPersonaIDs.contains(persona.id)
      }()
      let matchesSearch =
        sidebar.searchText.isEmpty
        || persona.name.localizedCaseInsensitiveContains(sidebar.searchText)
        || (persona.id.localizedCaseInsensitiveContains(sidebar.searchText))
        || (persona.about?.localizedCaseInsensitiveContains(sidebar.searchText) ?? false)
        || persona.sortedTags.contains(where: {
          $0.localizedCaseInsensitiveContains(sidebar.searchText)
        })

      let matchesTag: Bool = {
        guard !sidebar.activeFilterTags.isEmpty else { return true }
        let tags = persona.tags ?? []
        return sidebar.activeFilterTags.allSatisfy { tags.contains($0) }
      }()

      let matchesSource: Bool = {
        guard !sidebar.activeSourceKinds.isEmpty else { return true }
        guard let kind = personaSourcesByID[persona.id]?.kind else { return false }
        return sidebar.activeSourceKinds.contains(kind)
      }()

      return matchesPinned && matchesSearch && matchesTag && matchesSource
    }
  }

  /// A sorted list of all known tags from available personas.
  fileprivate var allTags: [String] {
    PersonaMetadata.sortedUniqueTags(from: personaIndex.values.map { $0.persona })
  }

  /// Search field with focus management and sidebar bindings.
  fileprivate var searchField: some View {
    TextField("Search personas", text: searchBinding)
      .textFieldStyle(.roundedBorder)
      .focused($searchFocused)
      .padding([.top, .horizontal])
      .onChange(of: sidebar.searchFocusRequest) { _, request in
        searchFocused = request.shouldFocus
      }
      .onChange(of: searchFocused) { _, newValue in
        sidebar.setSearchFocused(newValue)
      }
      .help("Search by name, id, description, or tag.")
  }

  /// Pinned personas section shortcut.
  fileprivate var pinnedSection: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("Pinned")
        .font(.caption)
        .foregroundStyle(.secondary)

      Button {
        sidebar.togglePinnedView()
      } label: {
        savedFilterRow(
          title: "Pinned Personas",
          isSelected: sidebar.isPinnedViewActive
        )
      }
      .buttonStyle(.plain)
    }
  }

  /// Saved filter list and management controls.
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
          sidebar.applyAllPersonasFilter()
        } label: {
          savedFilterRow(
            title: "All Personas",
            isSelected: sidebar.selectedSavedFilterID == SidebarModel.allPersonasFilterID
          )
        }
        .buttonStyle(.plain)

        ForEach(sidebar.savedFilters) { filter in
          Button {
            sidebar.applySavedFilter(filter)
          } label: {
            savedFilterRow(
              title: filter.name,
              isSelected: sidebar.selectedSavedFilterID == filter.id
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

  /// Tag filter menu and current tag summary.
  @ViewBuilder fileprivate var tagFilterSection: some View {
    if !allTags.isEmpty {
      VStack(alignment: .leading, spacing: 6) {
        HStack {
          Menu {
            Button {
              sidebar.setSelectedTag(nil)
            } label: {
              tagMenuRow(title: "All", isSelected: sidebar.activeFilterTags.isEmpty)
            }
            Divider()
            ForEach(allTags, id: \.self) { tag in
              Button {
                sidebar.setSelectedTag(tag)
              } label: {
                tagMenuRow(
                  title: tag,
                  isSelected: sidebar.activeFilterTags.contains(tag)
                )
              }
            }
          } label: {
            Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
          }
          .help("Filter personas by tag.")

          Spacer()
        }

        if let selectedTag = sidebar.selectedTag, !selectedTag.isEmpty {
          HStack(spacing: 6) {
            Text("Filter: \(selectedTag)")
            Button {
              sidebar.setSelectedTag(nil)
            } label: {
              Label("Clear", systemImage: "xmark.circle.fill")
            }
            .buttonStyle(.plain)
            .help("Clear tag filter.")
          }
          .font(.caption)
          .foregroundStyle(.secondary)
        } else if sidebar.activeFilterTags.count > 1 {
          Text("Filter: \(sidebar.activeFilterTags.count) tags")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
      .padding(.horizontal)
    }
  }

  /// List of personas matching the active filters.
  fileprivate var personaList: some View {
    List(selection: selectedPersonaID) {
      ForEach(filtered, id: \.persona.id) { rp in
        PersonaRow(
          persona: rp.persona,
          isPinned: sidebar.pinnedPersonaIDs.contains(rp.persona.id)
        ) {
          sidebar.togglePinnedPersona(id: rp.persona.id)
        }
        .tag(rp.persona.id)
      }
    }
  }

  /// Builds a tag row with an optional selection checkmark.
  fileprivate func tagMenuRow(title: String, isSelected: Bool) -> some View {
    HStack {
      Text(title)
      Spacer()
      if isSelected {
        Image(systemName: "checkmark")
      }
    }
  }

  /// Builds a saved-filter row with an optional selection checkmark.
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

  /// Seeds and presents the save filter sheet.
  fileprivate func beginSaveFilter() {
    let trimmed = sidebar.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    if !trimmed.isEmpty {
      pendingFilterName = trimmed
    } else if sidebar.activeFilterTags.count == 1 {
      pendingFilterName = sidebar.activeFilterTags.first ?? "Saved Filter"
    } else {
      pendingFilterName = "Saved Filter"
    }
    showSaveFilterSheet = true
  }

  /// Seeds and presents the rename filter sheet.
  fileprivate func beginRename(_ filter: SavedFilter) {
    renameTarget = filter
    pendingFilterName = filter.name
    showRenameFilterSheet = true
  }
}

/// Sheet for entering or editing a filter name.
private struct FilterNameSheet: View {
  let title: String
  let confirmLabel: String
  @Binding var name: String
  let onConfirm: (String) -> Void

  @Environment(\.dismiss)
  private var dismiss

  /// Builds the name entry sheet with validation.
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

/// A row rendering basic persona metadata plus pin control.
private struct PersonaRow: View {
  let persona: Persona
  let isPinned: Bool
  let onTogglePin: () -> Void

  /// Builds the persona summary row.
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

/// Footer that renders diagnostics produced during pack loading.
private struct DiagnosticsFooter: View {
  let diagnostics: [Diagnostic]

  /// Renders a scrollable diagnostics list when issues exist.
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
