import ContextCore
import ContextWorkspaceCore
import StudioFoundation
import SwiftUI

/// Library and essentials panel with edit/copy/reveal workflows.
struct StudioLibraryPanelView: View {
  let workspaceStore: WorkspaceStore
  let selection: SidebarItem
  let items: [WorkspaceListItem]
  @Binding var searchText: String
  @Binding var selectedLibraryItemID: String?
  @Binding var isInspectorPresented: Bool
  @Binding var inspectorMode: StudioInspectorMode
  let onNavigateHelpLink: (StudioHelpLink) -> Void

  @State private var markdownEditorPresentation: WorkspaceEssentialEditorPresentation?
  @State private var rawJSONEditorPresentation: WorkspaceLibraryEditorPresentation?
  @State private var personaEditorPresentation: PersonaEditorPresentation?
  @State private var detailMode = StudioLibraryDetailMode.edit
  @SceneStorage("studio.library.detailMode")
  private var persistedDetailModeRawValue = StudioLibraryDetailMode.edit.rawValue

  var body: some View {
    let visibleItems = filteredItems(items)
    let selectedItem = selectedLibraryItem(items: visibleItems)
    let entityType = editableEntityTypeForSelection()
    let actionState = StudioLibraryActionBarState(
      selection: selection,
      selectedItem: selectedItem,
      entityType: entityType,
      isLoadingLibraryEditor: workspaceStore.isLoadingLibraryEditor
    )
    let previewState = selectedItem.map {
      StudioLibraryPreviewState(
        selection: selection,
        item: $0,
        workspaceURL: workspaceStore.workspaceURL
      )
    }

    HSplitView {
      VStack(alignment: .leading, spacing: 0) {
        StudioLibraryToolbarView(
          actionState: actionState,
          searchText: $searchText,
          searchPrompt: "Search \(selection.title)",
          onNew: {
            openNewItemEditor()
          }
        )

        if let libraryActionMessage = workspaceStore.libraryActionMessage {
          Text(libraryActionMessage)
            .font(.footnote)
            .foregroundStyle(workspaceStore.libraryActionIsError ? .red : .secondary)
        }

        if selection == .directives,
          let selectedItem,
          let workstreamId = selectedItem.workstreamId,
          let workstreamPhase = selectedItem.workstreamPhase
        {
          Text("Workstream: \(workstreamId) · Phase: \(workstreamPhase)")
            .font(.footnote)
            .foregroundStyle(.secondary)
        }

        StudioLibraryItemListView(
          visibleItems: visibleItems,
          selectedLibraryItemID: $selectedLibraryItemID
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      }
      .frame(minWidth: 160, idealWidth: 320, maxWidth: .infinity)

      StudioLibraryDetailView(
        selection: selection,
        selectedItem: selectedItem,
        entityType: entityType,
        previewState: previewState,
        snapshotRevision: workspaceStore.snapshotRevision,
        workspaceURL: workspaceStore.workspaceURL,
        detailMode: detailModeBinding,
        onRevealInFinder: { fileURL in
          workspaceStore.revealInFinder(fileURL: fileURL)
        },
        onEditInSheet: {
          switch actionState.editAction {
          case .markdown:
            openMarkdownEditorForSelectedItem(selectedItem: selectedItem)
          case .rawJSON:
            openRawJSONEditorForSelectedItem(
              selectedItem: selectedItem,
              entityType: entityType
            )
          case .inlineForm,
            nil:
            break
          }
        },
        onCopyToProject: {
          switch selection {
          case .essentials:
            copySelectedGlobalEssentialToProject(
              selectedItem: selectedItem
            )
          default:
            copySelectedGlobalItemToProject(
              selectedItem: selectedItem,
              entityType: entityType
            )
          }
        },
        onSaveMarkdown: { markdown, presentation in
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
        },
        onValidate: { rawJSON, presentation in
          await workspaceStore.validateLibraryEditorRawJSON(
            rawJSON,
            presentation: presentation
          )
        },
        onSave: { rawJSON, presentation in
          await workspaceStore.saveLibraryEditorRawJSON(
            rawJSON,
            presentation: presentation
          )
        },
        onSaveSucceeded: { itemID in
          selectedLibraryItemID = itemID
        }
      )
      .frame(minWidth: 0, maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
    .inspector(isPresented: $isInspectorPresented) {
      StudioContextInspectorView(
        primaryTitle: "Info",
        helpTopic: StudioHelpCatalog.topic(for: selection),
        mode: $inspectorMode,
        onNavigateHelpLink: onNavigateHelpLink
      ) {
        StudioLibraryPreviewView(
          selection: selection,
          state: previewState
        )
      }
      .inspectorColumnWidth(min: 180, ideal: 260, max: 360)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .sheet(item: $personaEditorPresentation) { presentation in
      PersonaEditorView(
        title: "New Persona",
        initialDraft: presentation.draft,
        existingPersonaIDs: presentation.existingPersonaIDs,
        knownKits: presentation.knownKits,
        knownSkills: presentation.knownSkills,
        onCancel: {
          personaEditorPresentation = nil
        },
        onSave: { draft in
          let normalizedDraft = WorkspacePersonaDraftBuilder().normalizedDraft(draft)
          let expectedWorkspaceURL = presentation.workspaceURL.standardizedFileURL
          let saveError = await workspaceStore.createPersona(draft: draft)

          if saveError == nil {
            await MainActor.run {
              guard
                workspaceStore.workspaceURL?.standardizedFileURL == expectedWorkspaceURL
              else {
                return
              }

              selectedLibraryItemID = normalizedDraft.id
            }
          }

          return saveError
        }
      )
    }
    .sheet(item: $markdownEditorPresentation) { presentation in
      MarkdownEditorView(
        title: presentation.isCreatingNewItem ? "New Essential" : "Edit \(presentation.itemID)",
        initialMarkdown: presentation.markdown,
        onCancel: {
          markdownEditorPresentation = nil
        },
        onRevealInFinder: presentation.isCreatingNewItem
          ? nil
          : {
            workspaceStore.revealInFinder(fileURL: presentation.fileURL)
          },
        onSave: { markdown in
          let saveError = await workspaceStore.saveEssentialEditorMarkdown(
            markdown,
            presentation: presentation
          )

          if saveError == nil {
            await MainActor.run {
              selectedLibraryItemID =
                presentation.isCreatingNewItem
                ? WorkspaceLibraryCreateSupport.essentialItemID(markdown: markdown)
                : presentation.itemID
            }
          }

          return saveError
        }
      )
    }
    .sheet(item: $rawJSONEditorPresentation) { presentation in
      RawJSONEditorView(
        title: presentation.isCreatingNewItem
          ? "New \(presentation.entityType.displayName)"
          : "Edit \(presentation.itemID)",
        entityType: presentation.entityType,
        initialRawJSON: presentation.rawJSON,
        onCancel: {
          rawJSONEditorPresentation = nil
        },
        onRevealInFinder: presentation.isCreatingNewItem
          ? nil
          : {
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
              selectedLibraryItemID =
                presentation.isCreatingNewItem
                ? (try? WorkspaceLibraryCreateSupport.itemID(rawJSON: rawJSON))
                : presentation.itemID
            }
          }

          return saveError
        }
      )
    }
    .onChange(of: workspaceStore.workspaceURL) { _, _ in
      markdownEditorPresentation = nil
      personaEditorPresentation = nil
      rawJSONEditorPresentation = nil
    }
    .onChange(of: visibleItems.map(\.id)) { _, _ in
      reconcileSelectedLibraryItem(visibleItems: visibleItems)
    }
    .onAppear {
      detailMode = StudioLibraryDetailModeResolver.preferredMode(
        persistedRawValue: persistedDetailModeRawValue,
      )
      reconcileSelectedLibraryItem(visibleItems: visibleItems)
    }
  }

  private var detailModeBinding: Binding<StudioLibraryDetailMode> {
    Binding(
      get: {
        detailMode
      },
      set: { mode in
        detailMode = mode
        persistedDetailModeRawValue = StudioLibraryDetailModeResolver.persistedRawValue(
          for: mode
        )
      }
    )
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
    case .references:
      return .reference
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

  private func reconcileSelectedLibraryItem(
    visibleItems: [WorkspaceListItem]
  ) {
    guard let selectedLibraryItemID else {
      return
    }

    guard visibleItems.contains(where: { $0.id == selectedLibraryItemID }) else {
      self.selectedLibraryItemID = nil
      return
    }
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

  private func openPersonaEditor() {
    guard selection == .personas else {
      return
    }

    guard let workspaceURL = workspaceStore.workspaceURL?.standardizedFileURL else {
      return
    }

    personaEditorPresentation = PersonaEditorPresentation(
      workspaceURL: workspaceURL,
      draft: workspaceStore.defaultPersonaDraft(),
      existingPersonaIDs: workspaceStore.snapshot.personas.map(\.id),
      knownKits: workspaceStore.snapshot.kits,
      knownSkills: workspaceStore.snapshot.skills
    )
  }

  private func openNewItemEditor() {
    switch selection {
    case .personas:
      openPersonaEditor()
    case .essentials:
      markdownEditorPresentation = workspaceStore.newEssentialEditorPresentation()
    case .directives,
      .kits,
      .intents,
      .references,
      .skills:
      guard let entityType = editableEntityTypeForSelection() else {
        return
      }

      rawJSONEditorPresentation = workspaceStore.newLibraryEditorPresentation(
        entityType: entityType
      )
    default:
      break
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
