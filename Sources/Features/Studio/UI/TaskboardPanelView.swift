import Foundation
import SwiftUI

/// Taskboard planning surface with lane templates, lane CRUD, ticket creation, and workspace-local persistence.
struct TaskboardPanelView: View {
  let workspaceStore: WorkspaceStore

  @SceneStorage(StudioHelpStorageKey.taskboard)
  private var isTaskboardHelpExpanded = false

  @State private var board = TaskboardBoard.defaultBoard
  @State private var laneEditorDraft: LaneEditorDraft?
  @State private var ticketEditorDraft: TicketEditorDraft?
  @State private var pendingLaneDeletion: TaskboardLane?
  @State private var persistenceMessage: String?
  @State private var persistenceIsError = false

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      if let helpTopic = StudioHelpCatalog.topic(for: SidebarItem.taskboard) {
        StudioInlineHelpView(
          topic: helpTopic,
          isExpanded: $isTaskboardHelpExpanded
        )
      }

      headerBar

      if let persistenceMessage {
        Text(persistenceMessage)
          .font(.footnote)
          .foregroundStyle(persistenceIsError ? .red : .secondary)
          .padding(.horizontal, 16)
      }

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
    .onAppear {
      loadBoard()
    }
    .onChange(of: workspaceStore.workspaceURL) { _, _ in
      loadBoard()
    }
    .onChange(of: board) { _, _ in
      persistBoard()
    }
  }

  private var sortedLanes: [TaskboardLane] {
    board.lanes.sorted {
      if $0.order == $1.order {
        return $0.id < $1.id
      }

      return $0.order < $1.order
    }
  }

  private var headerBar: some View {
    HStack(alignment: .center, spacing: 10) {
      VStack(alignment: .leading, spacing: 2) {
        Text(board.name)
          .font(.title3)
          .fontWeight(.semibold)
        Text("Admin planning board")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Spacer(minLength: 8)

      Menu {
        Section("Lane Templates") {
          ForEach(TaskboardLaneTemplate.defaults) { template in
            Button {
              createLane(from: template)
            } label: {
              VStack(alignment: .leading, spacing: 2) {
                Text(template.title)
                Text(template.detail)
                  .font(.caption)
              }
            }
          }
        }

        Divider()

        Button("Custom Lane…") {
          laneEditorDraft = LaneEditorDraft.create()
        }
      } label: {
        Label("Add Lane", systemImage: "plus")
      }

      Button {
        resetBoard()
      } label: {
        Label("Reset", systemImage: "arrow.clockwise")
      }
      .help("Reset lanes and tickets to defaults for this workspace.")
    }
    .padding(.horizontal, 16)
  }

  private func laneCard(
    _ lane: TaskboardLane,
    laneIndex: Int,
    laneCount: Int
  ) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .center, spacing: 8) {
        Text(lane.title)
          .font(.headline)

        Spacer(minLength: 4)

        Text("\(lane.tickets.count)")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      HStack(spacing: 8) {
        Button {
          ticketEditorDraft = TicketEditorDraft.create(laneID: lane.id)
        } label: {
          Label("Add Ticket", systemImage: "plus")
        }
        .buttonStyle(.bordered)
        .controlSize(.small)

        Menu {
          Button("Edit Lane…") {
            laneEditorDraft = LaneEditorDraft.edit(lane: lane)
          }

          Button("Move Left") {
            moveLane(laneID: lane.id, direction: -1)
          }
          .disabled(laneIndex == 0)

          Button("Move Right") {
            moveLane(laneID: lane.id, direction: 1)
          }
          .disabled(laneIndex >= laneCount - 1)

          Divider()

          Button("Delete Lane", role: .destructive) {
            pendingLaneDeletion = lane
          }
        } label: {
          Label("Lane Actions", systemImage: "ellipsis.circle")
        }
        .controlSize(.small)
      }

      ForEach(lane.tickets) { ticket in
        VStack(alignment: .leading, spacing: 6) {
          Text(ticket.title)
            .font(.subheadline)
            .fontWeight(.medium)

          HStack(spacing: 6) {
            Text(ticket.priority.label)
              .font(.caption2)
              .padding(.horizontal, 6)
              .padding(.vertical, 3)
              .background(.regularMaterial, in: Capsule())

            Text(ticket.owner)
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
      }

      if lane.tickets.isEmpty {
        Text("No tickets yet")
          .font(.caption)
          .foregroundStyle(.secondary)
          .padding(.vertical, 8)
      }

      Spacer(minLength: 0)
    }
    .padding(12)
    .frame(width: 280, alignment: .topLeading)
    .frame(minHeight: 260, alignment: .topLeading)
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
  }

  private func laneEditorSheet(
    _ draft: LaneEditorDraft
  ) -> some View {
    NavigationStack {
      Form {
        TextField("Lane title", text: Binding(
          get: {
            laneEditorDraft?.title ?? draft.title
          },
          set: { newValue in
            laneEditorDraft?.title = newValue
          }
        ))

        Picker("Template", selection: Binding(
          get: {
            laneEditorDraft?.templateID ?? draft.templateID
          },
          set: { newValue in
            laneEditorDraft?.templateID = newValue
          }
        )) {
          Text("None").tag(Optional<String>.none)
          ForEach(TaskboardLaneTemplate.defaults) { template in
            Text(template.title).tag(Optional(template.id))
          }
        }
      }
      .formStyle(.grouped)
      .navigationTitle(draft.mode == .create ? "New Lane" : "Edit Lane")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            laneEditorDraft = nil
          }
        }

        ToolbarItem(placement: .confirmationAction) {
          Button("Save") {
            applyLaneEditorDraft()
          }
          .disabled((laneEditorDraft?.title ?? draft.title).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
      }
    }
  }

  private func ticketEditorSheet(
    _ draft: TicketEditorDraft
  ) -> some View {
    NavigationStack {
      Form {
        TextField("Ticket title", text: Binding(
          get: {
            ticketEditorDraft?.title ?? draft.title
          },
          set: { newValue in
            ticketEditorDraft?.title = newValue
          }
        ))

        TextField("Owner", text: Binding(
          get: {
            ticketEditorDraft?.owner ?? draft.owner
          },
          set: { newValue in
            ticketEditorDraft?.owner = newValue
          }
        ))

        Picker("Priority", selection: Binding(
          get: {
            ticketEditorDraft?.priority ?? draft.priority
          },
          set: { newValue in
            ticketEditorDraft?.priority = newValue
          }
        )) {
          ForEach(TaskboardTicketPriority.allCases) { priority in
            Text(priority.label).tag(priority)
          }
        }
      }
      .formStyle(.grouped)
      .navigationTitle("New Ticket")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            ticketEditorDraft = nil
          }
        }

        ToolbarItem(placement: .confirmationAction) {
          Button("Save") {
            applyTicketEditorDraft()
          }
          .disabled((ticketEditorDraft?.title ?? draft.title).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
      }
    }
  }

  private func createLane(
    from template: TaskboardLaneTemplate
  ) {
    let title = uniqueLaneTitle(
      baseTitle: template.title,
      excludingLaneID: nil
    )

    board.lanes.append(
      TaskboardLane(
        id: nextLaneID(),
        title: title,
        templateID: template.id,
        order: nextLaneOrder(),
        tickets: []
      )
    )
  }

  private func resetBoard() {
    board = TaskboardBoard.defaultBoard
    persistenceMessage = "Taskboard reset to default lanes."
    persistenceIsError = false
  }

  private func moveLane(
    laneID: String,
    direction: Int
  ) {
    var lanes = sortedLanes

    guard let currentIndex = lanes.firstIndex(where: { $0.id == laneID }) else {
      return
    }

    let targetIndex = currentIndex + direction

    guard lanes.indices.contains(targetIndex) else {
      return
    }

    lanes.swapAt(currentIndex, targetIndex)

    for index in lanes.indices {
      lanes[index].order = index + 1
    }

    board.lanes = lanes
  }

  private func deleteLane(
    laneID: String
  ) {
    board.lanes.removeAll {
      $0.id == laneID
    }
    pendingLaneDeletion = nil
  }

  private func applyLaneEditorDraft() {
    guard var draft = laneEditorDraft else {
      return
    }

    draft.title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)

    guard !draft.title.isEmpty else {
      return
    }

    switch draft.mode {
    case .create:
      board.lanes.append(
        TaskboardLane(
          id: nextLaneID(),
          title: uniqueLaneTitle(baseTitle: draft.title, excludingLaneID: nil),
          templateID: draft.templateID,
          order: nextLaneOrder(),
          tickets: []
        )
      )

    case .edit(let laneID):
      guard let laneIndex = board.lanes.firstIndex(where: { $0.id == laneID }) else {
        laneEditorDraft = nil
        return
      }

      board.lanes[laneIndex].title = uniqueLaneTitle(
        baseTitle: draft.title,
        excludingLaneID: laneID
      )
      board.lanes[laneIndex].templateID = draft.templateID
    }

    laneEditorDraft = nil
  }

  private func applyTicketEditorDraft() {
    guard var draft = ticketEditorDraft else {
      return
    }

    draft.title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
    draft.owner = draft.owner.trimmingCharacters(in: .whitespacesAndNewlines)

    guard !draft.title.isEmpty else {
      return
    }

    guard let laneIndex = board.lanes.firstIndex(where: { $0.id == draft.laneID }) else {
      ticketEditorDraft = nil
      return
    }

    let owner = draft.owner.isEmpty ? "Unassigned" : draft.owner

    board.lanes[laneIndex].tickets.append(
      TaskboardTicket(
        id: nextTicketID(),
        title: draft.title,
        owner: owner,
        priority: draft.priority
      )
    )

    ticketEditorDraft = nil
  }

  private func uniqueLaneTitle(
    baseTitle: String,
    excludingLaneID: String?
  ) -> String {
    let normalizedBase = baseTitle.trimmingCharacters(in: .whitespacesAndNewlines)

    guard !normalizedBase.isEmpty else {
      return "New Lane"
    }

    let existingTitles = Set(
      board.lanes.compactMap { lane -> String? in
        if lane.id == excludingLaneID {
          return nil
        }

        return lane.title.lowercased()
      }
    )

    if !existingTitles.contains(normalizedBase.lowercased()) {
      return normalizedBase
    }

    var suffix = 2

    while true {
      let candidate = "\(normalizedBase) \(suffix)"

      if !existingTitles.contains(candidate.lowercased()) {
        return candidate
      }

      suffix += 1
    }
  }

  private func nextLaneID() -> String {
    let id = "lane-\(board.nextLaneSequence)"
    board.nextLaneSequence += 1
    return id
  }

  private func nextTicketID() -> String {
    let id = "ticket-\(board.nextTicketSequence)"
    board.nextTicketSequence += 1
    return id
  }

  private func nextLaneOrder() -> Int {
    (board.lanes.map(\.order).max() ?? 0) + 1
  }

  private func taskboardFileURL(
    for workspaceURL: URL
  ) -> URL {
    workspaceURL
      .standardizedFileURL
      .appendingPathComponent(".personakit", isDirectory: true)
      .appendingPathComponent("Taskboard", isDirectory: true)
      .appendingPathComponent("taskboard.json", isDirectory: false)
  }

  private func loadBoard() {
    guard let workspaceURL = workspaceStore.workspaceURL else {
      board = TaskboardBoard.defaultBoard
      persistenceMessage = nil
      persistenceIsError = false
      return
    }

    let fileURL = taskboardFileURL(for: workspaceURL)
    let fileManager = FileManager.default

    guard fileManager.fileExists(atPath: fileURL.path()) else {
      board = TaskboardBoard.defaultBoard
      persistenceMessage = "Using default Taskboard lanes for this workspace."
      persistenceIsError = false
      return
    }

    do {
      let data = try Data(contentsOf: fileURL)
      let decodedBoard = try JSONDecoder().decode(TaskboardBoard.self, from: data)
      board = decodedBoard.normalized()
      persistenceMessage = "Loaded Taskboard data from workspace."
      persistenceIsError = false
    } catch {
      board = TaskboardBoard.defaultBoard
      persistenceMessage = "Failed to load Taskboard data: \(error.localizedDescription)"
      persistenceIsError = true
    }
  }

  private func persistBoard() {
    guard let workspaceURL = workspaceStore.workspaceURL else {
      return
    }

    let fileURL = taskboardFileURL(for: workspaceURL)
    let directoryURL = fileURL.deletingLastPathComponent()
    let fileManager = FileManager.default

    do {
      try fileManager.createDirectory(
        at: directoryURL,
        withIntermediateDirectories: true
      )

      let normalizedBoard = board.normalized()
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
      let data = try encoder.encode(normalizedBoard)
      try data.write(to: fileURL, options: .atomic)

      persistenceMessage = "Taskboard saved to workspace."
      persistenceIsError = false
    } catch {
      persistenceMessage = "Failed to save Taskboard data: \(error.localizedDescription)"
      persistenceIsError = true
    }
  }
}

