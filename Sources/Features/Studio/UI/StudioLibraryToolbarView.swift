import ContextCore
import SwiftUI

/// Toolbar for library and essentials list actions.
struct StudioLibraryToolbarView: View {
  let selectedItem: WorkspaceListItem?
  let isEssentialsSelection: Bool
  let isLoadingLibraryEditor: Bool
  let canEditRawJSON: Bool
  let canEditMarkdown: Bool
  let canCopyToProject: Bool
  let onRevealInFinder: () -> Void
  let onEditMarkdown: () -> Void
  let onEditRawJSON: () -> Void
  let onCopyToProject: () -> Void

  var body: some View {
    HStack(spacing: 8) {
      Button("Reveal in Finder") {
        onRevealInFinder()
      }
      .disabled(selectedItem == nil)

      if isEssentialsSelection {
        Button("Edit Markdown") {
          onEditMarkdown()
        }
        .disabled(!canEditMarkdown)
      } else {
        Button("Edit Raw JSON") {
          onEditRawJSON()
        }
        .disabled(!canEditRawJSON)
      }

      Button("Copy to Project") {
        onCopyToProject()
      }
      .disabled(!canCopyToProject)

      if isLoadingLibraryEditor {
        ProgressView()
          .controlSize(.small)
      }

      Spacer()
    }
  }
}
