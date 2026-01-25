extension AppStore {
  func handleLifecycle(_ action: Action) -> Bool {
    switch action {
    case .task, .reloadAll:
      reloadAll()
      return true
    case .importPack:
      importPack()
      return true
    case .revealStorageRoot:
      revealStorageRoot()
      return true
    case .revealSelectedPack:
      revealSelectedPack()
      return true
    case .removeSelectedPack:
      removeSelectedPack()
      return true
    case .copyPromptToClipboard:
      copyPromptToClipboard()
      return true
    default:
      return false
    }
  }

  func handleFocus(_ action: Action) -> Bool {
    switch action {
    case .requestSidebarSearchFocus:
      state.sidebarSearchFocusRequest = SidebarSearchFocusRequest(id: uuid(), shouldFocus: true)
      return true
    case .requestSidebarSearchBlur:
      state.sidebarSearchFocusRequest = SidebarSearchFocusRequest(id: uuid(), shouldFocus: false)
      return true
    case .requestComposerFocus(let sectionKey):
      state.composerFocusRequest = ComposerFocusRequest(id: uuid(), sectionKey: sectionKey)
      return true
    case .setSidebarSearchFocused(let isFocused):
      state.isSidebarSearchFocused = isFocused
      return true
    default:
      return false
    }
  }

  func handleSelection(_ action: Action) -> Bool {
    switch action {
    case .setSelectedPersonaID(let id):
      state.selectedPersonaID = id
      recomputePreview()
      return true
    case .setComposerValue(let key, let value):
      state.composerValues[key] = value
      recomputePreview()
      return true
    case .setJSONPreview(let text):
      updateJSONPreview(text, scheduleFormat: true)
      return true
    default:
      return false
    }
  }

  func handleFiltering(_ action: Action) -> Bool {
    if handleSearchFiltering(action) { return true }
    if handleSavedFilterActions(action) { return true }
    return false
  }

  private func handleSearchFiltering(_ action: Action) -> Bool {
    switch action {
    case .setSearchText(let text):
      state.searchText = text
      if !isApplyingSavedFilter {
        state.selectedSavedFilterID = nil
      }
      return true
    case .setSelectedTag(let tag):
      state.selectedTag = tag
      if let tag, !tag.isEmpty {
        state.activeFilterTags = [tag]
      } else {
        state.activeFilterTags = []
      }
      if !isApplyingSavedFilter {
        state.selectedSavedFilterID = nil
      }
      return true
    default:
      return false
    }
  }

  private func handleSavedFilterActions(_ action: Action) -> Bool {
    switch action {
    case .applyAllPersonasFilter:
      state.isPinnedViewActive = false
      applySavedFilterState(
        id: Self.allPersonasFilterID,
        queryText: "",
        tags: [],
        sources: []
      )
      return true
    case .applySavedFilter(let filter):
      state.isPinnedViewActive = false
      applySavedFilterState(
        id: filter.id,
        queryText: filter.queryText,
        tags: filter.selectedTags,
        sources: filter.selectedSources
      )
      return true
    case .saveCurrentFilter(let name):
      saveCurrentFilter(name: name)
      return true
    case .renameSavedFilter(let id, let newName):
      renameSavedFilter(id: id, newName: newName)
      return true
    case .deleteSavedFilter(let id):
      deleteSavedFilter(id: id)
      return true
    default:
      return false
    }
  }

  func handlePinned(_ action: Action) -> Bool {
    switch action {
    case .setPinnedViewActive:
      if state.isPinnedViewActive {
        state.isPinnedViewActive = false
        return true
      }
      state.isPinnedViewActive = true
      state.selectedSavedFilterID = nil
      return true
    case .togglePinnedPersona(let id):
      togglePinnedPersona(id: id)
      return true
    default:
      return false
    }
  }
}