private struct TaskboardBoard: Codable, Equatable {
  var name: String
  var nextLaneSequence: Int
  var nextTicketSequence: Int
  var lanes: [TaskboardLane]

  static let defaultBoard = TaskboardBoard(
    name: "Taskboard",
    nextLaneSequence: 7,
    nextTicketSequence: 4,
    lanes: [
      TaskboardLane(id: "lane-1", title: "Inbox", templateID: "inbox", order: 1, tickets: []),
      TaskboardLane(id: "lane-2", title: "Ready", templateID: "ready", order: 2, tickets: []),
      TaskboardLane(
        id: "lane-3",
        title: "In Progress",
        templateID: "in-progress",
        order: 3,
        tickets: [
          TaskboardTicket(
            id: "ticket-1",
            title: "Implement Taskboard lane CRUD",
            owner: "Samwise",
            priority: .high
          )
        ]
      ),
      TaskboardLane(id: "lane-4", title: "Blocked", templateID: "blocked", order: 4, tickets: []),
      TaskboardLane(
        id: "lane-5",
        title: "Review",
        templateID: "review",
        order: 5,
        tickets: [
          TaskboardTicket(
            id: "ticket-2",
            title: "Run red-pen interaction review",
            owner: "studio-interaction-quality-lead",
            priority: .medium
          )
        ]
      ),
      TaskboardLane(
        id: "lane-6",
        title: "Done",
        templateID: "done",
        order: 6,
        tickets: [
          TaskboardTicket(
            id: "ticket-3",
            title: "Approve Taskboard feature name",
            owner: "AJ",
            priority: .low
          )
        ]
      ),
    ]
  )

