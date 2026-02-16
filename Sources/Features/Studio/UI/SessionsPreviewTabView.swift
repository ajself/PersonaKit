import ContextCore
import ContextWorkspaceCore
import SwiftUI

/// Session preview tab with refresh, copy, export, and reveal actions.
struct SessionsPreviewTabView: View {
  let selectedSession: WorkspaceSessionListItem?
  let sessionPreview: String
  let sessionPreviewErrorMessage: String?
  let sessionPreviewActionMessage: String?
  let isLoadingSessionPreview: Bool
  let onRefresh: () -> Void
  let onRevealInFinder: () -> Void
  let onCopy: () -> Void
  let onExport: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 8) {
        Text("Session Preview")
          .font(.title3)
          .fontWeight(.semibold)

        if let selectedSession {
          Text("· \(selectedSession.id)")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }

        Spacer()

        Button("Refresh") {
          onRefresh()
        }
        .disabled(selectedSession == nil || isLoadingSessionPreview)

        Button("Reveal in Finder") {
          onRevealInFinder()
        }
        .disabled(selectedSession == nil)

        Button("Copy") {
          onCopy()
        }
        .disabled(sessionPreview.isEmpty || isLoadingSessionPreview)

        Button("Export Markdown…") {
          onExport()
        }
        .disabled(sessionPreview.isEmpty || isLoadingSessionPreview)
      }

      if let sessionPreviewActionMessage {
        Text(sessionPreviewActionMessage)
          .font(.footnote)
          .foregroundStyle(.secondary)
      }

      if selectedSession == nil {
        ContentUnavailableView(
          "No Session Selected",
          systemImage: "doc.text.magnifyingglass",
          description: Text("Select a session to generate a preview.")
        )
      } else if isLoadingSessionPreview {
        VStack(alignment: .center, spacing: 10) {
          ProgressView()
          Text("Loading preview...")
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else if let sessionPreviewErrorMessage {
        ContentUnavailableView(
          "Preview Failed",
          systemImage: "exclamationmark.triangle",
          description: Text(sessionPreviewErrorMessage)
        )
      } else if sessionPreview.isEmpty {
        ContentUnavailableView(
          "No Preview",
          systemImage: "doc.plaintext",
          description: Text("Generate a preview for the selected session.")
        )
      } else {
        ScrollView {
          Text(sessionPreview)
            .frame(maxWidth: .infinity, alignment: .leading)
            .font(.body.monospaced())
            .textSelection(.enabled)
            .padding(12)
        }
        .background(
          RoundedRectangle(cornerRadius: 8)
            .fill(.quaternary.opacity(0.2))
        )
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .padding()
  }
}
