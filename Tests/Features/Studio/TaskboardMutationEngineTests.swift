import Foundation
import Testing

@testable import StudioFeatures

struct TaskboardMutationEngineTests {
  @Test
  func determinismForIdenticalRequestSequence() throws {
    let sequence = makeRequestSequence()

    let first = try applySequence(sequence)
    let second = try applySequence(sequence)

    #expect(first.board == second.board)
    #expect(first.revision == second.revision)
  }

  @Test
  func staleExpectedRevisionFailsWithRevisionConflict() throws {
    let request = TaskboardMutationRequest(
      schemaVersion: TaskboardMutationEngine.schemaVersion,
      requestID: "req-stale",
      expectedBoardRevision: 3,
      operation: .createLane(
        CreateLanePayload(
          title: "Design",
          templateID: nil
        )
      )
    )

    do {
      _ = try TaskboardMutationEngine.apply(
        request,
        to: TaskboardBoard.defaultBoard,
        boardRevision: 2
      )
      Issue.record("Expected revision conflict error.")
    } catch let error as TaskboardMutationError {
      #expect(error.code == .revisionConflict)
    }
  }

  @Test
  func moveTicketToMissingLaneFailsWithoutMutation() throws {
    let board = TaskboardBoard.defaultBoard.normalized()
    let request = TaskboardMutationRequest(
      schemaVersion: TaskboardMutationEngine.schemaVersion,
      requestID: "req-missing-lane",
      expectedBoardRevision: 0,
      operation: .moveTicket(
        MoveTicketPayload(
          ticketID: "ticket-1",
          sourceLaneID: "lane-3",
          destinationLaneID: "lane-999",
          destinationIndex: nil
        )
      )
    )

    do {
      _ = try TaskboardMutationEngine.apply(
        request,
        to: board,
        boardRevision: 0
      )
      Issue.record("Expected lane not found error.")
    } catch let error as TaskboardMutationError {
      #expect(error.code == .laneNotFound)
      #expect(board == TaskboardBoard.defaultBoard.normalized())
    }
  }

  @Test
  func duplicateRequestIDIsIdempotent() throws {
    let request = TaskboardMutationRequest(
      schemaVersion: TaskboardMutationEngine.schemaVersion,
      requestID: "req-idempotent",
      expectedBoardRevision: 10,
      operation: .createLane(
        CreateLanePayload(
          title: "QA",
          templateID: nil
        )
      )
    )

    let originalBoard = TaskboardBoard.defaultBoard.normalized()
    let duplicateResult = try TaskboardMutationEngine.apply(
      request,
      to: originalBoard,
      boardRevision: 10,
      processedRequestIDs: ["req-idempotent"]
    )

    #expect(duplicateResult.duplicateRequest)
    #expect(duplicateResult.board == originalBoard)
    #expect(duplicateResult.boardRevision == 10)
  }

  @Test
  func laneReorderNormalizationProducesContiguousOrder() throws {
    var board = TaskboardBoard.defaultBoard.normalized()
    board.lanes[0].order = 4
    board.lanes[1].order = 12
    board.lanes[2].order = 12

    let request = TaskboardMutationRequest(
      schemaVersion: TaskboardMutationEngine.schemaVersion,
      requestID: "req-reorder",
      expectedBoardRevision: 4,
      operation: .reorderLane(
        ReorderLanePayload(
          laneID: "lane-4",
          destinationIndex: 1
        )
      )
    )

    let result = try TaskboardMutationEngine.apply(
      request,
      to: board,
      boardRevision: 4
    )

    let sortedLanes = result.board.lanes.sorted { $0.order < $1.order }
    #expect(sortedLanes.map(\.order) == Array(1...sortedLanes.count))
  }

  private func makeRequestSequence() -> [TaskboardMutationRequest] {
    [
      TaskboardMutationRequest(
        schemaVersion: TaskboardMutationEngine.schemaVersion,
        requestID: "req-1",
        expectedBoardRevision: 0,
        operation: .createLane(
          CreateLanePayload(
            title: "Design",
            templateID: "ready"
          )
        )
      ),
      TaskboardMutationRequest(
        schemaVersion: TaskboardMutationEngine.schemaVersion,
        requestID: "req-2",
        expectedBoardRevision: 1,
        operation: .createTicket(
          CreateTicketPayload(
            laneID: "lane-2",
            title: "Refine visual hierarchy",
            owner: "Samwise",
            priority: .high,
            labels: ["ux", "design"],
            dueDateISO8601: "2026-03-18",
            checklist: [
              TaskboardChecklistItem(
                id: "draft-1",
                title: "Audit lane spacing",
                isComplete: false
              )
            ]
          )
        )
      ),
      TaskboardMutationRequest(
        schemaVersion: TaskboardMutationEngine.schemaVersion,
        requestID: "req-3",
        expectedBoardRevision: 2,
        operation: .moveTicket(
          MoveTicketPayload(
            ticketID: "ticket-1",
            sourceLaneID: "lane-3",
            destinationLaneID: "lane-5",
            destinationIndex: 0
          )
        )
      ),
      TaskboardMutationRequest(
        schemaVersion: TaskboardMutationEngine.schemaVersion,
        requestID: "req-4",
        expectedBoardRevision: 3,
        operation: .reorderLane(
          ReorderLanePayload(
            laneID: "lane-5",
            destinationIndex: 2
          )
        )
      ),
    ]
  }

  private func applySequence(
    _ requests: [TaskboardMutationRequest]
  ) throws -> (board: TaskboardBoard, revision: Int) {
    var board = TaskboardBoard.defaultBoard.normalized()
    var revision = 0
    var processedRequestIDs = Set<String>()

    for request in requests {
      let result = try TaskboardMutationEngine.apply(
        request,
        to: board,
        boardRevision: revision,
        processedRequestIDs: processedRequestIDs
      )
      board = result.board
      revision = result.boardRevision
      processedRequestIDs.insert(request.requestID)
    }

    return (board, revision)
  }
}
