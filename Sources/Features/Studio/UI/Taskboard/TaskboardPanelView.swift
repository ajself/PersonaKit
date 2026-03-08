import Foundation
import SwiftUI

enum TaskboardPanelFocusField: Hashable {
  case keywordSearch
}

/// Taskboard planning surface with lane templates, lane CRUD, ticket creation, and workspace-local persistence.
struct TaskboardPanelView: View {
  let workspaceStore: WorkspaceStore

  @SceneStorage(StudioHelpStorageKey.taskboard)
  var isTaskboardHelpExpanded = false

  @State var board = TaskboardBoard.defaultBoard
  @State var selectedLaneID: String?
  @State var laneEditorDraft: LaneEditorDraft?
  @State var ticketEditorDraft: TicketEditorDraft?
  @State var pendingLaneDeletion: TaskboardLane?
  @State var pendingTicketDeletion: PendingTicketDeletion?
  @State var activeDropLaneID: String?
  @State var activeDropTicketID: String?
  @State var activeLabelFilter: String?
  @State var dueDateFilter: DueDateFilter = .all
  @State var ownerFilterText = ""
  @State var keywordFilterText = ""
  @State var persistenceMessage: String?
  @State var persistenceIsError = false
  @State var interactionEventSequence = 1
  @FocusState var focusedField: TaskboardPanelFocusField?

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      if let helpTopic = StudioHelpCatalog.topic(for: SidebarItem.taskboard) {
        StudioInlineHelpView(
          topic: helpTopic,
          isExpanded: $isTaskboardHelpExpanded
        )
      }

      headerBar
      filterBar

      if let persistenceMessage {
        Text(persistenceMessage)
          .font(.footnote)
          .foregroundStyle(persistenceIsError ? .red : .secondary)
          .padding(.horizontal, 16)
      }

      if sortedLanes.isEmpty {
        VStack(alignment: .center, spacing: 10) {
          Image(systemName: "rectangle.3.group")
            .font(.system(size: 28, weight: .regular))
            .foregroundStyle(.secondary)
          Text("No Lanes Yet")
            .font(.headline)
          Text("Start by adding a lane from a template.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
          Button {
            if let inboxTemplate = TaskboardLaneTemplate.defaults.first {
              createLane(from: inboxTemplate)
            } else {
              laneEditorDraft = LaneEditorDraft.create()
            }
          } label: {
            Label("Add First Lane", systemImage: "plus")
          }
          .buttonStyle(.borderedProminent)
          .controlSize(.small)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
      } else {
        ScrollView([.horizontal, .vertical]) {
          HStack(alignment: .top, spacing: 12) {
            ForEach(Array(sortedLanes.enumerated()), id: \.element.id) { index, lane in
              laneCard(
                lane,
                laneIndex: index,
                laneCount: sortedLanes.count
              )
            }
          }
          .padding(.horizontal, 16)
          .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .sheet(item: $laneEditorDraft) { draft in
      laneEditorSheet(draft)
    }
    .sheet(item: $ticketEditorDraft) { draft in
      ticketEditorSheet(draft)
    }
    .alert(
      "Delete Lane?",
      isPresented: Binding(
        get: {
          pendingLaneDeletion != nil
        },
        set: { isPresented in
          if !isPresented {
            pendingLaneDeletion = nil
          }
        }
      ),
      presenting: pendingLaneDeletion
    ) { lane in
      Button("Delete", role: .destructive) {
        deleteLane(laneID: lane.id)
      }
      Button("Cancel", role: .cancel) {
        pendingLaneDeletion = nil
      }
    } message: { lane in
      Text("Delete lane \"\(lane.title)\" and all tickets in it?")
    }
    .alert(
      "Delete Ticket?",
      isPresented: Binding(
        get: {
          pendingTicketDeletion != nil
        },
        set: { isPresented in
          if !isPresented {
            pendingTicketDeletion = nil
          }
        }
      ),
      presenting: pendingTicketDeletion
    ) { pendingDeletion in
      Button("Delete", role: .destructive) {
        deleteTicket(
          ticketID: pendingDeletion.ticketID,
          laneID: pendingDeletion.laneID
        )
      }
      Button("Cancel", role: .cancel) {
        pendingTicketDeletion = nil
      }
    } message: { pendingDeletion in
      Text("Delete ticket \"\(pendingDeletion.ticketTitle)\"?")
    }
    .onAppear {
      loadBoard()
    }
    .onChange(of: workspaceStore.workspaceURL) { _, _ in
      loadBoard()
    }
    .onChange(of: board) { _, updatedBoard in
      if let selectedLaneID,
        !updatedBoard.lanes.contains(where: { $0.id == selectedLaneID })
      {
        self.selectedLaneID =
          updatedBoard.lanes
          .sorted { $0.order < $1.order }
          .first?
          .id
      }

      persistBoard()
    }
  }
}
