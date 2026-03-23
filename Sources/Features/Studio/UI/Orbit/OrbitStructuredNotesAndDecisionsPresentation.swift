import Foundation
import OrbitServerRuntime

struct OrbitStructuredNotesAndDecisionsSurfaceItem: Identifiable, Equatable {
  enum Content: Equatable {
    case note(OrbitStructuredNoteSurface)
    case decision(OrbitStructuredDecisionSurface)
  }

  let id: String
  let createdByDisplayName: String
  let createdAt: Date
  let content: Content
}

struct OrbitStructuredNoteSurface: Equatable {
  enum Presentation: Equatable {
    case fullBody
    case meetingSummaryReference
  }

  let noteType: OrbitNoteType
  let body: String
  let presentation: Presentation
}

struct OrbitStructuredDecisionSurface: Equatable {
  let title: String
  let body: String
  let decisionState: OrbitDecisionState
  let rationale: String
  let tradeoffs: String
  let dissent: String
  let evidence: [OrbitStructuredDecisionEvidenceSurface]
}

struct OrbitStructuredDecisionEvidenceSurface: Identifiable, Equatable {
  let id: String
  let title: String
  let subtitle: String
  let isMissing: Bool
}

extension OrbitWorkspace {
  func structuredNotesAndDecisionsSurfaceItems(
    for postID: String
  ) -> [OrbitStructuredNotesAndDecisionsSurfaceItem] {
    let structuredObjectRecords = structuredPostObjectRecords(for: postID)
    let referencesByID = Dictionary(
      uniqueKeysWithValues: structuredObjectRecords.compactMap { record -> (String, OrbitReferenceRecord)? in
        guard case let .reference(reference) = record.object else {
          return nil
        }

        return (reference.id.uuidString, reference)
      }
    )
    let isMeetingPost = self.isMeetingPost(postID: postID)

    return structuredObjectRecords.compactMap { record in
      switch record.object {
      case let .note(note):
        return OrbitStructuredNotesAndDecisionsSurfaceItem(
          id: record.id,
          createdByDisplayName: structuredCreatorDisplayName(
            for: note.createdByParticipantType,
            participantID: note.createdByParticipantID
          ),
          createdAt: note.createdAt,
          content: .note(
            OrbitStructuredNoteSurface(
              noteType: note.noteType,
              body: note.body,
              presentation: note.noteType == .meetingSummary && isMeetingPost
                ? .meetingSummaryReference
                : .fullBody
            )
          )
        )
      case let .decision(decision):
        return OrbitStructuredNotesAndDecisionsSurfaceItem(
          id: record.id,
          createdByDisplayName: structuredCreatorDisplayName(
            for: decision.createdByParticipantType,
            participantID: decision.createdByParticipantID
          ),
          createdAt: decision.createdAt,
          content: .decision(
            OrbitStructuredDecisionSurface(
              title: decision.title,
              body: decision.body,
              decisionState: decision.decisionState,
              rationale: decision.rationale,
              tradeoffs: decision.tradeoffs,
              dissent: decision.dissent,
              evidence: decision.linkedReferenceIDs.enumerated().map { index, referenceID in
                if let reference = referencesByID[referenceID.uuidString] {
                  return OrbitStructuredDecisionEvidenceSurface(
                    id: "\(referenceID.uuidString)-\(index)",
                    title: reference.title ?? reference.target,
                    subtitle: "\(reference.referenceType.rawValue): \(reference.target)",
                    isMissing: false
                  )
                }

                return OrbitStructuredDecisionEvidenceSurface(
                  id: "\(referenceID.uuidString)-\(index)",
                  title: "Missing linked evidence",
                  subtitle: "Reference \(referenceID.uuidString) is unavailable in this post.",
                  isMissing: true
                )
              }
            )
          )
        )
      case .reference, .artifact:
        return nil
      }
    }
  }

  var activeStructuredNotesAndDecisionsSurfaceItems: [OrbitStructuredNotesAndDecisionsSurfaceItem] {
    guard let activePostID else {
      return []
    }

    return structuredNotesAndDecisionsSurfaceItems(for: activePostID)
  }

  func structuredCreatorDisplayName(
    for authorType: OrbitParticipantAuthorType,
    participantID: String
  ) -> String {
    if let participant = participant(id: participantID) {
      return participant.displayName
    }

    if let participant = participant(workspacePersonaID: participantID) {
      return participant.displayName
    }

    switch authorType {
    case .user:
      if participantID == OrbitParticipantID.aj.rawValue {
        return "AJ"
      }

      return participantID
    case .workspacePersona:
      return participantID
    case .system:
      if participantID == "orbit-system" {
        return "Orbit System"
      }

      return "System"
    }
  }

  private func isMeetingPost(
    postID: String
  ) -> Bool {
    meetingStatusRecord(for: postID) != nil
      || meetingSummaryRecord(for: postID) != nil
      || meetingOutcomeRecord(for: postID) != nil
  }
}

extension OrbitNoteType {
  var displayText: String {
    switch self {
    case .brief:
      return "Brief"
    case .detailed:
      return "Detailed"
    case .meetingSummary:
      return "Meeting Summary"
    case .retrospective:
      return "Retrospective"
    case .workstreamCloseout:
      return "Workstream Closeout"
    case .manual:
      return "Manual"
    }
  }
}

extension OrbitDecisionState {
  var displayText: String {
    switch self {
    case .proposed:
      return "Proposed"
    case .adopted:
      return "Adopted"
    case .rejected:
      return "Rejected"
    case .superseded:
      return "Superseded"
    }
  }
}
