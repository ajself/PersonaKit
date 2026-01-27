/// Sidebar feature handling for ``AppStore``.
extension AppStore {
  /// Routes sidebar actions to state mutations.
  func handleSidebar(_ action: SidebarFeature.Action) {
    switch action {
    case .requestSearchFocus, .requestSearchBlur, .setSearchFocused:
      handleSidebarSearchFocus(action)
    case .setSearchText, .setSelectedTag:
      handleSidebarSearchContent(action)
    case .applyAllPersonasFilter, .applySavedFilter:
      handleSidebarFilterApply(action)
    case .saveCurrentFilter, .renameSavedFilter, .deleteSavedFilter:
      handleSidebarSavedFilters(action)
    case .setPinnedViewActive, .togglePinnedPersona:
      handleSidebarPins(action)
    }
  }

  private func handleSidebarSearchFocus(_ action: SidebarFeature.Action) {
    switch action {
    case .requestSearchFocus:
      state.sidebar.searchFocusRequest = SidebarFeature.SearchFocusRequest(
        id: uuid(),
        shouldFocus: true
      )
    case .requestSearchBlur:
      state.sidebar.searchFocusRequest = SidebarFeature.SearchFocusRequest(
        id: uuid(),
        shouldFocus: false
      )
    case .setSearchFocused(let isFocused):
      state.sidebar.isSearchFocused = isFocused
    default:
      return
    }
  }

  private func handleSidebarSearchContent(_ action: SidebarFeature.Action) {
    switch action {
    case .setSearchText(let text):
      state.sidebar.searchText = text
      if !isApplyingSavedFilter {
        state.sidebar.selectedSavedFilterID = nil
      }
    case .setSelectedTag(let tag):
      state.sidebar.selectedTag = tag
      if let tag, !tag.isEmpty {
        state.sidebar.activeFilterTags = [tag]
      } else {
        state.sidebar.activeFilterTags = []
      }
      if !isApplyingSavedFilter {
        state.sidebar.selectedSavedFilterID = nil
      }
    default:
      return
    }
  }

  private func handleSidebarFilterApply(_ action: SidebarFeature.Action) {
    switch action {
    case .applyAllPersonasFilter:
      state.sidebar.isPinnedViewActive = false
      applySavedFilterState(
        id: SidebarFeature.allPersonasFilterID,
        queryText: "",
        tags: [],
        sources: []
      )
    case .applySavedFilter(let filter):
      state.sidebar.isPinnedViewActive = false
      applySavedFilterState(
        id: filter.id,
        queryText: filter.queryText,
        tags: filter.selectedTags,
        sources: filter.selectedSources
      )
    default:
      return
    }
  }

  private func handleSidebarSavedFilters(_ action: SidebarFeature.Action) {
    switch action {
    case .saveCurrentFilter(let name):
      saveCurrentFilter(name: name)
    case .renameSavedFilter(let id, let newName):
      renameSavedFilter(id: id, newName: newName)
    case .deleteSavedFilter(let id):
      deleteSavedFilter(id: id)
    default:
      return
    }
  }

  private func handleSidebarPins(_ action: SidebarFeature.Action) {
    switch action {
    case .setPinnedViewActive:
      if state.sidebar.isPinnedViewActive {
        state.sidebar.isPinnedViewActive = false
        return
      }
      state.sidebar.isPinnedViewActive = true
      state.sidebar.selectedSavedFilterID = nil
    case .togglePinnedPersona(let id):
      togglePinnedPersona(id: id)
    default:
      return
    }
  }
}
