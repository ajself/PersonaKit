import ContextCore
import ContextWorkspaceCore
import SwiftUI

/// Sessions list panel with CRUD actions and project/global scope labels.
struct SessionsListTabView: View {
  let items: [WorkspaceSessionListItem]
  @Binding var selectedSessionID: String?
  let sessionActionErrorMessage: String?
  let actionState: SessionsListActionState
  let helpTopic: StudioHelpTopic?
  @Binding var isHelpExpanded: Bool
  let onNewSession: () -> Void
  let onEditSession: () -> Void
  let onDeleteSession: () -> Void
  let onRevealInFinder: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      StudioActionBarView(
        actions: actionItems,
        isLoading: actionState.isLoadingDraft
      )

      if let helpTopic {
        VStack(alignment: .leading, spacing: 0) {
          StudioHelpHintChipView(
            hintText: helpTopic.shortHint,
            isExpanded: $isHelpExpanded
          )
          .padding(.horizontal, 10)
          .padding(.vertical, 10)

          if isHelpExpanded {
            Divider()
              .overlay(.white.opacity(0.08))
              .padding(.horizontal, 10)
              .padding(.bottom, 12)

            StudioHelpCardView(
              topic: helpTopic
            )
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
            .transition(.opacity)
          }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
          RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(.quaternary.opacity(0.1))
            .overlay(
              RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(.white.opacity(0.08), lineWidth: 0.8)
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .layoutPriority(1)
      }

      if let sessionActionErrorMessage {
        Text(sessionActionErrorMessage)
          .font(.footnote)
          .foregroundStyle(.red)
          .padding(.horizontal, 12)
          .padding(.top, 8)
      }

      List(items, id: \.id, selection: $selectedSessionID) { session in
        VStack(alignment: .leading, spacing: 6) {
          HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(session.id)
              .font(.headline)

            Spacer()

            scopeBadge(scope: session.sourceScope)
          }

          Text("persona: \(session.personaId) · directive: \(session.directiveId)")
            .font(.subheadline)
            .foregroundStyle(.secondary)

          Text(session.fileURL.path())
            .font(.caption.monospaced())
            .foregroundStyle(.tertiary)
            .textSelection(.enabled)
        }
        .padding(.vertical, 4)
        .tag(Optional(session.id))
      }
      .overlay {
        if items.isEmpty {
          ContentUnavailableView.search
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
      ),
      StudioActionItem(
        id: "edit-session",
        group: .selection,
        title: "Edit",
        systemImage: "pencil",
        role: .standard,
        isEnabled: actionState.canEdit,
        action: onEditSession
      ),
      StudioActionItem(
        id: "reveal-session",
        group: .selection,
        title: "Reveal",
        systemImage: "folder",
        role: .standard,
        isEnabled: actionState.canReveal,
        action: onRevealInFinder
      ),
      StudioActionItem(
        id: "delete-session",
        group: .destructive,
        title: "Delete",
        systemImage: "trash",
        role: .destructive,
        isEnabled: actionState.canDelete,
        action: onDeleteSession
      ),
    ]
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
