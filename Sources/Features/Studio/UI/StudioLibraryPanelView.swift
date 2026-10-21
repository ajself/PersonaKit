import ContextCore
import ContextWorkspaceCore
import StudioFoundation
import SwiftUI

/// Library panel with edit/copy/reveal workflows.
struct StudioLibraryPanelView: View {
  private static let listPaneMinWidth: CGFloat = 160

  let workspaceStore: WorkspaceStore
  let selection: SidebarItem
  let items: [WorkspaceListItem]
  @Binding var searchText: String
  @Binding var selectedLibraryItemID: String?
  @Binding var isInspectorPresented: Bool
  @Binding var inspectorMode: StudioInspectorMode
  let onNavigate: (StudioNavigationTarget) -> Void
  let onNavigateHelpLink: (StudioHelpLink) -> Void

  @State private var detailMode = StudioLibraryDetailMode.edit
  @SceneStorage("studio.library.detailMode")
  private var persistedDetailModeRawValue = StudioLibraryDetailMode.edit.rawValue

  var body: some View {
    let visibleItems = StudioLibraryItemFilter.filteredItems(items, searchText: searchText)
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

        StudioLibraryItemListView(
          selection: selection,
          visibleItems: visibleItems,
          searchText: StudioLibraryItemFilter.normalizedSearchText(searchText),
          selectedLibraryItemID: $selectedLibraryItemID
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      }
      .frame(minWidth: Self.listPaneMinWidth, idealWidth: 320, maxWidth: .infinity)

      StudioLibraryDetailView(
        workspaceStore: workspaceStore,
        selection: selection,
        selectedItem: selectedItem,
        entityType: entityType,
        previewState: previewState,
        detailMode: detailModeBinding,
        onEditInSheet: {
          switch actionState.editAction {
          case .rawJSON:
            workspaceStore.presentLibraryEditor(
              selectedItem: selectedItem,
              entityType: entityType
            )
          case .inlineForm,
            nil:
            break
          }
        },
        onCopyToProject: {
          workspaceStore.copyGlobalLibraryItemToProject(
            selectedItem: selectedItem,
            entityType: entityType
          )
        }
      )
      .frame(minWidth: 0, maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
    // An HSplitView behaves as if its minimum width is its current width; beside the inspector that
    // ratchets the window wider on every section switch, so pin the minimum to the list pane's.
    .frame(minWidth: Self.listPaneMinWidth, maxWidth: .infinity, maxHeight: .infinity)
    .inspector(isPresented: $isInspectorPresented) {
      StudioContextInspectorView(
        primaryTitle: "Info",
        helpTopic: StudioHelpCatalog.topic(for: selection),
        mode: $inspectorMode,
        onNavigateHelpLink: onNavigateHelpLink
      ) {
        StudioLibraryPreviewView(
          selection: selection,
          state: previewState,
          users: selectedItemUsers(selectedItem),
          usersFailedToLoad: workspaceStore.libraryUsageLoadFailed,
          onNavigate: onNavigate
        )
      }
      .inspectorColumnWidth(min: 180, ideal: 260, max: 360)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .sheet(item: personaEditorPresentationBinding) { presentation in
      PersonaEditorView(
        title: "New Persona",
        initialDraft: presentation.draft,
        existingPersonaIDs: presentation.existingPersonaIDs,
        knownKits: presentation.knownKits,
        knownSkills: presentation.knownSkills,
        onCancel: {
          workspaceStore.dismissPersonaEditor()
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
    .sheet(item: rawJSONEditorPresentationBinding) { presentation in
      RawJSONEditorView(
        title: presentation.isCreatingNewItem
          ? "New \(presentation.entityType.displayName)"
          : "Edit \(presentation.itemID)",
        entityType: presentation.entityType,
        initialRawJSON: presentation.rawJSON,
        onCancel: {
          workspaceStore.dismissLibraryEditor()
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
    .onChange(of: selectedItem.map { StudioLibraryDetailItem(item: $0, entityType: entityType) }, initial: true) {
      workspaceStore.selectLibraryDetailItem(selectedItem, entityType: entityType)
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

  private var personaEditorPresentationBinding: Binding<PersonaEditorPresentation?> {
    Binding(
      get: {
        workspaceStore.libraryPersonaEditorPresentation
      },
      set: { presentation in
        if presentation == nil {
          workspaceStore.dismissPersonaEditor()
        }
      }
    )
  }

  private var rawJSONEditorPresentationBinding: Binding<WorkspaceLibraryEditorPresentation?> {
    Binding(
      get: {
        workspaceStore.libraryRawJSONEditorPresentation
      },
      set: { presentation in
        if presentation == nil {
          workspaceStore.dismissLibraryEditor()
        }
      }
    )
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
    default:
      return nil
    }
  }

  private func selectedItemUsers(
    _ selectedItem: WorkspaceListItem?
  ) -> [WorkspaceSessionMapNode]? {
    guard let selectedItem,
      let kind = selection.libraryNodeKind
    else {
      return nil
    }

    return workspaceStore.libraryItemUsers(kind: kind, id: selectedItem.id)
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

  private func openNewItemEditor() {
    switch selection {
    case .personas:
      workspaceStore.presentPersonaEditor()
    case .directives,
      .kits,
      .skills:
      guard let entityType = editableEntityTypeForSelection() else {
        return
      }

      workspaceStore.presentNewLibraryEditor(entityType: entityType)
    default:
      break
    }
  }
}