  func normalized() -> TaskboardBoard {
    var normalizedBoard = self
    normalizedBoard.lanes = normalizedBoard.lanes
      .sorted {
        if $0.order == $1.order {
          return $0.id < $1.id
        }

        return $0.order < $1.order
      }
      .enumerated()
      .map { index, lane in
        var normalizedLane = lane
        normalizedLane.order = index + 1
        return normalizedLane
      }

    let nextLaneSequenceCandidate = normalizedBoard.lanes.compactMap { lane -> Int? in
      guard lane.id.hasPrefix("lane-") else {
        return nil
      }

      return Int(lane.id.replacingOccurrences(of: "lane-", with: ""))
    }
    .max() ?? 0

    let nextTicketSequenceCandidate = normalizedBoard.lanes
      .flatMap(\.tickets)
      .compactMap { ticket -> Int? in
        guard ticket.id.hasPrefix("ticket-") else {
          return nil
        }

        return Int(ticket.id.replacingOccurrences(of: "ticket-", with: ""))
      }
      .max() ?? 0

    normalizedBoard.nextLaneSequence = max(normalizedBoard.nextLaneSequence, nextLaneSequenceCandidate + 1)
    normalizedBoard.nextTicketSequence = max(normalizedBoard.nextTicketSequence, nextTicketSequenceCandidate + 1)
    return normalizedBoard
  }
}

