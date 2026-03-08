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
}
