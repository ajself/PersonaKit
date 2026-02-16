import ContextCore
import SwiftUI

/// Sessions list tab with CRUD actions and project/global scope labels.
struct SessionsListTabView: View {
  let items: [WorkspaceSessionListItem]
  let selectedSession: WorkspaceSessionListItem?
  @Binding var selectedSessionID: String?
  let sessionActionErrorMessage: String?
  let isLoadingSessionDraft: Bool
  let canDeleteSelectedSession: Bool
  let onNewSession: () -> Void
  let onEditSession: () -> Void
  let onDeleteSession: () -> Void
  let onRevealInFinder: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 8) {
        Button("New Session") {
          onNewSession()
        }

        Button("Edit Session") {
          onEditSession()
        }
        .disabled(selectedSession == nil || isLoadingSessionDraft)

        Button("Delete Session") {
          onDeleteSession()
        }
        .disabled(!canDeleteSelectedSession)

        Button("Reveal in Finder") {
          onRevealInFinder()
        }
        .disabled(selectedSession == nil)

        if isLoadingSessionDraft {
          ProgressView()
            .controlSize(.small)
        }

        Spacer()
      }

      if let sessionActionErrorMessage {
        Text(sessionActionErrorMessage)
          .font(.footnote)
          .foregroundStyle(.red)
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
