import ContextCore
import ContextWorkspaceCore
import Foundation
import StudioFoundation
import SwiftUI

/// Library detail pane with a lightweight rendered source preview.
///
/// The source text and inline draft live in `WorkspaceLibraryFeatureModel`; this view renders
/// them and forwards edits.
struct StudioLibraryDetailView: View {
  let workspaceStore: WorkspaceStore
  let selection: SidebarItem
  let selectedItem: WorkspaceListItem?
  let entityType: WorkspaceLibraryEntityType?
  let previewState: StudioLibraryPreviewState?
  @Binding var detailMode: StudioLibraryDetailMode
  let onEditInSheet: () -> Void
  let onCopyToProject: () -> Void

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
    "Choose one from the list to read or edit it."
  }

  private var detail: StudioLibraryDetailState {
    workspaceStore.libraryDetail
  }

  /// The owner switches items one update after the selection does; until then the
  /// previous item's detail must not render under the new header.
  private var isShowingSelectedItem: Bool {
    detail.item?.fileURL == selectedItem?.fileURL.standardizedFileURL
  }

  private func detailHeader(
    _ previewState: StudioLibraryPreviewState
  ) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      detailHeaderTitleRow(previewState)

      if previewState.displayName != previewState.id {
        Text(previewState.id)
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .lineLimit(1)
          .textSelection(.enabled)
      }

      if let workstreamLine = previewState.workstreamLine {
        Text(workstreamLine)
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .lineLimit(1)
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

  private var detailActionControls: some View {
    HStack(spacing: 8) {
      StudioUtilityActionRowView(
        primaryAction: primaryDetailAction,
        secondaryActions: secondaryDetailActions,
        visibleSecondaryActionCount: 2
      )

      if isInlineFormDirty {
        unsavedBadge
      }

      if isInlineFormDirty, detail.hasChangedOnDisk {
        changedOnDiskBadge
      }
    }
  }

  private var primaryDetailAction: StudioUtilityActionItem? {
    guard let selectedItem else {
      return nil
    }

    if selectedItem.sourceScope == .global,
      canCopySelectedItemToProject
    {
      return StudioUtilityActionItem(
        id: "library-detail-copy",
        title: "Copy to Project",
        systemImage: "arrow.down.doc",
        isEnabled: !detail.isBusy,
        action: onCopyToProject
      )
    }

    guard selectedItem.sourceScope == .project else {
      return nil
    }

    switch detailEditAction {
    case .inlineForm,
      nil:
      return nil
    case .rawJSON:
      return StudioUtilityActionItem(
        id: "library-detail-edit-json",
        title: "Edit JSON",
        systemImage: "curlybraces",
        isEnabled: !detail.isBusy,
        action: onEditInSheet
      )
    }
  }

  private var secondaryDetailActions: [StudioUtilityActionItem] {
    guard let selectedItem else {
      return []
    }

    return [
      StudioUtilityActionItem(
        id: "library-detail-reveal",
        title: "Reveal",
        systemImage: "folder",
        isEnabled: !detail.isBusy,
        action: {
          workspaceStore.revealInFinder(fileURL: selectedItem.fileURL)
        }
      )
    ]
  }

  private var detailEditAction: StudioLibraryEditAction? {
    switch selection {
    case .personas,
      .directives,
      .kits,
      .skills:
      guard selectedItem?.sourceScope == .project,
        entityType?.supportsMinimalForm == true
      else {
        return .rawJSON
      }

      return .inlineForm
    default:
      return nil
    }
  }

  private var canCopySelectedItemToProject: Bool {
    switch selection {
    case .personas,
      .directives,
      .kits,
      .skills:
      return entityType != nil
    default:
      return false
    }
  }

  private var unsavedBadge: some View {
    StudioBadge(title: "Unsaved", tone: .warning)
  }

  private var changedOnDiskBadge: some View {
    StudioBadge(title: "Changed on Disk", tone: .warning)
      .help("This file changed on disk. Your edits are kept: Save overwrites the file, Cancel loads the new version.")
  }

  private func detailHeaderTitleRow(
    _ previewState: StudioLibraryPreviewState
  ) -> some View {
    ViewThatFits(in: .horizontal) {
      HStack(alignment: .firstTextBaseline, spacing: 10) {
        detailTitle(previewState)

        Spacer(minLength: 12)

        detailModePicker
        detailActionControls
        StudioScopeBadge(scope: previewState.sourceScope)
      }

      VStack(alignment: .leading, spacing: 8) {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
          detailTitle(previewState)

          Spacer(minLength: 8)

          StudioScopeBadge(scope: previewState.sourceScope)
        }

        detailModePicker
        detailActionControls
      }
    }
  }

  private func detailTitle(
    _ previewState: StudioLibraryPreviewState
  ) -> some View {
    Text(previewState.displayName)
      .font(.title3)
      .fontWeight(.semibold)
      .lineLimit(1)
      .truncationMode(.middle)
      .textSelection(.enabled)
  }

  @ViewBuilder
  private var detailModePicker: some View {
    if availableDetailModes.count > 1 {
      Picker("Detail Mode", selection: $detailMode) {
        ForEach(availableDetailModes, id: \.self) { mode in
          Text(mode.title)
            .tag(mode)
        }
      }
      .pickerStyle(.segmented)
      .controlSize(.small)
      .labelsHidden()
      .accessibilityLabel("Detail Mode")
      .frame(width: 150)
    }
  }

  @ViewBuilder
  private func previewContent(
    _ previewState: StudioLibraryPreviewState
  ) -> some View {
    if detail.isLoading || !isShowingSelectedItem {
      stateContainer {
        VStack(alignment: .center, spacing: 10) {
          ProgressView()

          Text("Loading preview…")
            .foregroundStyle(.secondary)
        }
      }
    } else if let previewErrorMessage = detail.errorMessage {
      stateContainer {
        ContentUnavailableView(
          "Preview Failed",
          systemImage: "exclamationmark.triangle",
          description: Text(previewErrorMessage)
        )
      }
    } else if detail.sourceText.isEmpty {
      stateContainer {
        ContentUnavailableView(
          "No Preview",
          systemImage: selection.systemImage,
          description: Text("No source content is available for \(previewState.id).")
        )
      }
    } else if effectiveDetailMode == .edit,
      detail.isDraftReady
    {
      inlineFormPreview
    } else if effectiveDetailMode == .edit {
      stateContainer {
        VStack(alignment: .center, spacing: 10) {
          ProgressView()

          Text("Preparing editor…")
            .foregroundStyle(.secondary)
        }
      }
    } else {
      sourcePreview
    }
  }

  private var sourcePreview: some View {
    GeometryReader { proxy in
      ScrollView([.vertical, .horizontal]) {
        Text(detail.sourceText)
          .font(.system(.body, design: .monospaced))
          .textSelection(.enabled)
          .padding(12)
          .frame(
            minWidth: proxy.size.width,
            minHeight: proxy.size.height,
            alignment: .topLeading
          )
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(previewPanelBackground)
    .padding()
  }

  @ViewBuilder
  private var inlineFormPreview: some View {
    if let formDescriptor {
      VStack(spacing: 0) {
        ScrollView {
          RawJSONEditorMinimalFormView(
            formDescriptor: formDescriptor,
            formSyncErrorMessage: detail.formSyncErrorMessage,
            idBinding: idBinding,
            primaryTextBinding: primaryTextBinding,
            secondaryTextBinding: secondaryTextBinding,
            firstArrayLinesBinding: firstArrayLinesBinding,
            secondArrayLinesBinding: secondArrayLinesBinding
          )
          .padding()
          .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

        Divider()

        inlineFormFooter
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    } else {
      stateContainer {
        ContentUnavailableView(
          "Form Unavailable",
          systemImage: "square.and.pencil",
          description: Text("This item can only be previewed as JSON.")
        )
      }
    }
  }

  private var availableDetailModes: [StudioLibraryDetailMode] {
    StudioLibraryDetailModeResolver.availableModes(
      selection: selection,
      selectedItem: selectedItem,
      entityType: entityType
    )
  }

  private var effectiveDetailMode: StudioLibraryDetailMode {
    StudioLibraryDetailModeResolver.effectiveMode(
      preferredMode: detailMode,
      selection: selection,
      selectedItem: selectedItem,
      entityType: entityType
    )
  }

  private var formDescriptor: WorkspaceLibraryEntityFormDescriptor? {
    detail.item?.formAdapter?.descriptor
  }

  private var isInlineFormDirty: Bool {
    effectiveDetailMode == .edit && detail.isDraftDirty
  }

  private var inlineFormFooter: some View {
    ViewThatFits(in: .horizontal) {
      HStack(spacing: 12) {
        inlineFooterMessage

        Spacer(minLength: 12)

        inlineFooterButtons
      }

      VStack(alignment: .leading, spacing: 8) {
        inlineFooterMessage
        inlineFooterButtons
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 10)
    .background(.quaternary.opacity(0.08))
  }

  @ViewBuilder
  private var inlineFooterMessage: some View {
    if let inlineMessage = detail.inlineMessage {
      Text(inlineMessage)
        .font(.footnote)
        .foregroundStyle(detail.inlineMessageIsError ? .red : .secondary)
        .lineLimit(2)
    }
  }

  private var inlineFooterButtons: some View {
    HStack(spacing: 8) {
      Button("Cancel", role: .cancel) {
        workspaceStore.revertLibraryDetailDraft()
      }
      .disabled(detail.isBusy)

      Button(detail.isValidating ? "Validating…" : "Validate") {
        workspaceStore.validateLibraryDetailDraft()
      }
      .disabled(detail.isBusy || detail.formSyncErrorMessage != nil)

      Button(detail.isSaving ? "Saving…" : "Save") {
        workspaceStore.saveLibraryDetailDraft()
      }
      .disabled(
        detail.isBusy
          || detail.formSyncErrorMessage != nil
          || !isInlineFormDirty
      )
    }
    .controlSize(.small)
  }

  private var previewPanelBackground: some View {
    RoundedRectangle(cornerRadius: StudioDesign.Radius.card)
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

  private var idBinding: Binding<String> {
    formBinding(\.id)
  }

  private var primaryTextBinding: Binding<String> {
    formBinding(\.primaryText)
  }

  private var secondaryTextBinding: Binding<String> {
    formBinding(\.secondaryText)
  }

  private var firstArrayLinesBinding: Binding<String> {
    formBinding(\.firstArrayLines)
  }

  private var secondArrayLinesBinding: Binding<String> {
    formBinding(\.secondArrayLines)
  }

  private func formBinding(
    _ keyPath: WritableKeyPath<WorkspaceLibraryEntityFormState, String>
  ) -> Binding<String> {
    Binding(
      get: { detail.formState[keyPath: keyPath] },
      set: { updatedText in
        workspaceStore.updateLibraryDetailForm { formState in
          formState[keyPath: keyPath] = updatedText
        }
      }
    )
  }
}
