import ContextCore
import ContextWorkspaceCore
import Foundation
import StudioFoundation

extension WorkspaceLibraryFeatureModel {
  /// Shows `item` in the detail pane and loads its source. Selecting a different item
  /// discards the previous draft; re-selecting the current item keeps it.
  func selectDetailItem(_ item: StudioLibraryDetailItem?) {
    guard item != detail.item else {
      return
    }

    detailSourceTask?.cancel()
    detailSourceTask = nil
    detailActionTask?.cancel()
    detailActionTask = nil
    detail.select(item)

    if item != nil {
      loadDetailSource()
    }
  }

  /// Re-reads the detail item after a workspace reload when its file may have changed.
  /// Unsaved edits survive; see ``StudioLibraryDetailState/applyLoadedSource(_:)``.
  func revalidateDetailAfterReload(changedFileURLs: Set<URL>?) {
    guard let item = detail.item,
      WorkspaceFileChangeRelevance.affectsFile(item.fileURL, changedFileURLs: changedFileURLs)
    else {
      return
    }

    // A save in flight re-reads the file itself once it finishes.
    guard !detail.isSaving else {
      return
    }

    loadDetailSource()
  }

  func updateDetailForm(_ update: (inout WorkspaceLibraryEntityFormState) -> Void) {
    detail.updateForm(update)
  }

  func revertDetailDraft() {
    detail.revertDraft()
  }

  func validateDetailDraft(workspaceURL: URL?) {
    guard let presentation = detailEditorPresentation(workspaceURL: workspaceURL) else {
      detail.setInlineError("Form editing is unavailable for this item.")
      return
    }

    let item = detail.item

    detail.beginValidating()
    detailActionTask?.cancel()
    detailActionTask = Task {
      let errorMessage = await validateLibraryEditorRawJSON(
        presentation.rawJSON,
        presentation: presentation
      )

      guard !Task.isCancelled, detail.item == item else {
        return
      }

      detail.finishValidating(errorMessage: errorMessage)
      detailActionTask = nil
    }
  }

  func saveDetailDraft(
    snapshot: WorkspaceSnapshot,
    workspaceURL: URL?,
    currentWorkspaceURLProvider: @MainActor @escaping () -> URL?,
    onWorkspaceMutation: @MainActor @escaping () -> Void
  ) {
    guard let presentation = detailEditorPresentation(workspaceURL: workspaceURL) else {
      detail.setInlineError("Form editing is unavailable for this item.")
      return
    }

    let item = detail.item

    // A read that started before the save would report pre-save text as a disk change.
    detailSourceTask?.cancel()
    detailSourceTask = nil
    detail.beginSaving()
    detailActionTask?.cancel()
    detailActionTask = Task {
      let errorMessage = await saveLibraryEditorRawJSON(
        presentation.rawJSON,
        presentation: presentation,
        snapshot: snapshot,
        currentWorkspaceURLProvider: currentWorkspaceURLProvider,
        onWorkspaceMutation: onWorkspaceMutation
      )

      guard !Task.isCancelled, detail.item == item else {
        return
      }

      detail.finishSaving(errorMessage: errorMessage)
      detailActionTask = nil
      // Pick up the normalized on-disk text the save produced.
      loadDetailSource()
    }
  }

  private func detailEditorPresentation(
    workspaceURL: URL?
  ) -> WorkspaceLibraryEditorPresentation? {
    guard let item = detail.item,
      item.formAdapter != nil,
      let entityType = item.entityType,
      detail.isDraftReady,
      let workspaceURL = workspaceURL?.standardizedFileURL
    else {
      return nil
    }

    return WorkspaceLibraryEditorPresentation(
      itemID: item.id,
      entityType: entityType,
      fileURL: item.fileURL,
      rawJSON: detail.draftRawJSON,
      workspaceURL: workspaceURL,
      isCreatingNewItem: false
    )
  }

  private func loadDetailSource() {
    guard let item = detail.item else {
      return
    }

    detailSourceTask?.cancel()
    detailSourceTask = Task {
      let outcome: WorkspaceLoadOutcome<String>

      do {
        let rawText = try await operationRunner.loadLibraryItemRawJSON(fileURL: item.fileURL)
        outcome = .loaded(StudioLibrarySourceFormatter.displayText(for: rawText))
      } catch {
        outcome = .failed(error.localizedDescription)
      }

      guard !Task.isCancelled, detail.item == item else {
        return
      }

      var updatedDetail = detail

      switch outcome {
      case .loaded(let sourceText):
        updatedDetail.applyLoadedSource(sourceText)
      case .failed(let message):
        updatedDetail.applyFailedSource(message: message)
      }

      // Skip no-op writes so an unchanged reload doesn't re-render the editor.
      if updatedDetail != detail {
        detail = updatedDetail
      }

      detailSourceTask = nil
    }
  }
}
