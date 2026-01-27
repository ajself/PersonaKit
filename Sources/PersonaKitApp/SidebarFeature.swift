import Foundation
import PersonaKitCore

/// Sidebar feature state and actions.
enum SidebarFeature {
  /// A tokenized focus request used to drive sidebar search focus changes.
  struct SearchFocusRequest: Equatable {
    let id: UUID
    let shouldFocus: Bool
  }

  /// Sidebar-specific UI state.
  struct State {
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

    init(
      searchText: String = "",
      selectedTag: String? = nil,
      activeFilterTags: [String] = [],
      activeSourceKinds: Set<PersonaSource.Kind> = [],
      savedFilters: [SavedFilter] = [],
      selectedSavedFilterID: String? = nil,
      pinnedPersonaIDs: Set<String> = [],
      isPinnedViewActive: Bool = false,
      searchFocusRequest: SearchFocusRequest = .initial,
      isSearchFocused: Bool = false
    ) {
      self.searchText = searchText
      self.selectedTag = selectedTag
      self.activeFilterTags = activeFilterTags
      self.activeSourceKinds = activeSourceKinds
      self.savedFilters = savedFilters
      self.selectedSavedFilterID = selectedSavedFilterID
      self.pinnedPersonaIDs = pinnedPersonaIDs
      self.isPinnedViewActive = isPinnedViewActive
      self.searchFocusRequest = searchFocusRequest
      self.isSearchFocused = isSearchFocused
    }
  }

  /// Actions handled by the sidebar feature.
  enum Action {
    case requestSearchFocus
    case requestSearchBlur
    case setSearchFocused(Bool)
    case setSearchText(String)
    case setSelectedTag(String?)
    case applyAllPersonasFilter
    case applySavedFilter(SavedFilter)
    case saveCurrentFilter(name: String)
    case renameSavedFilter(id: String, newName: String)
    case deleteSavedFilter(id: String)
    case setPinnedViewActive
    case togglePinnedPersona(id: String)
  }

  /// Stable identifier for the built-in "All Personas" filter.
  static let allPersonasFilterID = "all-personas"
}

extension SidebarFeature.SearchFocusRequest {
  static let initial = SidebarFeature.SearchFocusRequest(
    id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
    shouldFocus: false
  )
}
