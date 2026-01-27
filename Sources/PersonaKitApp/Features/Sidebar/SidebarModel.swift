import Dependencies
import Foundation
import Observation
import PersonaKitCore

/// Sidebar state owner and mutation surface.
@MainActor
@Observable
final class SidebarModel {
  /// A tokenized focus request used to drive sidebar search focus changes.
  struct SearchFocusRequest: Equatable {
    let id: UUID
    let shouldFocus: Bool
  }

  /// Stable identifier for the built-in "All Personas" filter.
  static let allPersonasFilterID = "all-personas"

  var searchText: String
  var selectedTag: String?
  var activeFilterTags: [String]
  var activeSourceKinds: Set<PersonaSource.Kind>
  var savedFilters: [SavedFilter]
  var selectedSavedFilterID: String?
  var pinnedPersonaIDs: Set<String>
  var isPinnedViewActive: Bool
  var searchFocusRequest: SearchFocusRequest
  var isSearchFocused: Bool

  @Dependency(\.uuid)
  @ObservationIgnored private var uuid

  private let savedFiltersStore: SavedFiltersStore
  private let pinnedPersonasStore: PinnedPersonasStore
  private var isApplyingSavedFilter = false

  init(
    savedFiltersStore: SavedFiltersStore = SavedFiltersStore(),
    pinnedPersonasStore: PinnedPersonasStore = PinnedPersonasStore()
  ) {
    self.savedFiltersStore = savedFiltersStore
    self.pinnedPersonasStore = pinnedPersonasStore
    self.searchText = ""
    self.selectedTag = nil
    self.activeFilterTags = []
    self.activeSourceKinds = []
    self.savedFilters = savedFiltersStore.load()
    self.selectedSavedFilterID = SidebarModel.allPersonasFilterID
    self.pinnedPersonaIDs = Set(pinnedPersonasStore.load())
    self.isPinnedViewActive = false
    self.searchFocusRequest = .initial
    self.isSearchFocused = false
  }

  /// Requests focus for the sidebar search field.
  func requestSearchFocus() {
    searchFocusRequest = SearchFocusRequest(id: uuid(), shouldFocus: true)
  }

  /// Requests blur for the sidebar search field.
  func requestSearchBlur() {
    searchFocusRequest = SearchFocusRequest(id: uuid(), shouldFocus: false)
  }

  /// Records the current focus state of the sidebar search field.
  func setSearchFocused(_ isFocused: Bool) {
    isSearchFocused = isFocused
  }

  /// Updates the search text and clears saved filter selection if needed.
  func setSearchText(_ text: String) {
    searchText = text
    if !isApplyingSavedFilter {
      selectedSavedFilterID = nil
    }
  }

  /// Updates the selected tag filter and clears saved filter selection if needed.
  func setSelectedTag(_ tag: String?) {
    selectedTag = tag
    if let tag, !tag.isEmpty {
      activeFilterTags = [tag]
    } else {
      activeFilterTags = []
    }
    if !isApplyingSavedFilter {
      selectedSavedFilterID = nil
    }
  }

  /// Applies the built-in "All Personas" filter.
  func applyAllPersonasFilter() {
    isPinnedViewActive = false
    applySavedFilterState(
      id: SidebarModel.allPersonasFilterID,
      queryText: "",
      tags: [],
      sources: []
    )
  }

  /// Applies a saved filter definition to the sidebar.
  func applySavedFilter(_ filter: SavedFilter) {
    isPinnedViewActive = false
    applySavedFilterState(
      id: filter.id,
      queryText: filter.queryText,
      tags: filter.selectedTags,
      sources: filter.selectedSources
    )
  }

  /// Toggles the pinned personas view on or off.
  func togglePinnedView() {
    if isPinnedViewActive {
      isPinnedViewActive = false
      return
    }
    isPinnedViewActive = true
    selectedSavedFilterID = nil
  }

  /// Toggles a persona's pinned state and persists the pin set.
  func togglePinnedPersona(id: String) {
    if pinnedPersonaIDs.contains(id) {
      pinnedPersonaIDs.remove(id)
      if pinnedPersonaIDs.isEmpty {
        isPinnedViewActive = false
      }
    } else {
      pinnedPersonaIDs.insert(id)
    }
    pinnedPersonasStore.save(Array(pinnedPersonaIDs))
  }

  /// Persists the current filter configuration under the provided name.
  func saveCurrentFilter(name: String) {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }

    let tags = Array(Set(activeFilterTags)).sorted()
    let sources = Array(Set(activeSourceKinds.map(\.rawValue))).sorted()

    let filter = SavedFilter(
      id: uuid().uuidString,
      name: trimmed,
      queryText: searchText,
      selectedTags: tags,
      selectedSources: sources,
      groupingMode: nil
    )

    savedFilters = sortSavedFilters(savedFilters + [filter])
    savedFiltersStore.save(savedFilters)
    selectedSavedFilterID = filter.id
    isPinnedViewActive = false
  }

  /// Renames a saved filter while preserving its query configuration.
  func renameSavedFilter(id: String, newName: String) {
    let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }
    guard let index = savedFilters.firstIndex(where: { $0.id == id }) else { return }

    let existing = savedFilters[index]
    let renamed = SavedFilter(
      id: existing.id,
      name: trimmed,
      queryText: existing.queryText,
      selectedTags: existing.selectedTags,
      selectedSources: existing.selectedSources,
      groupingMode: existing.groupingMode
    )
    var next = savedFilters
    next[index] = renamed
    savedFilters = sortSavedFilters(next)
    savedFiltersStore.save(savedFilters)
  }

  /// Deletes a saved filter and clears selection if needed.
  func deleteSavedFilter(id: String) {
    savedFilters.removeAll { $0.id == id }
    savedFiltersStore.save(savedFilters)
    if selectedSavedFilterID == id {
      selectedSavedFilterID = nil
    }
  }

  private func applySavedFilterState(
    id: String?,
    queryText: String,
    tags: [String],
    sources: [String]
  ) {
    isApplyingSavedFilter = true
    selectedSavedFilterID = id
    searchText = queryText
    activeFilterTags = tags
    if tags.count == 1, let only = tags.first {
      selectedTag = only
    } else {
      selectedTag = nil
    }
    activeSourceKinds = parseSourceKinds(from: sources)
    isApplyingSavedFilter = false
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

extension SidebarModel.SearchFocusRequest {
  static let initial = SidebarModel.SearchFocusRequest(
    id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
    shouldFocus: false
  )
}
