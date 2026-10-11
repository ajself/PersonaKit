import ContextWorkspaceCore

/// Search filtering for library list rows.
enum StudioLibraryItemFilter {
  static func normalizedSearchText(_ searchText: String) -> String {
    searchText.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  /// Matches the item id or display name, case-insensitively; blank search keeps everything.
  static func filteredItems(
    _ items: [WorkspaceListItem],
    searchText: String
  ) -> [WorkspaceListItem] {
    let normalizedSearch = normalizedSearchText(searchText)

    guard !normalizedSearch.isEmpty else {
      return items
    }

    return items.filter { item in
      item.id.localizedCaseInsensitiveContains(normalizedSearch)
        || item.displayName.localizedCaseInsensitiveContains(normalizedSearch)
    }
  }
}
