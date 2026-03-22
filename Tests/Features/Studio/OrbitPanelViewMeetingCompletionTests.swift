import Foundation
import Testing

@testable import StudioFeatures

@MainActor
struct OrbitPanelViewMeetingCompletionTests {
  @Test
  func meetingCompletionDraftHelpersPreserveDirtySameMeetingAndResyncDifferentMeeting() {
    let initialSeed = OrbitPanelView.meetingCompletionDraftSeed(
      from: sampleMeetingWorkspace(
        postID: "post-meeting-1",
        summaryBody: "Server summary",
        outcomeDetail: "Needs a final review."
      )
    )

    #expect(initialSeed.meetingSummaryDraft == "Server summary")
    #expect(initialSeed.meetingNoDecisionDetailDraft == "Needs a final review.")
    #expect(initialSeed.meetingOutcome == .noDecision)

    #expect(
      OrbitPanelView.shouldSyncMeetingCompletionDrafts(
        force: false,
        meetingCompletionDraftsDirty: true,
        activeMeetingPostID: "post-meeting-1",
        syncedMeetingDraftPostID: "post-meeting-1"
      ) == false
    )

    #expect(
      OrbitPanelView.shouldSyncMeetingCompletionDrafts(
        force: false,
        meetingCompletionDraftsDirty: true,
        activeMeetingPostID: "post-meeting-2",
        syncedMeetingDraftPostID: "post-meeting-1"
      ) == true
    )

    let switchedSeed = OrbitPanelView.meetingCompletionDraftSeed(
      from: sampleMeetingWorkspace(
        postID: "post-meeting-2",
        summaryBody: "Other meeting summary"
      )
    )

    #expect(switchedSeed.meetingSummaryDraft == "Other meeting summary")
    #expect(switchedSeed.syncedMeetingDraftPostID == "post-meeting-2")
  }

  @Test
  func invalidFollowUpReferenceBlocksMeetingCompletionSubmit() {
    let parseResult = OrbitPanelView.parseMeetingFollowUpReferencesDraft(
      """
      doc Docs/Orbit/Planning/Milestones/M5-Meeting-Promotion-And-Continuity/README.md | Packet scope
      not_a_type missing-target
      """
    )

    #expect(parseResult.references.count == 1)
    #expect(parseResult.invalidLines == ["not_a_type missing-target"])
    #expect(
      OrbitPanelView.meetingFollowUpReferenceValidationMessage(
        for: parseResult
      ) != nil
    )
  }
}

private func sampleMeetingWorkspace(
  postID: String,
  summaryBody: String,
  outcomeDetail: String? = nil
) -> OrbitWorkspace {
  var workspace = OrbitWorkspace.defaultWorkspace
  let timestamp = Date(timeIntervalSince1970: 1_742_342_530)
  workspace.activePostID = postID
  workspace.meetingSummaryRecords = [
    OrbitMeetingSummaryRecord(
      id: "\(postID)-summary",
      postID: postID,
      postTitle: "Meeting room",
      body: summaryBody,
      createdByParticipantType: .system,
      createdByParticipantID: "orbit-system",
      createdAt: timestamp
    )
  ]
  workspace.meetingStatusRecords = [
    OrbitMeetingStatusRecord(
      id: "\(postID)-status",
      postID: postID,
      meetingType: .team,
      status: .created,
      startedByParticipantType: .user,
      startedByParticipantID: OrbitParticipantID.aj.rawValue,
      startedAt: timestamp,
      completedAt: nil
    )
  ]
  workspace.meetingOutcomeRecords = [
    OrbitMeetingOutcomeRecord(
      id: "\(postID)-outcome",
      postID: postID,
      outcomeState: .noDecisionRecorded,
      detail: outcomeDetail,
      recordedByParticipantType: .user,
      recordedByParticipantID: OrbitParticipantID.aj.rawValue,
      recordedAt: timestamp
    )
  ]
  return workspace
}
