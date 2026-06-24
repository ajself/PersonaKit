import AppKit
import SwiftUI

/// Session preview detail content.
struct SessionsPreviewTabView: View {
  let sessionPreview: String
  let sessionPreviewErrorMessage: String?
  let isLoadingSessionPreview: Bool
  let isGlobalLibraryConnected: Bool
  let onConnectGlobalLibrary: () -> Void

  var body: some View {
    Group {
      if isLoadingSessionPreview {
        stateContainer {
          VStack(alignment: .center, spacing: 10) {
            ProgressView()

            Text("Loading preview...")
              .foregroundStyle(.secondary)
          }
        }
      } else if let sessionPreviewErrorMessage {
        stateContainer {
          // A disconnected shared library is the overwhelmingly common cause of a preview
          // failure, so offer the fix right here instead of making the user discover the
          // Connect action buried in Validation Results. If connecting does not resolve it,
          // the refreshed preview falls through to the raw error below.
          if !isGlobalLibraryConnected {
            ContentUnavailableView {
              Label("Shared Library Not Connected", systemImage: "link.badge.plus")
            } description: {
              Text(
                "This session uses personas, directives, or kits from your shared library (~/.personakit). Connect it to preview them."
              )
            } actions: {
              Button("Connect Shared Library…", action: onConnectGlobalLibrary)
                .buttonStyle(.borderedProminent)
            }
          } else {
            ContentUnavailableView(
              "Preview Failed",
              systemImage: "exclamationmark.triangle",
              description: Text(sessionPreviewErrorMessage)
            )
          }
        }
      } else if sessionPreview.isEmpty {
        stateContainer {
          ContentUnavailableView(
            "No Preview",
            systemImage: "doc.plaintext",
            description: Text("Generate a preview for the selected session.")
          )
        }
      } else {
        StudioMultilineTextInput(
          text: .constant(sessionPreview),
          font: .monospacedSystemFont(
            ofSize: NSFont.systemFontSize,
            weight: .regular
          ),
          textColor: .labelColor,
          isEditable: false,
          horizontalInset: 12,
          verticalInset: 12
        )
        .frame(minWidth: 0, maxWidth: .infinity, maxHeight: .infinity)
        .frame(minWidth: 0, maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(previewPanelBackground)
      }
    }
    .frame(minWidth: 0, maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .padding()
  }

  private var previewPanelBackground: some View {
    RoundedRectangle(cornerRadius: 8)
      .fill(.quaternary.opacity(0.2))
  }

  private func stateContainer<Content: View>(
    @ViewBuilder content: () -> Content
  ) -> some View {
    content()
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
      .background(previewPanelBackground)
  }
}
