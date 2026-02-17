import SwiftUI

/// Session preview detail content.
struct SessionsPreviewTabView: View {
  let sessionPreview: String
  let sessionPreviewErrorMessage: String?
  let isLoadingSessionPreview: Bool

  var body: some View {
    Group {
      if isLoadingSessionPreview {
        VStack(alignment: .center, spacing: 10) {
          ProgressView()
          Text("Loading preview...")
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
      } else if let sessionPreviewErrorMessage {
        ContentUnavailableView(
          "Preview Failed",
          systemImage: "exclamationmark.triangle",
          description: Text(sessionPreviewErrorMessage)
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
      } else if sessionPreview.isEmpty {
        ContentUnavailableView(
          "No Preview",
          systemImage: "doc.plaintext",
          description: Text("Generate a preview for the selected session.")
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
      } else {
        ScrollView {
          Text(sessionPreview)
            .frame(maxWidth: .infinity, alignment: .leading)
            .font(.body.monospaced())
            .textSelection(.enabled)
            .padding(12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
          RoundedRectangle(cornerRadius: 8)
            .fill(.quaternary.opacity(0.2))
        )
      }
    }
    .padding()
  }
}
