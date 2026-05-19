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

  @SceneStorage(StudioHelpStorageKey.personas)
  private var isPersonasHelpExpanded = false
  @SceneStorage(StudioHelpStorageKey.directives)
  private var isDirectivesHelpExpanded = false
  @SceneStorage(StudioHelpStorageKey.kits)
  private var isKitsHelpExpanded = false
  @SceneStorage(StudioHelpStorageKey.essentials)
  private var isEssentialsHelpExpanded = false
  @SceneStorage(StudioHelpStorageKey.references)
  private var isReferencesHelpExpanded = false
  @SceneStorage(StudioHelpStorageKey.skills)
  private var isSkillsHelpExpanded = false
  @SceneStorage(StudioHelpStorageKey.intents)
  private var isIntentsHelpExpanded = false

  @State private var markdownEditorPresentation: WorkspaceEssentialEditorPresentation?
  @State private var rawJSONEditorPresentation: WorkspaceLibraryEditorPresentation?
  @State private var personaEditorPresentation: PersonaEditorPresentation?

  var body: some View {
    let visibleItems = filteredItems(items)
    let selectedItem = selectedLibraryItem(items: visibleItems)
    let entityType = editableEntityTypeForSelection()
    let actionState = StudioLibraryActionBarState(
      selection: selection,
      selectedItem: selectedItem,
      isLoadingLibraryEditor: workspaceStore.isLoadingLibraryEditor
    )

    VStack(alignment: .leading, spacing: 0) {
      StudioLibraryToolbarView(
        actionState: actionState,
        searchText: $searchText,
        searchPrompt: "Search \(selection.title)",
        onNew: {
          openPersonaEditor()
        },
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

      if let helpTopic = StudioHelpCatalog.topic(for: selection) {
        StudioInlineHelpView(
          topic: helpTopic,
          isExpanded: libraryHelpExpandedBinding
        )
      }

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
    .inspector(isPresented: $isInspectorPresented) {
      StudioLibraryPreviewView(
        selection: selection,
        state: selectedItem.map {
          StudioLibraryPreviewState(
            selection: selection,
            item: $0,
            workspaceURL: workspaceStore.workspaceURL
          )
        }
      )
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
      personaEditorPresentation = nil
      rawJSONEditorPresentation = nil
    }
    .onChange(of: visibleItems.map(\.id)) { _, _ in
      reconcileSelectedLibraryItem(visibleItems: visibleItems)
    }
    .onAppear {
      reconcileSelectedLibraryItem(visibleItems: visibleItems)
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
    if let selectedLibraryItemID,
      visibleItems.contains(where: { $0.id == selectedLibraryItemID })
    {
      return
    }

    selectedLibraryItemID = visibleItems.first?.id
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

  private var libraryHelpExpandedBinding: Binding<Bool> {
    switch selection {
    case .personas:
      return $isPersonasHelpExpanded
    case .directives:
      return $isDirectivesHelpExpanded
    case .kits:
      return $isKitsHelpExpanded
    case .essentials:
      return $isEssentialsHelpExpanded
    case .references:
      return $isReferencesHelpExpanded
    case .skills:
      return $isSkillsHelpExpanded
    case .intents:
      return $isIntentsHelpExpanded
    case .sessions,
      .relationshipMap,
      .validationResults:
      return .constant(false)
    }
  }
}
