import ContextWorkspaceCore
import Foundation
import SwiftUI

/// Library detail pane with a lightweight rendered source preview.
struct StudioLibraryDetailView: View {
  let selection: SidebarItem
  let selectedItem: WorkspaceListItem?
  let previewState: StudioLibraryPreviewState?
  let snapshotRevision: Int

  @State private var previewText = ""
  @State private var previewErrorMessage: String?
  @State private var isLoadingPreview = false

  var body: some View {
    VStack(spacing: 0) {
      if selectedItem != nil,
        let previewState
      {
        detailHeader(previewState)

        Divider()

        previewContent(previewState)
      } else {
        emptyState
      }
    }
    .task(id: previewRequestID) {
      await loadPreview()
    }
  }

  private var emptyState: some View {
    ContentUnavailableView(
      "Select a \(selection.singularTitle)",
      systemImage: selection.systemImage,
      description: Text(emptyStateDescription)
    )
    .foregroundStyle(.secondary)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var emptyStateDescription: String {
    switch selection {
    case .essentials:
      return "Preview the selected markdown source before editing."
    default:
      return "Preview the selected source before editing or copying."
    }
  }

  private var previewRequestID: String {
    guard let selectedItem else {
      return "\(selection.title)::none::\(snapshotRevision)"
    }

    return [
      selection.title,
      selectedItem.fileURL.standardizedFileURL.path(),
      String(snapshotRevision),
    ].joined(separator: "::")
  }

  private func detailHeader(
    _ previewState: StudioLibraryPreviewState
  ) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .firstTextBaseline, spacing: 10) {
        Text(previewState.id)
          .font(.title3)
          .fontWeight(.semibold)
          .lineLimit(1)
          .truncationMode(.middle)
          .textSelection(.enabled)

        Spacer()

        scopeBadge(previewState.scope)
      }

      if previewState.displayName != previewState.id {
        Text(previewState.displayName)
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .lineLimit(2)
          .textSelection(.enabled)
      }

      Text(previewState.relativePath)
        .font(.caption.monospaced())
        .foregroundStyle(.tertiary)
        .lineLimit(1)
        .truncationMode(.middle)
        .textSelection(.enabled)
    }
    .padding(12)
    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
    .background(.quaternary.opacity(0.07))
  }

  @ViewBuilder
  private func previewContent(
    _ previewState: StudioLibraryPreviewState
  ) -> some View {
    if isLoadingPreview {
      stateContainer {
        VStack(alignment: .center, spacing: 10) {
          ProgressView()

          Text("Loading preview...")
            .foregroundStyle(.secondary)
        }
      }
    } else if let previewErrorMessage {
      stateContainer {
        ContentUnavailableView(
          "Preview Failed",
          systemImage: "exclamationmark.triangle",
          description: Text(previewErrorMessage)
        )
      }
    } else if previewText.isEmpty {
      stateContainer {
        ContentUnavailableView(
          "No Preview",
          systemImage: selection.systemImage,
          description: Text("No source content is available for \(previewState.id).")
        )
      }
    } else if selection == .essentials {
      markdownPreview
    } else {
      sourcePreview
    }
  }

  private var markdownPreview: some View {
    ScrollView {
      Text(renderedMarkdown)
        .font(.body)
        .textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(16)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(previewPanelBackground)
    .padding()
  }

  private var renderedMarkdown: AttributedString {
    (try? AttributedString(markdown: previewText)) ?? AttributedString(previewText)
  }

  private var sourcePreview: some View {
    ScrollView([.vertical, .horizontal]) {
      Text(previewText)
        .font(.system(.body, design: .monospaced))
        .textSelection(.enabled)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(previewPanelBackground)
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
      .padding()
  }

  private func scopeBadge(
    _ scope: String
  ) -> some View {
    Text(scope)
      .font(.caption2)
      .fontWeight(.semibold)
      .padding(.horizontal, 6)
      .padding(.vertical, 2)
      .background(
        Capsule()
          .fill(scope == "Project" ? .blue.opacity(0.16) : .secondary.opacity(0.16))
      )
  }

  @MainActor
  private func loadPreview() async {
    guard let selectedItem else {
      previewText = ""
      previewErrorMessage = nil
      isLoadingPreview = false
      return
    }

    isLoadingPreview = true
    previewErrorMessage = nil

    do {
      previewText = try Self.previewText(
        for: selectedItem.fileURL,
        selection: selection
      )
    } catch {
      previewText = ""
      previewErrorMessage = error.localizedDescription
    }

    isLoadingPreview = false
  }

  private static func previewText(
    for fileURL: URL,
    selection: SidebarItem
  ) throws -> String {
    let rawText = try String(
      contentsOf: fileURL.standardizedFileURL,
      encoding: .utf8
    )

    guard selection != .essentials else {
      return rawText
    }

    return prettyPrintedJSON(rawText) ?? rawText
  }

  private static func prettyPrintedJSON(
    _ rawText: String
  ) -> String? {
    guard let data = rawText.data(using: .utf8),
      let jsonObject = try? JSONSerialization.jsonObject(with: data),
      JSONSerialization.isValidJSONObject(jsonObject),
      let prettyData = try? JSONSerialization.data(
        withJSONObject: jsonObject,
        options: [
          .prettyPrinted,
          .sortedKeys,
        ]
      )
    else {
      return nil
    }

    return String(data: prettyData, encoding: .utf8)
  }
}
