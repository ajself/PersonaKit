#if os(macOS)
  import AppKit
  import Foundation
  import SnapshotTesting
  import SwiftUI
  import XCTest

  @testable import StudioFeatures

  @MainActor
  final class TaskboardSnapshotTests: XCTestCase {
    override func invokeTest() {
      let recordMode: SnapshotTestingConfiguration.Record =
        ProcessInfo.processInfo
          .environment["RECORD_SNAPSHOTS"] == "1" ? .all : .missing

      withSnapshotTesting(record: recordMode) {
        super.invokeTest()
      }
    }

    func testTaskboardDefaultBoard() throws {
      let store = WorkspaceStore()
      let view = makeHostingView(
        workspaceStore: store,
        width: 1500,
        height: 920
      )

      assertSnapshot(
        of: view,
        as: .image,
        named: "taskboard-default-board"
      )
    }

    func testTaskboardEmptyBoard() throws {
      let workspaceURL = try makeWorkspaceWithBoard(
        TaskboardBoard(
          name: "Taskboard",
          nextLaneSequence: 1,
          nextTicketSequence: 1,
          nextChecklistSequence: 1,
          nextCommentSequence: 1,
          lanes: []
        )
      )

      let store = WorkspaceStore()
      store.workspaceURL = workspaceURL
      let view = makeHostingView(
        workspaceStore: store,
        width: 1500,
        height: 920
      )

      assertSnapshot(
        of: view,
        as: .image,
        named: "taskboard-empty-board"
      )
    }

    func testTaskboardDenseBoard() throws {
      let workspaceURL = try makeWorkspaceWithBoard(denseBoardFixture())

      let store = WorkspaceStore()
      store.workspaceURL = workspaceURL
      let view = makeHostingView(
        workspaceStore: store,
        width: 1800,
        height: 920
      )

      assertSnapshot(
        of: view,
        as: .image,
        named: "taskboard-dense-board"
      )
    }

    func testTaskboardSelectedLane() throws {
      let board = TaskboardBoard.defaultBoard
      let selectedLaneID = "lane-3"
      let workspaceURL = try makeWorkspaceWithBoard(board)

      let store = WorkspaceStore()
      store.workspaceURL = workspaceURL
      let view = makeHostingView(
        workspaceStore: store,
        snapshotSeed: TaskboardPanelSnapshotSeed(selectedLaneID: selectedLaneID),
        width: 1500,
        height: 920
      )

      assertSnapshot(
        of: view,
        as: .image,
        named: "taskboard-selected-lane"
      )
    }

    func testTaskboardLaneEditorOpen() throws {
      let board = TaskboardBoard.defaultBoard
      let lane = try XCTUnwrap(board.lanes.first(where: { $0.id == "lane-3" }))
      let workspaceURL = try makeWorkspaceWithBoard(board)

      let store = WorkspaceStore()
      store.workspaceURL = workspaceURL
      let view = makeLaneEditorHostingView(
        workspaceStore: store,
        boardWidth: 1380,
        editorWidth: 420,
        height: 920,
        draft: LaneEditorDraft.edit(lane: lane),
        snapshotSeed: TaskboardPanelSnapshotSeed(selectedLaneID: lane.id)
      )

      assertSnapshot(
        of: view,
        as: .image,
        named: "taskboard-lane-editor-open"
      )
    }

    func testTaskboardTicketEditorOpen() throws {
      let board = TaskboardBoard.defaultBoard
      let lane = try XCTUnwrap(board.lanes.first(where: { $0.id == "lane-3" }))
      let ticket = try XCTUnwrap(lane.tickets.first)
      let workspaceURL = try makeWorkspaceWithBoard(board)

      let store = WorkspaceStore()
      store.workspaceURL = workspaceURL
      let view = makeTicketEditorHostingView(
        workspaceStore: store,
        boardWidth: 1380,
        editorWidth: 420,
        height: 920,
        draft: TicketEditorDraft.edit(ticket: ticket, laneID: lane.id),
        snapshotSeed: TaskboardPanelSnapshotSeed(selectedLaneID: lane.id)
      )

      assertSnapshot(
        of: view,
        as: .image,
        named: "taskboard-ticket-editor-open"
      )
    }

    func testTaskboardActiveDragTargetHighlight() throws {
      let board = TaskboardBoard.defaultBoard
      let lane = try XCTUnwrap(board.lanes.first(where: { $0.id == "lane-5" }))
      let ticket = try XCTUnwrap(lane.tickets.first)
      let workspaceURL = try makeWorkspaceWithBoard(board)

      let store = WorkspaceStore()
      store.workspaceURL = workspaceURL
      let view = makeHostingView(
        workspaceStore: store,
        snapshotSeed: TaskboardPanelSnapshotSeed(
          selectedLaneID: lane.id,
          activeDropLaneID: lane.id,
          activeDropTicketID: ticket.id
        ),
        width: 1500,
        height: 920
      )

      assertSnapshot(
        of: view,
        as: .image,
        named: "taskboard-active-drag-target"
      )
    }

    private func makeWorkspaceWithBoard(
      _ board: TaskboardBoard
    ) throws -> URL {
      let fileManager = FileManager.default
      let workspaceURL = fileManager.temporaryDirectory
        .appendingPathComponent("taskboard-snapshot-\(UUID().uuidString)", isDirectory: true)
      let taskboardDirectory =
        workspaceURL
        .appendingPathComponent(".personakit", isDirectory: true)
        .appendingPathComponent("Taskboard", isDirectory: true)
      let boardFileURL = taskboardDirectory.appendingPathComponent("taskboard.json", isDirectory: false)

      try fileManager.createDirectory(
        at: taskboardDirectory,
        withIntermediateDirectories: true
      )

      let encoder = JSONEncoder()
      encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
      let data = try encoder.encode(board)
      try data.write(to: boardFileURL, options: .atomic)
      return workspaceURL.standardizedFileURL
    }

    private func makeHostingView(
      workspaceStore: WorkspaceStore,
      snapshotSeed: TaskboardPanelSnapshotSeed? = nil,
      width: CGFloat,
      height: CGFloat
    ) -> NSView {
      let rootView = TaskboardPanelView(
        workspaceStore: workspaceStore,
        snapshotSeed: snapshotSeed
      )
        .frame(width: width, height: height)
      let hostingView = NSHostingView(rootView: rootView)
      hostingView.frame = CGRect(x: 0, y: 0, width: width, height: height)
      hostingView.layoutSubtreeIfNeeded()
      RunLoop.main.run(until: Date().addingTimeInterval(0.2))
      return hostingView
    }

    private func makeLaneEditorHostingView(
      workspaceStore: WorkspaceStore,
      boardWidth: CGFloat,
      editorWidth: CGFloat,
      height: CGFloat,
      draft: LaneEditorDraft,
      snapshotSeed: TaskboardPanelSnapshotSeed
    ) -> NSView {
      let panel = TaskboardPanelView(
        workspaceStore: workspaceStore,
        snapshotSeed: snapshotSeed
      )
      let editorPanel = TaskboardPanelView(
        workspaceStore: workspaceStore,
        snapshotSeed: TaskboardPanelSnapshotSeed(
          selectedLaneID: snapshotSeed.selectedLaneID,
          laneEditorDraft: draft
        )
      )

      return makeCompositeHostingView(
        boardView: AnyView(panel),
        editorView: AnyView(editorPanel.laneEditorSheet(draft)),
        boardWidth: boardWidth,
        editorWidth: editorWidth,
        height: height
      )
    }

    private func makeTicketEditorHostingView(
      workspaceStore: WorkspaceStore,
      boardWidth: CGFloat,
      editorWidth: CGFloat,
      height: CGFloat,
      draft: TicketEditorDraft,
      snapshotSeed: TaskboardPanelSnapshotSeed
    ) -> NSView {
      let panel = TaskboardPanelView(
        workspaceStore: workspaceStore,
        snapshotSeed: snapshotSeed
      )
      let editorPanel = TaskboardPanelView(
        workspaceStore: workspaceStore,
        snapshotSeed: TaskboardPanelSnapshotSeed(
          selectedLaneID: snapshotSeed.selectedLaneID,
          ticketEditorDraft: draft
        )
      )

      return makeCompositeHostingView(
        boardView: AnyView(panel),
        editorView: AnyView(editorPanel.ticketEditorSheet(draft)),
        boardWidth: boardWidth,
        editorWidth: editorWidth,
        height: height
      )
    }

    private func makeCompositeHostingView(
      boardView: AnyView,
      editorView: AnyView,
      boardWidth: CGFloat,
      editorWidth: CGFloat,
      height: CGFloat
    ) -> NSView {
      let rootView =
        HStack(spacing: 16) {
          boardView
            .frame(width: boardWidth, height: height)

          editorView
            .frame(width: editorWidth, height: height)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .padding(20)
        .frame(width: boardWidth + editorWidth + 56, height: height + 40)

      let hostingView = NSHostingView(rootView: rootView)
      hostingView.frame = CGRect(
        x: 0,
        y: 0,
        width: boardWidth + editorWidth + 56,
        height: height + 40
      )
      hostingView.layoutSubtreeIfNeeded()
      RunLoop.main.run(until: Date().addingTimeInterval(0.2))
      return hostingView
    }

    private func denseBoardFixture() -> TaskboardBoard {
      TaskboardBoard(
        name: "Taskboard",
        nextLaneSequence: 9,
        nextTicketSequence: 17,
        nextChecklistSequence: 8,
        nextCommentSequence: 5,
        lanes: [
          TaskboardLane(
            id: "lane-1",
            title: "Inbox",
            templateID: "inbox",
            order: 1,
            wipLimit: nil,
            isCollapsed: false,
            tickets: [
              makeTicket(id: "ticket-1", title: "Review parity notes", owner: "Samwise", priority: .high, labels: ["parity", "ui"], dueDateISO8601: "2026-03-12"),
              makeTicket(id: "ticket-2", title: "Group benchmark screenshots", owner: "AJ", priority: .medium, labels: ["research"], dueDateISO8601: nil),
            ]
          ),
          TaskboardLane(
            id: "lane-2",
            title: "Ready",
            templateID: "ready",
            order: 2,
            wipLimit: 4,
            isCollapsed: false,
            tickets: [
              makeTicket(id: "ticket-3", title: "Tighten board hierarchy", owner: "Designer", priority: .high, labels: ["visual", "board"], dueDateISO8601: "2026-03-10"),
              makeTicket(id: "ticket-4", title: "Add keyboard lane movement", owner: "Samwise", priority: .high, labels: ["keyboard"], dueDateISO8601: "2026-03-11"),
              makeTicket(id: "ticket-5", title: "Refine dense card metadata", owner: "Designer", priority: .medium, labels: ["metadata"], dueDateISO8601: nil),
            ]
          ),
          TaskboardLane(
            id: "lane-3",
            title: "In Progress",
            templateID: "in-progress",
            order: 3,
            wipLimit: 3,
            isCollapsed: false,
            tickets: [
              makeTicket(id: "ticket-6", title: "Implement inline quick edit", owner: "Samwise", priority: .high, labels: ["editing", "ui"], dueDateISO8601: "2026-03-09", checklistCount: 3, completedChecklistCount: 1),
              makeTicket(id: "ticket-7", title: "Tune card chrome spacing", owner: "Designer", priority: .medium, labels: ["visual"], dueDateISO8601: nil, checklistCount: 2, completedChecklistCount: 2),
            ]
          ),
          TaskboardLane(
            id: "lane-4",
            title: "Review",
            templateID: nil,
            order: 4,
            wipLimit: nil,
            isCollapsed: false,
            tickets: [
              makeTicket(id: "ticket-8", title: "Run red-pen parity pass", owner: "Quality", priority: .high, labels: ["review"], dueDateISO8601: "2026-03-13"),
              makeTicket(id: "ticket-9", title: "Check accessibility focus order", owner: "Quality", priority: .medium, labels: ["a11y"], dueDateISO8601: nil),
            ]
          ),
          TaskboardLane(
            id: "lane-5",
            title: "Blocked",
            templateID: "blocked",
            order: 5,
            wipLimit: nil,
            isCollapsed: false,
            tickets: [
              makeTicket(id: "ticket-10", title: "Investigate sheet snapshot rendering", owner: "Samwise", priority: .high, labels: ["tests"], dueDateISO8601: nil),
            ]
          ),
          TaskboardLane(
            id: "lane-6",
            title: "Done",
            templateID: "done",
            order: 6,
            wipLimit: nil,
            isCollapsed: false,
            tickets: [
              makeTicket(id: "ticket-11", title: "Land worktree squad charter", owner: "AJ", priority: .low, labels: ["process"], dueDateISO8601: nil),
              makeTicket(id: "ticket-12", title: "Ship telemetry foundation", owner: "Samwise", priority: .low, labels: ["telemetry"], dueDateISO8601: nil),
              makeTicket(id: "ticket-13", title: "Record baseline snapshots", owner: "Quality", priority: .low, labels: ["snapshots"], dueDateISO8601: nil),
            ]
          ),
          TaskboardLane(
            id: "lane-7",
            title: "Archive",
            templateID: nil,
            order: 7,
            wipLimit: nil,
            isCollapsed: true,
            tickets: [
              makeTicket(id: "ticket-14", title: "Taskboard V1 note cleanup", owner: "Rosie", priority: .low, labels: ["docs"], dueDateISO8601: nil),
            ]
          ),
        ]
      )
    }

    private func makeTicket(
      id: String,
      title: String,
      owner: String,
      priority: TaskboardTicketPriority,
      labels: [String],
      dueDateISO8601: String?,
      checklistCount: Int = 0,
      completedChecklistCount: Int = 0
    ) -> TaskboardTicket {
      let assignee = TaskboardAssignee(
        id: TaskboardMemberCoder.memberID(from: owner),
        displayName: owner
      )

      let checklist = (0..<checklistCount).map { index in
        TaskboardChecklistItem(
          id: "checklist-\(id)-\(index + 1)",
          title: "Checklist item \(index + 1)",
          isComplete: index < completedChecklistCount
        )
      }

      return TaskboardTicket(
        id: id,
        title: title,
        owner: owner,
        assignees: [assignee],
        priority: priority,
        labels: labels,
        dueDateISO8601: dueDateISO8601,
        checklist: checklist,
        descriptionMarkdown: "Support a Trello-like planning loop without losing determinism.",
        comments: []
      )
    }
  }
#endif
