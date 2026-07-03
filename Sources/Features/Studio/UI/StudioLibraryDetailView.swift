import ContextCore
import ContextWorkspaceCore
import Foundation
import StudioFoundation
import SwiftUI

/// Library detail pane with a lightweight rendered source preview.
struct StudioLibraryDetailView: View {
  let selection: SidebarItem
  let selectedItem: WorkspaceListItem?
  let entityType: WorkspaceLibraryEntityType?
  let previewState: StudioLibraryPreviewState?
  let snapshotRevision: Int
  let workspaceURL: URL?
  @Binding var detailMode: StudioLibraryDetailMode
  let onRevealInFinder: (URL) -> Void
  let onEditInSheet: () -> Void
  let onCopyToProject: () -> Void
  let onSaveMarkdown: @Sendable (String, WorkspaceEssentialEditorPresentation) async -> String?
  let onValidate: @Sendable (String, WorkspaceLibraryEditorPresentation) async -> String?
  let onSave: @Sendable (String, WorkspaceLibraryEditorPresentation) async -> String?
  let onSaveSucceeded: (String) -> Void

  @State private var previewText = ""
  @State private var draftRawJSON = ""
  @State private var draftPreviewRequestID: String?
  @State private var previewErrorMessage: String?
  @State private var isLoadingPreview = false
  @State private var formState = WorkspaceLibraryEntityFormState.empty
  @State private var formSyncErrorMessage: String?
  @State private var inlineMessage: String?
  @State private var inlineMessageIsError = false
  @State private var isSavingInlineForm = false
  @State private var isValidatingInlineForm = false

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
    .onAppear {
      beginInlineEditIfPossible()
    }
    .onChange(of: previewRequestID) { _, _ in
      resetInlineFormState()
    }
    .onChange(of: previewText) { _, _ in
      beginInlineEditIfPossible()
    }
    .onChange(of: detailMode) { _, _ in
      guard effectiveDetailMode == .edit else {
        return
      }

      beginInlineEditIfPossible()
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
      detailHeaderTitleRow(previewState)

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
        isEnabled: !isSavingInlineForm && !isValidatingInlineForm,
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
    case .markdown:
      guard selection != .essentials else {
        return nil
      }

      return StudioUtilityActionItem(
        id: "library-detail-edit-markdown",
        title: "Edit",
        systemImage: "pencil",
        isEnabled: !isSavingInlineForm && !isValidatingInlineForm,
        action: onEditInSheet
      )
    case .rawJSON:
      return StudioUtilityActionItem(
        id: "library-detail-edit-json",
        title: "Edit JSON",
        systemImage: "curlybraces",
        isEnabled: !isSavingInlineForm && !isValidatingInlineForm,
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
        isEnabled: !isSavingInlineForm && !isValidatingInlineForm,
        action: {
          onRevealInFinder(selectedItem.fileURL)
        }
      )
    ]
  }

  private var detailEditAction: StudioLibraryEditAction? {
    switch selection {
    case .essentials:
      return .markdown
    case .personas,
      .directives,
      .kits,
      .references,
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
    case .essentials:
      return true
    case .personas,
      .directives,
      .kits,
      .references,
      .skills:
      return entityType != nil
    default:
      return false
    }
  }

  private var unsavedBadge: some View {
    Text("Unsaved")
      .font(.caption2)
      .fontWeight(.semibold)
      .padding(.horizontal, 7)
      .padding(.vertical, 3)
      .background(
        Capsule()
          .fill(.orange.opacity(0.16))
      )
      .foregroundStyle(.orange)
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
        scopeBadge(previewState.scope)
      }

      VStack(alignment: .leading, spacing: 8) {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
          detailTitle(previewState)

          Spacer(minLength: 8)

          scopeBadge(previewState.scope)
        }

        detailModePicker
        detailActionControls
      }
    }
  }

  private func detailTitle(
    _ previewState: StudioLibraryPreviewState
  ) -> some View {
    Text(previewState.id)
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
          Text(mode.title(for: selection))
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
    } else if effectiveDetailMode == .edit,
      inlineFormDraftIsReady
    {
      if selection == .essentials {
        inlineMarkdownPreview
      } else {
        inlineFormPreview
      }
    } else if effectiveDetailMode == .edit {
      stateContainer {
        VStack(alignment: .center, spacing: 10) {
          ProgressView()

          Text("Preparing editor...")
            .foregroundStyle(.secondary)
        }
      }
    } else if selection == .essentials {
      markdownPreview
    } else {
      sourcePreview
    }
  }

  private var markdownPreview: some View {
    GeometryReader { proxy in
      ScrollView {
        Text(renderedMarkdown)
          .font(.body)
          .textSelection(.enabled)
          .padding(16)
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

  private var inlineMarkdownPreview: some View {
    VStack(spacing: 0) {
      TextEditor(text: inlineMarkdownBinding)
        .font(.body.monospaced())
        .scrollContentBackground(.hidden)
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(previewPanelBackground)
        .padding()

      Divider()

      inlineMarkdownFooter
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }

  private var renderedMarkdown: AttributedString {
    (try? AttributedString(markdown: previewText)) ?? AttributedString(previewText)
  }

  private var sourcePreview: some View {
    GeometryReader { proxy in
      ScrollView([.vertical, .horizontal]) {
        Text(previewText)
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
    if let formDescriptor,
      inlineEditorPresentation != nil
    {
      VStack(spacing: 0) {
        ScrollView {
          RawJSONEditorMinimalFormView(
            formDescriptor: formDescriptor,
            formSyncErrorMessage: formSyncErrorMessage,
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

  private var formAdapter: WorkspaceLibraryEntityFormAdapter? {
    guard let entityType,
      entityType.supportsMinimalForm
    else {
      return nil
    }

    return WorkspaceLibraryEntityFormAdapter(entityType: entityType)
  }

  private var formDescriptor: WorkspaceLibraryEntityFormDescriptor? {
    formAdapter?.descriptor
  }

  private var inlineEditorPresentation: WorkspaceLibraryEditorPresentation? {
    guard
      let selectedItem,
      selectedItem.sourceScope == .project,
      let entityType,
      entityType.supportsMinimalForm,
      let workspaceURL = workspaceURL?.standardizedFileURL
    else {
      return nil
    }

    return WorkspaceLibraryEditorPresentation(
      itemID: selectedItem.id,
      entityType: entityType,
      fileURL: selectedItem.fileURL.standardizedFileURL,
      rawJSON: draftRawJSON,
      workspaceURL: workspaceURL,
      isCreatingNewItem: false
    )
  }

  private var inlineMarkdownEditorPresentation: WorkspaceEssentialEditorPresentation? {
    guard
      let selectedItem,
      selectedItem.sourceScope == .project,
      selection == .essentials,
      let workspaceURL = workspaceURL?.standardizedFileURL
    else {
      return nil
    }

    return WorkspaceEssentialEditorPresentation(
      fileURL: selectedItem.fileURL.standardizedFileURL,
      itemID: selectedItem.id,
      markdown: draftRawJSON,
      workspaceURL: workspaceURL
    )
  }

  private var isInlineFormDirty: Bool {
    StudioLibraryInlineFormDraftStateResolver.isDirty(
      effectiveMode: effectiveDetailMode,
      draftPreviewRequestID: draftPreviewRequestID,
      previewRequestID: previewRequestID,
      draftRawJSON: draftRawJSON,
      previewText: previewText
    )
  }

  private var inlineFormDraftIsReady: Bool {
    StudioLibraryInlineFormDraftStateResolver.isReady(
      draftPreviewRequestID: draftPreviewRequestID,
      previewRequestID: previewRequestID
    )
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

  private var inlineMarkdownFooter: some View {
    ViewThatFits(in: .horizontal) {
      HStack(spacing: 12) {
        inlineFooterMessage

        Spacer(minLength: 12)

        inlineMarkdownFooterButtons
      }

      VStack(alignment: .leading, spacing: 8) {
        inlineFooterMessage
        inlineMarkdownFooterButtons
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 10)
    .background(.quaternary.opacity(0.08))
  }

  @ViewBuilder
  private var inlineFooterMessage: some View {
    if let inlineMessage {
      Text(inlineMessage)
        .font(.footnote)
        .foregroundStyle(inlineMessageIsError ? .red : .secondary)
        .lineLimit(2)
    }
  }

  private var inlineFooterButtons: some View {
    HStack(spacing: 8) {
      Button("Cancel", role: .cancel) {
        cancelInlineForm()
      }
      .disabled(isSavingInlineForm || isValidatingInlineForm)

      Button(isValidatingInlineForm ? "Validating..." : "Validate") {
        validateInlineForm()
      }
      .disabled(isSavingInlineForm || isValidatingInlineForm || formSyncErrorMessage != nil)

      Button(isSavingInlineForm ? "Saving..." : "Save") {
        saveInlineForm()
      }
      .disabled(
        isSavingInlineForm
          || isValidatingInlineForm
          || formSyncErrorMessage != nil
          || !isInlineFormDirty
      )
    }
    .controlSize(.small)
  }

  private var inlineMarkdownFooterButtons: some View {
    HStack(spacing: 8) {
      Button("Cancel", role: .cancel) {
        cancelInlineForm()
      }
      .disabled(isSavingInlineForm)

      Button(isSavingInlineForm ? "Saving..." : "Save") {
        saveInlineMarkdown()
      }
      .disabled(isSavingInlineForm || !isInlineFormDirty)
    }
    .controlSize(.small)
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
      draftRawJSON = ""
      draftPreviewRequestID = nil
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

    if effectiveDetailMode == .edit {
      beginInlineEditIfPossible()
    }
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

  private var inlineMarkdownBinding: Binding<String> {
    Binding(
      get: { draftRawJSON },
      set: { updatedMarkdown in
        draftRawJSON = updatedMarkdown
        inlineMessage = nil
      }
    )
  }

  private var idBinding: Binding<String> {
    Binding(
      get: { formState.id },
      set: { updatedID in
        formState.id = updatedID
        syncDraftFromFormState()
      }
    )
  }

  private var primaryTextBinding: Binding<String> {
    Binding(
      get: { formState.primaryText },
      set: { updatedText in
        formState.primaryText = updatedText
        syncDraftFromFormState()
      }
    )
  }

  private var secondaryTextBinding: Binding<String> {
    Binding(
      get: { formState.secondaryText },
      set: { updatedText in
        formState.secondaryText = updatedText
        syncDraftFromFormState()
      }
    )
  }

  private var firstArrayLinesBinding: Binding<String> {
    Binding(
      get: { formState.firstArrayLines },
      set: { updatedText in
        formState.firstArrayLines = updatedText
        syncDraftFromFormState()
      }
    )
  }

  private var secondArrayLinesBinding: Binding<String> {
    Binding(
      get: { formState.secondArrayLines },
      set: { updatedText in
        formState.secondArrayLines = updatedText
        syncDraftFromFormState()
      }
    )
  }

  private func resetInlineFormState() {
    formState = .empty
    draftRawJSON = ""
    draftPreviewRequestID = nil
    formSyncErrorMessage = nil
    inlineMessage = nil
    inlineMessageIsError = false
    isSavingInlineForm = false
    isValidatingInlineForm = false
  }

  private func beginInlineEditIfPossible() {
    guard effectiveDetailMode == .edit,
      !previewText.isEmpty,
      draftPreviewRequestID != previewRequestID
    else {
      return
    }

    draftRawJSON = previewText
    draftPreviewRequestID = previewRequestID
    syncFormStateFromDraft()
  }

  private func syncFormStateFromDraft() {
    guard let formAdapter else {
      return
    }

    do {
      formState = try formAdapter.parseFormState(from: draftRawJSON)
      formSyncErrorMessage = nil
    } catch {
      formSyncErrorMessage = error.localizedDescription
    }
  }

  private func syncDraftFromFormState() {
    guard let formAdapter else {
      return
    }

    do {
      draftRawJSON = try formAdapter.applyFormState(
        formState,
        to: draftRawJSON
      )
      formSyncErrorMessage = nil
      inlineMessage = nil
    } catch {
      formSyncErrorMessage = error.localizedDescription
    }
  }

  private func validateInlineForm() {
    guard let presentation = inlineEditorPresentation else {
      inlineMessage = "Form editing is unavailable for this item."
      inlineMessageIsError = true
      return
    }

    isValidatingInlineForm = true
    inlineMessage = nil

    Task {
      let validationError = await onValidate(draftRawJSON, presentation)

      await MainActor.run {
        isValidatingInlineForm = false

        if let validationError {
          inlineMessage = validationError
          inlineMessageIsError = true
        } else {
          inlineMessage = "JSON is valid."
          inlineMessageIsError = false
        }
      }
    }
  }

  private func cancelInlineForm() {
    draftRawJSON = previewText
    draftPreviewRequestID = previewRequestID
    inlineMessage = nil
    inlineMessageIsError = false
    syncFormStateFromDraft()
  }

  private func saveInlineForm() {
    guard let presentation = inlineEditorPresentation else {
      inlineMessage = "Form editing is unavailable for this item."
      inlineMessageIsError = true
      return
    }

    isSavingInlineForm = true
    inlineMessage = nil

    Task {
      let saveError = await onSave(draftRawJSON, presentation)

      await MainActor.run {
        isSavingInlineForm = false

        if let saveError {
          inlineMessage = saveError
          inlineMessageIsError = true
        } else {
          previewText = draftRawJSON
          inlineMessage = "Saved \(presentation.itemID)."
          inlineMessageIsError = false
          onSaveSucceeded(presentation.itemID)
        }
      }
    }
  }

  private func saveInlineMarkdown() {
    guard let presentation = inlineMarkdownEditorPresentation else {
      inlineMessage = "Markdown editing is unavailable for this item."
      inlineMessageIsError = true
      return
    }

    isSavingInlineForm = true
    inlineMessage = nil

    Task {
      let saveError = await onSaveMarkdown(draftRawJSON, presentation)

      await MainActor.run {
        isSavingInlineForm = false

        if let saveError {
          inlineMessage = saveError
          inlineMessageIsError = true
        } else {
          previewText = draftRawJSON
          inlineMessage = "Saved \(presentation.itemID)."
          inlineMessageIsError = false
          onSaveSucceeded(presentation.itemID)
        }
      }
    }
  }
}
