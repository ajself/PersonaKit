import Foundation
import PersonaKitCore

/// Saved filter and pin management helpers for ``AppStore``.
extension AppStore {
  /// Applies a saved filter snapshot to the current UI state.
  func applySavedFilterState(
    id: String?, queryText: String, tags: [String], sources: [String]
  ) {
    isApplyingSavedFilter = true
    state.selectedSavedFilterID = id
    state.searchText = queryText
    state.activeFilterTags = tags
    if tags.count == 1, let only = tags.first {
      state.selectedTag = only
    } else {
      state.selectedTag = nil
    }
    state.activeSourceKinds = parseSourceKinds(from: sources)
    isApplyingSavedFilter = false
  }

  /// Persists the current filter configuration under the provided name.
  func saveCurrentFilter(name: String) {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }

    let tags = Array(Set(state.activeFilterTags)).sorted()
    let sources = Array(Set(state.activeSourceKinds.map(\.rawValue))).sorted()

    let filter = SavedFilter(
      id: uuid().uuidString,
      name: trimmed,
      queryText: state.searchText,
      selectedTags: tags,
      selectedSources: sources,
      groupingMode: nil
    )

    state.savedFilters = sortSavedFilters(state.savedFilters + [filter])
    savedFiltersStore.save(state.savedFilters)
    state.selectedSavedFilterID = filter.id
    state.isPinnedViewActive = false
  }

  /// Renames a saved filter while preserving its query configuration.
  func renameSavedFilter(id: String, newName: String) {
    let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }
    guard let index = state.savedFilters.firstIndex(where: { $0.id == id }) else { return }

    let existing = state.savedFilters[index]
    let renamed = SavedFilter(
      id: existing.id,
      name: trimmed,
      queryText: existing.queryText,
      selectedTags: existing.selectedTags,
      selectedSources: existing.selectedSources,
      groupingMode: existing.groupingMode
    )
    var next = state.savedFilters
    next[index] = renamed
    state.savedFilters = sortSavedFilters(next)
    savedFiltersStore.save(state.savedFilters)
  }

  /// Deletes a saved filter and clears selection if needed.
  func deleteSavedFilter(id: String) {
    state.savedFilters.removeAll { $0.id == id }
    savedFiltersStore.save(state.savedFilters)
    if state.selectedSavedFilterID == id {
      state.selectedSavedFilterID = nil
    }
  }

  /// Toggles a persona's pinned state and persists the pin set.
  func togglePinnedPersona(id: String) {
    if state.pinnedPersonaIDs.contains(id) {
      state.pinnedPersonaIDs.remove(id)
      if state.pinnedPersonaIDs.isEmpty {
        state.isPinnedViewActive = false
      }
    } else {
      state.pinnedPersonaIDs.insert(id)
    }
    pinnedPersonasStore.save(Array(state.pinnedPersonaIDs))
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
