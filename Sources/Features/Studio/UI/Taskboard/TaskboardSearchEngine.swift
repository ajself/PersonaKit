import Foundation

enum TaskboardSearchEngine {
  static func search(
    board: TaskboardBoard,
    query: String
  ) -> TaskboardSearchResult? {
    let normalizedQuery = normalize(query)
    guard !normalizedQuery.isEmpty else {
      return nil
    }

    let orderedLanes = board.lanes.sorted {
      if $0.order == $1.order {
        return $0.id < $1.id
      }

      return $0.order < $1.order
    }

    var matchingLaneIDs: [String] = []
    var matchingTicketIDs: [String] = []

    for lane in orderedLanes {
      if laneMatches(
        lane,
        normalizedQuery: normalizedQuery
      ) {
        matchingLaneIDs.append(lane.id)
      }

      for ticket in lane.tickets {
        if ticketMatches(
          ticket,
          lane: lane,
          normalizedQuery: normalizedQuery
        ) {
          matchingTicketIDs.append(ticket.id)
        }
      }
    }

    return TaskboardSearchResult(
      normalizedQuery: normalizedQuery,
      matchingLaneIDs: matchingLaneIDs,
      matchingTicketIDs: matchingTicketIDs
    )
  }

  static func laneMatches(
    _ lane: TaskboardLane,
    normalizedQuery: String
  ) -> Bool {
    let fields = [
      lane.title,
      lane.templateID ?? "",
    ]

    let haystack =
      fields
      .joined(separator: " ")
      .lowercased()

    return haystack.contains(normalizedQuery)
  }

  static func ticketMatches(
    _ ticket: TaskboardTicket,
    lane: TaskboardLane,
    normalizedQuery: String
  ) -> Bool {
    let fields = [
      lane.title,
      ticket.title,
      ticket.owner,
      ticket.assignees.map(\.displayName).joined(separator: " "),
      ticket.labels.joined(separator: " "),
      ticket.checklist.map(\.title).joined(separator: " "),
      ticket.descriptionMarkdown,
      ticket.comments.map(\.author).joined(separator: " "),
      ticket.comments.map(\.bodyMarkdown).joined(separator: " "),
      ticket.dueDateISO8601 ?? "",
    ]

    let haystack =
      fields
      .joined(separator: " ")
      .lowercased()

    return haystack.contains(normalizedQuery)
  }

  static func normalize(
    _ query: String
  ) -> String {
    query
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .lowercased()
  }
}

struct TaskboardSearchResult: Equatable {
  let normalizedQuery: String
  let matchingLaneIDs: [String]
  let matchingTicketIDs: [String]
}

enum TaskboardLaneNavigation {
  static func adjacentLaneID(
    lanes: [TaskboardLane],
    selectedLaneID: String?,
    direction: Int
  ) -> String? {
    let orderedLanes = lanes.sorted {
      if $0.order == $1.order {
        return $0.id < $1.id
      }

      return $0.order < $1.order
    }

    guard !orderedLanes.isEmpty else {
      return nil
    }

    guard let selectedLaneID,
      let currentIndex = orderedLanes.firstIndex(where: { $0.id == selectedLaneID })
    else {
      return orderedLanes.first?.id
    }

    let targetIndex = max(0, min(currentIndex + direction, orderedLanes.count - 1))
    return orderedLanes[targetIndex].id
  }
}

enum TaskboardTicketLaneNavigation {
  static func adjacentLaneID(
    lanes: [TaskboardLane],
    currentLaneID: String,
    direction: Int
  ) -> String? {
    let orderedLanes = lanes.sorted {
      if $0.order == $1.order {
        return $0.id < $1.id
      }

      return $0.order < $1.order
    }

    guard let currentIndex = orderedLanes.firstIndex(where: { $0.id == currentLaneID }) else {
      return nil
    }

    let destinationIndex = currentIndex + direction

    guard orderedLanes.indices.contains(destinationIndex) else {
      return nil
    }

    return orderedLanes[destinationIndex].id
  }
}