private struct TaskboardLane: Codable, Equatable, Identifiable {
  let id: String
  var title: String
  var templateID: String?
  var order: Int
  var tickets: [TaskboardTicket]
}

private struct TaskboardTicket: Codable, Equatable, Identifiable {
  let id: String
  var title: String
  var owner: String
  var priority: TaskboardTicketPriority
}

private enum TaskboardTicketPriority: String, Codable, CaseIterable, Identifiable {
  case high
  case medium
  case low

  var id: String {
    rawValue
  }

  var label: String {
    rawValue.capitalized
  }
}

private struct TaskboardLaneTemplate: Identifiable {
  let id: String
  let title: String
  let detail: String

  static let defaults: [TaskboardLaneTemplate] = [
    TaskboardLaneTemplate(id: "inbox", title: "Inbox", detail: "Capture new ideas and requests"),
    TaskboardLaneTemplate(id: "ready", title: "Ready", detail: "Refined and ready to start"),
    TaskboardLaneTemplate(id: "in-progress", title: "In Progress", detail: "Active implementation work"),
    TaskboardLaneTemplate(id: "blocked", title: "Blocked", detail: "Waiting on dependency or decision"),
    TaskboardLaneTemplate(id: "review", title: "Review", detail: "Pending quality and approval pass"),
    TaskboardLaneTemplate(id: "done", title: "Done", detail: "Completed and accepted"),
  ]
}

private struct LaneEditorDraft: Identifiable {
  enum Mode: Equatable {
    case create
    case edit(laneID: String)
  }

  var mode: Mode
  var title: String
  var templateID: String?

  var id: String {
    switch mode {
    case .create:
      return "create-lane"
    case .edit(let laneID):
      return "edit-\(laneID)"
    }
  }

  static func create() -> LaneEditorDraft {
    LaneEditorDraft(
      mode: .create,
      title: "",
      templateID: nil
    )
  }

  static func edit(
    lane: TaskboardLane
  ) -> LaneEditorDraft {
    LaneEditorDraft(
      mode: .edit(laneID: lane.id),
      title: lane.title,
      templateID: lane.templateID
    )
  }
}

private struct TicketEditorDraft: Identifiable {
  let laneID: String
  var title: String
  var owner: String
  var priority: TaskboardTicketPriority

  var id: String {
    "new-ticket-\(laneID)"
  }

  static func create(
    laneID: String
  ) -> TicketEditorDraft {
    TicketEditorDraft(
      laneID: laneID,
      title: "",
      owner: "",
      priority: .medium
    )
  }
}
