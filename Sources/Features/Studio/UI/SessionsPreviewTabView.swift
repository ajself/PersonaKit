import AppKit
import SwiftUI

/// Session preview detail content.
struct SessionsPreviewTabView: View {
  let sessionPreview: String
  let sessionPreviewErrorMessage: String?
  let isLoadingSessionPreview: Bool

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
          ContentUnavailableView(
            "Preview Failed",
            systemImage: "exclamationmark.triangle",
            description: Text(sessionPreviewErrorMessage)
          )
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
