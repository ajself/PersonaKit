import ContextCore
import ContextWorkspaceCore
import SwiftUI

/// Library list rows: name first, id second, with a scope badge.
struct StudioLibraryItemListView: View {
  let selection: SidebarItem
  let visibleItems: [WorkspaceListItem]
  let searchText: String
  @Binding var selectedLibraryItemID: String?

  var body: some View {
    List(visibleItems, id: \.id, selection: $selectedLibraryItemID) { item in
      StudioListRow(
        title: item.displayName,
        subtitle: item.displayName == item.id ? nil : item.id,
        scope: item.sourceScope
      )
      .tag(Optional(item.id))
    }
    .overlay {
      if visibleItems.isEmpty {
        emptyState
      }
    }
  }

  @ViewBuilder
  private var emptyState: some View {
    if !searchText.isEmpty {
      ContentUnavailableView.search(text: searchText)
    } else {
      ContentUnavailableView(
        "No \(selection.title)",
        systemImage: selection.systemImage,
        description: Text("Use New to add one to this project.")
      )
    }
  }
}
