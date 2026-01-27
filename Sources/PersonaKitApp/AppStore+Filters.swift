import Foundation
import PersonaKitCore

/// Saved filter and pin management helpers for ``AppStore``.
extension AppStore {
  /// Applies a saved filter snapshot to the current UI state.
  func applySavedFilterState(
    id: String?, queryText: String, tags: [String], sources: [String]
  ) {
    isApplyingSavedFilter = true
    state.sidebar.selectedSavedFilterID = id
    state.sidebar.searchText = queryText
    state.sidebar.activeFilterTags = tags
    if tags.count == 1, let only = tags.first {
      state.sidebar.selectedTag = only
    } else {
      state.sidebar.selectedTag = nil
    }
    state.sidebar.activeSourceKinds = parseSourceKinds(from: sources)
    isApplyingSavedFilter = false
  }

  /// Persists the current filter configuration under the provided name.
  func saveCurrentFilter(name: String) {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }

    let tags = Array(Set(state.sidebar.activeFilterTags)).sorted()
    let sources = Array(Set(state.sidebar.activeSourceKinds.map(\.rawValue))).sorted()

    let filter = SavedFilter(
      id: uuid().uuidString,
      name: trimmed,
      queryText: state.sidebar.searchText,
      selectedTags: tags,
      selectedSources: sources,
      groupingMode: nil
    )

    state.sidebar.savedFilters = sortSavedFilters(state.sidebar.savedFilters + [filter])
    savedFiltersStore.save(state.sidebar.savedFilters)
    state.sidebar.selectedSavedFilterID = filter.id
    state.sidebar.isPinnedViewActive = false
  }

  /// Renames a saved filter while preserving its query configuration.
  func renameSavedFilter(id: String, newName: String) {
    let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }
    guard let index = state.sidebar.savedFilters.firstIndex(where: { $0.id == id }) else { return }

    let existing = state.sidebar.savedFilters[index]
    let renamed = SavedFilter(
      id: existing.id,
      name: trimmed,
      queryText: existing.queryText,
      selectedTags: existing.selectedTags,
      selectedSources: existing.selectedSources,
      groupingMode: existing.groupingMode
    )
    var next = state.sidebar.savedFilters
    next[index] = renamed
    state.sidebar.savedFilters = sortSavedFilters(next)
    savedFiltersStore.save(state.sidebar.savedFilters)
  }

  /// Deletes a saved filter and clears selection if needed.
  func deleteSavedFilter(id: String) {
    state.sidebar.savedFilters.removeAll { $0.id == id }
    savedFiltersStore.save(state.sidebar.savedFilters)
    if state.sidebar.selectedSavedFilterID == id {
      state.sidebar.selectedSavedFilterID = nil
    }
  }

  /// Toggles a persona's pinned state and persists the pin set.
  func togglePinnedPersona(id: String) {
    if state.sidebar.pinnedPersonaIDs.contains(id) {
      state.sidebar.pinnedPersonaIDs.remove(id)
      if state.sidebar.pinnedPersonaIDs.isEmpty {
        state.sidebar.isPinnedViewActive = false
      }
    } else {
      state.sidebar.pinnedPersonaIDs.insert(id)
    }
    pinnedPersonasStore.save(Array(state.sidebar.pinnedPersonaIDs))
  }

  private func parseSourceKinds(from values: [String]) -> Set<PersonaSource.Kind> {
    Set(values.compactMap(PersonaSource.Kind.init(rawValue:)))
  }

  private func sortSavedFilters(_ filters: [SavedFilter]) -> [SavedFilter] {
    filters.sorted { lhs, rhs in
      if lhs.name != rhs.name { return lhs.name < rhs.name }
      return lhs.id < rhs.id
    }
  }
}
