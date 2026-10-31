import ContextCore
import ContextWorkspaceCore
import Foundation
import StudioFoundation

/// Identity of the library item shown in the detail pane.
struct StudioLibraryDetailItem: Equatable, Sendable {
  let id: String
  let fileURL: URL
  let sourceScope: WorkspaceSourceScope
  let entityType: WorkspaceLibraryEntityType?

  init(
    item: WorkspaceListItem,
    entityType: WorkspaceLibraryEntityType?
  ) {
    self.id = item.id
    self.fileURL = item.fileURL.standardizedFileURL
    self.sourceScope = item.sourceScope
    self.entityType = entityType
  }

  /// Project items with a minimal form can be edited inline; everything else is read-only.
  var formAdapter: WorkspaceLibraryEntityFormAdapter? {
    guard sourceScope == .project,
      let entityType,
      entityType.supportsMinimalForm
    else {
      return nil
    }

    return WorkspaceLibraryEntityFormAdapter(entityType: entityType)
  }
}

/// On-disk source and inline-form draft for the selected library item.
///
/// Reloads keep unsaved edits: when the file changes on disk while the draft is dirty, the
/// draft stays and ``hasChangedOnDisk`` flags it instead.
struct StudioLibraryDetailState: Equatable, Sendable {
  private(set) var item: StudioLibraryDetailItem?
  private(set) var sourceText = ""
  private(set) var errorMessage: String?
  private(set) var isLoading = false
  private(set) var draftRawJSON = ""
  private(set) var isDraftReady = false
  private(set) var formState = WorkspaceLibraryEntityFormState.empty
  private(set) var formSyncErrorMessage: String?
  private(set) var inlineMessage: String?
  private(set) var inlineMessageIsError = false
  private(set) var isSaving = false
  private(set) var isValidating = false
  private(set) var hasChangedOnDisk = false

  var isDraftDirty: Bool {
    isDraftReady && draftRawJSON != sourceText
  }

  var isBusy: Bool {
    isSaving || isValidating
  }

  /// Switches to `item`, discarding the previous item's draft.
  mutating func select(_ item: StudioLibraryDetailItem?) {
    self = StudioLibraryDetailState()
    self.item = item
    isLoading = item != nil
  }

  /// Applies freshly read source text. A clean draft follows the new source; a dirty draft
  /// is kept and marked as changed on disk unless the new source already matches it.
  mutating func applyLoadedSource(_ text: String) {
    let hadUnsavedEdits = isDraftDirty

    isLoading = false
    errorMessage = nil

    guard text != sourceText || !isDraftReady else {
      return
    }

    sourceText = text

    if hadUnsavedEdits {
      hasChangedOnDisk = draftRawJSON != text
      return
    }

    hasChangedOnDisk = false
    resetDraftToSource()
  }

  mutating func applyFailedSource(message: String) {
    isLoading = false

    // A transient read failure must not drop unsaved edits.
    guard !isDraftDirty else {
      return
    }

    sourceText = ""
    errorMessage = message
    draftRawJSON = ""
    isDraftReady = false
    formState = .empty
    formSyncErrorMessage = nil
  }

  mutating func updateForm(_ update: (inout WorkspaceLibraryEntityFormState) -> Void) {
    guard isDraftReady,
      let formAdapter = item?.formAdapter
    else {
      return
    }

    update(&formState)

    do {
      draftRawJSON = try formAdapter.applyFormState(formState, to: draftRawJSON)
      formSyncErrorMessage = nil
      inlineMessage = nil
    } catch {
      formSyncErrorMessage = error.localizedDescription
    }
  }

  mutating func revertDraft() {
    hasChangedOnDisk = false
    inlineMessage = nil
    inlineMessageIsError = false
    resetDraftToSource()
  }

  mutating func beginValidating() {
    isValidating = true
    inlineMessage = nil
  }

  mutating func finishValidating(errorMessage: String?) {
    isValidating = false
    inlineMessage = errorMessage ?? "JSON is valid."
    inlineMessageIsError = errorMessage != nil
  }

  mutating func beginSaving() {
    isSaving = true
    inlineMessage = nil
  }

  /// On success the saved draft becomes the source until the next read replaces it with
  /// the normalized on-disk text.
  mutating func finishSaving(errorMessage: String?) {
    isSaving = false

    if let errorMessage {
      inlineMessage = errorMessage
      inlineMessageIsError = true
      return
    }

    sourceText = draftRawJSON
    hasChangedOnDisk = false
    inlineMessage = item.map { "Saved \($0.id)." }
    inlineMessageIsError = false
  }

  mutating func setInlineError(_ message: String) {
    inlineMessage = message
    inlineMessageIsError = true
  }

  private mutating func resetDraftToSource() {
    draftRawJSON = sourceText
    formSyncErrorMessage = nil

    guard let formAdapter = item?.formAdapter,
      !sourceText.isEmpty
    else {
      isDraftReady = false
      formState = .empty
      return
    }

    isDraftReady = true

    do {
      formState = try formAdapter.parseFormState(from: draftRawJSON)
    } catch {
      formSyncErrorMessage = error.localizedDescription
    }
  }
}

/// Formats library source files for the detail pane.
enum StudioLibrarySourceFormatter {
  /// Pretty-prints JSON with sorted keys, or returns the text unchanged when it isn't JSON.
  static func displayText(for rawText: String) -> String {
    guard let data = rawText.data(using: .utf8),
      let jsonObject = try? JSONSerialization.jsonObject(with: data),
      JSONSerialization.isValidJSONObject(jsonObject),
      let prettyData = try? JSONSerialization.data(
        withJSONObject: jsonObject,
        options: [
          .prettyPrinted,
          .sortedKeys,
        ]
      ),
      let prettyText = String(data: prettyData, encoding: .utf8)
    else {
      return rawText
    }

    return prettyText
  }
}
