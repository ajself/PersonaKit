import ContextCore
import ContextWorkspaceCore
import SwiftUI

/// Library and essentials panel with edit/copy/reveal workflows.
struct StudioLibraryPanelView: View {
  let workspaceStore: WorkspaceStore
  let selection: SidebarItem
  let items: [WorkspaceListItem]
  @Binding var searchText: String
  @Binding var selectedLibraryItemID: String?

  @State private var markdownEditorPresentation: WorkspaceEssentialEditorPresentation?
  @State private var rawJSONEditorPresentation: WorkspaceLibraryEditorPresentation?

  var body: some View {
    let visibleItems = filteredItems(items)
    let selectedItem = selectedLibraryItem(items: visibleItems)
    let entityType = editableEntityTypeForSelection()
    let actionState = StudioLibraryActionBarState(
      selection: selection,
      selectedItem: selectedItem,
      isLoadingLibraryEditor: workspaceStore.isLoadingLibraryEditor
    )

    VStack(alignment: .leading, spacing: 10) {
      StudioLibraryToolbarView(
        actionState: actionState,
        onRevealInFinder: {
          guard let selectedItem else {
            return
          }

          workspaceStore.revealInFinder(fileURL: selectedItem.fileURL)
        },
        onEdit: {
          switch actionState.editAction {
          case .markdown:
            openMarkdownEditorForSelectedItem(selectedItem: selectedItem)
          case .rawJSON:
            openRawJSONEditorForSelectedItem(
              selectedItem: selectedItem,
              entityType: entityType
            )
          case nil:
            break
          }
        },
        onCopyToProject: {
          switch actionState.editAction {
          case .markdown:
            copySelectedGlobalEssentialToProject(
              selectedItem: selectedItem
            )
          case .rawJSON:
            copySelectedGlobalItemToProject(
              selectedItem: selectedItem,
              entityType: entityType
            )
          case nil:
            break
          }
        }
      )

      if let libraryActionMessage = workspaceStore.libraryActionMessage {
        Text(libraryActionMessage)
          .font(.footnote)
          .foregroundStyle(workspaceStore.libraryActionIsError ? .red : .secondary)
      }

      StudioLibraryItemListView(
        visibleItems: visibleItems,
        selectedLibraryItemID: $selectedLibraryItemID
      )
    }
    .searchable(text: $searchText, prompt: "Search \(selection.title)")
    .sheet(item: $markdownEditorPresentation) { presentation in
      MarkdownEditorView(
        title: "Edit \(presentation.itemID)",
        initialMarkdown: presentation.markdown,
        onCancel: {
          markdownEditorPresentation = nil
        },
        onRevealInFinder: {
          workspaceStore.revealInFinder(fileURL: presentation.fileURL)
        },
        onSave: { markdown in
          let saveError = await workspaceStore.saveEssentialEditorMarkdown(
            markdown,
            presentation: presentation
          )

          if saveError == nil {
            await MainActor.run {
              selectedLibraryItemID = presentation.itemID
            }
          }

          return saveError
        }
      )
    }
    .sheet(item: $rawJSONEditorPresentation) { presentation in
      RawJSONEditorView(
        title: "Edit \(presentation.itemID)",
        entityType: presentation.entityType,
        initialRawJSON: presentation.rawJSON,
        onCancel: {
          rawJSONEditorPresentation = nil
        },
        onRevealInFinder: {
          workspaceStore.revealInFinder(fileURL: presentation.fileURL)
        },
        onValidate: { rawJSON in
          await workspaceStore.validateLibraryEditorRawJSON(
            rawJSON,
            presentation: presentation
          )
        },
        onSave: { rawJSON in
          let saveError = await workspaceStore.saveLibraryEditorRawJSON(
            rawJSON,
            presentation: presentation
          )

          if saveError == nil {
            await MainActor.run {
              selectedLibraryItemID = presentation.itemID
            }
          }

          return saveError
        }
      )
    }
    .onChange(of: workspaceStore.workspaceURL) { _, _ in
      markdownEditorPresentation = nil
      rawJSONEditorPresentation = nil
    }
  }

  private func filteredItems(_ items: [WorkspaceListItem]) -> [WorkspaceListItem] {
    let normalizedSearch = normalizedSearchText

    guard !normalizedSearch.isEmpty else {
      return items
    }

    return items.filter { item in
      item.id.localizedCaseInsensitiveContains(normalizedSearch)
        || item.displayName.localizedCaseInsensitiveContains(normalizedSearch)
        || item.fileURL.path().localizedCaseInsensitiveContains(normalizedSearch)
    }
  }

  private var normalizedSearchText: String {
    searchText.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private func editableEntityTypeForSelection() -> WorkspaceLibraryEntityType? {
    switch selection {
    case .personas:
      return .persona
    case .directives:
      return .directive
    case .kits:
      return .kit
    case .skills:
      return .skill
    case .intents:
      return .intent
    default:
      return nil
    }
  }

  private func selectedLibraryItem(
    items: [WorkspaceListItem]
  ) -> WorkspaceListItem? {
    guard let selectedLibraryItemID else {
      return nil
    }

    return items.first { $0.id == selectedLibraryItemID }
  }

  private func openRawJSONEditorForSelectedItem(
    selectedItem: WorkspaceListItem?,
    entityType: WorkspaceLibraryEntityType?
  ) {
    Task {
      let presentation = await workspaceStore.openLibraryEditor(
        selectedItem: selectedItem,
        entityType: entityType
      )

      await MainActor.run {
        rawJSONEditorPresentation = presentation
      }
    }
  }

  private func openMarkdownEditorForSelectedItem(
    selectedItem: WorkspaceListItem?
  ) {
    Task {
      let presentation = await workspaceStore.openEssentialEditor(
        selectedItem: selectedItem
      )

      await MainActor.run {
        markdownEditorPresentation = presentation
      }
    }
  }

  private func copySelectedGlobalItemToProject(
    selectedItem: WorkspaceListItem?,
    entityType: WorkspaceLibraryEntityType?
  ) {
    Task {
      let didCopy = await workspaceStore.copySelectedGlobalLibraryItem(
        selectedItem: selectedItem,
        entityType: entityType
      )

      guard didCopy, let selectedItemID = selectedItem?.id else {
        return
      }

      await MainActor.run {
        selectedLibraryItemID = selectedItemID
      }
    }
  }

  private func copySelectedGlobalEssentialToProject(
    selectedItem: WorkspaceListItem?
  ) {
    Task {
      let didCopy = await workspaceStore.copySelectedGlobalEssentialToProject(
        selectedItem: selectedItem
      )

      guard didCopy, let selectedItemID = selectedItem?.id else {
        return
      }

      await MainActor.run {
        selectedLibraryItemID = selectedItemID
      }
    }
  }
}
