import ContextCore
import ContextWorkspaceCore
import SwiftUI

/// Sessions list panel with CRUD actions and project/global scope labels.
struct SessionsListTabView: View {
  let items: [WorkspaceSessionListItem]
  let snapshot: WorkspaceSnapshot
  @Binding var searchText: String
  @Binding var selectedSessionID: String?
  let sessionActionErrorMessage: String?
  let actionState: SessionsActionState
  let onNewSession: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      StudioActionBarView(
        actions: actionItems,
        isLoading: actionState.isLoadingDraft,
        searchText: $searchText,
        searchPrompt: "Search Sessions"
      )

      if let sessionActionErrorMessage {
        Text(sessionActionErrorMessage)
          .font(.footnote)
          .foregroundStyle(.red)
          .padding(.horizontal, 12)
          .padding(.top, 8)
      }

      List(items, id: \.id, selection: $selectedSessionID) { session in
        StudioListRow(
          title: session.id,
          subtitle: SessionsListRowState.subtitle(for: session, in: snapshot),
          scope: session.sourceScope
        )
        .tag(Optional(session.id))
      }
      .overlay {
        if items.isEmpty {
          emptyState
        }
      }
      .padding(.top, sessionActionErrorMessage == nil ? 0 : 8)
    }
  }

  private var actionItems: [StudioActionItem] {
    [
      StudioActionItem(
        id: "new-session",
        group: .primary,
        title: "New",
        systemImage: "plus",
        role: .primary,
        isEnabled: actionState.canCreate,
        action: onNewSession
      )
    ]
  }

  @ViewBuilder
  private var emptyState: some View {
    if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      ContentUnavailableView(
        "No Sessions",
        systemImage: "clock.arrow.circlepath",
        description: Text("A session pairs a persona with a directive. Create one to resolve its contract.")
      )
    } else {
      ContentUnavailableView.search(text: searchText)
    }
  }
}
