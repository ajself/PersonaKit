import Testing

@testable import StudioFeatures

struct TaskboardSearchEngineTests {
  @Test
  func searchMatchesLaneTitleWithoutTicketMatch() {
    let board = TaskboardBoard.defaultBoard.normalized()

    let result = TaskboardSearchEngine.search(
      board: board,
      query: "Blocked"
    )

    #expect(result != nil)
    #expect(result?.matchingLaneIDs == ["lane-4"])
    #expect(result?.matchingTicketIDs == [])
  }

  @Test
  func searchMatchesTicketFieldsAcrossLabelsAndOwner() {
    let board = TaskboardBoard.defaultBoard.normalized()

    let labelResult = TaskboardSearchEngine.search(
      board: board,
      query: "quality"
    )
    #expect(labelResult?.matchingTicketIDs == ["ticket-2"])

    let ownerResult = TaskboardSearchEngine.search(
      board: board,
      query: "samwise"
    )
    #expect(ownerResult?.matchingTicketIDs == ["ticket-1"])

    let descriptionResult = TaskboardSearchEngine.search(
      board: board,
      query: "workflow speed"
    )
    #expect(descriptionResult?.matchingTicketIDs == ["ticket-1"])
  }

  @Test
  func searchReturnsNilForWhitespaceOnlyQuery() {
    let board = TaskboardBoard.defaultBoard.normalized()

    let result = TaskboardSearchEngine.search(
      board: board,
      query: "   "
    )

    #expect(result == nil)
  }

  @Test
  func adjacentLaneIDDefaultsToFirstLaneWhenNothingSelected() {
    let board = TaskboardBoard.defaultBoard.normalized()

    let selected = TaskboardLaneNavigation.adjacentLaneID(
      lanes: board.lanes,
      selectedLaneID: nil,
      direction: 1
    )

    #expect(selected == "lane-1")
  }

  @Test
  func adjacentLaneIDClampsAtBoardEdges() {
    let board = TaskboardBoard.defaultBoard.normalized()

    let leftEdge = TaskboardLaneNavigation.adjacentLaneID(
      lanes: board.lanes,
      selectedLaneID: "lane-1",
      direction: -1
    )
    #expect(leftEdge == "lane-1")

    let rightEdge = TaskboardLaneNavigation.adjacentLaneID(
      lanes: board.lanes,
      selectedLaneID: "lane-6",
      direction: 1
    )
    #expect(rightEdge == "lane-6")
  }

  @Test
  func ticketAdjacentLaneIDReturnsNeighborWithinBounds() {
    let board = TaskboardBoard.defaultBoard.normalized()

    let previousLaneID = TaskboardTicketLaneNavigation.adjacentLaneID(
      lanes: board.lanes,
      currentLaneID: "lane-3",
      direction: -1
    )
    #expect(previousLaneID == "lane-2")

    let nextLaneID = TaskboardTicketLaneNavigation.adjacentLaneID(
      lanes: board.lanes,
      currentLaneID: "lane-3",
      direction: 1
    )
    #expect(nextLaneID == "lane-4")
  }

  @Test
  func ticketAdjacentLaneIDReturnsNilAtBoardEdges() {
    let board = TaskboardBoard.defaultBoard.normalized()

    let beforeFirst = TaskboardTicketLaneNavigation.adjacentLaneID(
      lanes: board.lanes,
      currentLaneID: "lane-1",
      direction: -1
    )
    #expect(beforeFirst == nil)

    let afterLast = TaskboardTicketLaneNavigation.adjacentLaneID(
      lanes: board.lanes,
      currentLaneID: "lane-6",
      direction: 1
    )
    #expect(afterLast == nil)
  }

  @Test
  func ticketAdjacentLaneIDReturnsNilWhenCurrentLaneMissing() {
    let board = TaskboardBoard.defaultBoard.normalized()

    let destination = TaskboardTicketLaneNavigation.adjacentLaneID(
      lanes: board.lanes,
      currentLaneID: "lane-missing",
      direction: 1
    )

    #expect(destination == nil)
  }

  @Test
  func adjacentTicketIDDefaultsToFirstOrLastTicketWhenNothingSelected() {
    let tickets = TaskboardBoard.defaultBoard.normalized().lanes[2].tickets

    let firstTicketID = TaskboardTicketNavigation.adjacentTicketID(
      tickets: tickets,
      selectedTicketID: nil,
      direction: 1
    )
    #expect(firstTicketID == tickets.first?.id)

    let lastTicketID = TaskboardTicketNavigation.adjacentTicketID(
      tickets: tickets,
      selectedTicketID: nil,
      direction: -1
    )
    #expect(lastTicketID == tickets.last?.id)
  }

  @Test
  func adjacentTicketIDMovesWithinBounds() {
    let tickets = [
      TaskboardTicket(
        id: "ticket-1",
        title: "One",
        owner: "Samwise",
        assignees: [],
        priority: .medium,
        labels: [],
        dueDateISO8601: nil,
        checklist: [],
        descriptionMarkdown: "",
        comments: []
      ),
      TaskboardTicket(
        id: "ticket-2",
        title: "Two",
        owner: "Samwise",
        assignees: [],
        priority: .medium,
        labels: [],
        dueDateISO8601: nil,
        checklist: [],
        descriptionMarkdown: "",
        comments: []
      ),
      TaskboardTicket(
        id: "ticket-3",
        title: "Three",
        owner: "Samwise",
        assignees: [],
        priority: .medium,
        labels: [],
        dueDateISO8601: nil,
        checklist: [],
        descriptionMarkdown: "",
        comments: []
      ),
    ]

    let nextTicketID = TaskboardTicketNavigation.adjacentTicketID(
      tickets: tickets,
      selectedTicketID: "ticket-2",
      direction: 1
    )
    #expect(nextTicketID == "ticket-3")

    let previousTicketID = TaskboardTicketNavigation.adjacentTicketID(
      tickets: tickets,
      selectedTicketID: "ticket-2",
      direction: -1
    )
    #expect(previousTicketID == "ticket-1")
  }

  @Test
  func adjacentTicketIDClampsAtEdgesAndReturnsNilForEmptyLists() {
    let tickets = TaskboardBoard.defaultBoard.normalized().lanes[2].tickets

    let beforeFirst = TaskboardTicketNavigation.adjacentTicketID(
      tickets: tickets,
      selectedTicketID: tickets.first?.id,
      direction: -1
    )
    #expect(beforeFirst == tickets.first?.id)

    let afterLast = TaskboardTicketNavigation.adjacentTicketID(
      tickets: tickets,
      selectedTicketID: tickets.last?.id,
      direction: 1
    )
    #expect(afterLast == tickets.last?.id)

    let emptyResult = TaskboardTicketNavigation.adjacentTicketID(
      tickets: [],
      selectedTicketID: nil,
      direction: 1
    )
    #expect(emptyResult == nil)
  }
}
