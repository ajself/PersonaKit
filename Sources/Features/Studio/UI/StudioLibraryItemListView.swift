import ContextCore
import ContextWorkspaceCore
import SwiftUI

/// Library and essentials list rows with scope badges.
struct StudioLibraryItemListView: View {
  let visibleItems: [WorkspaceListItem]
  @Binding var selectedLibraryItemID: String?

  var body: some View {
    List(visibleItems, id: \.id, selection: $selectedLibraryItemID) { item in
      VStack(alignment: .leading, spacing: 6) {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
          Text(item.id)
            .font(.headline)

          Spacer()

          scopeBadge(scope: item.sourceScope)
        }

        if item.displayName != item.id {
          Text(item.displayName)
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }

        Text(item.fileURL.path())
          .font(.caption.monospaced())
          .foregroundStyle(.tertiary)
          .textSelection(.enabled)
      }
      .padding(.vertical, 4)
      .tag(Optional(item.id))
    }
    .overlay {
      if visibleItems.isEmpty {
        ContentUnavailableView.search
      }
    }
  }

  private func scopeBadge(scope: WorkspaceSourceScope) -> some View {
    Text(scope.displayName)
      .font(.caption2)
      .fontWeight(.semibold)
      .padding(.horizontal, 6)
      .padding(.vertical, 2)
      .background(
        RoundedRectangle(cornerRadius: 8)
          .fill(scope == .project ? .blue.opacity(0.16) : .secondary.opacity(0.16))
      )
  }
}
