import Foundation
import Synchronization
import Testing

@testable import OrbitServerRuntime

struct Phase1MeetingCompletionServiceTests {
  private let workspaceID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
  private let channelID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
  private let postID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
  private let threadID = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
  private let summaryNoteID = UUID(uuidString: "55555555-5555-5555-5555-555555555555")!

  @Test
  func completeMeetingWritesDecisionBundleAndUpdatesSummaryInPlace() async throws {
    let recorder = MeetingCompletionRecorder()
    let completedAt = Date(timeIntervalSince1970: 1_742_342_700)
    let decisionID = UUID(uuidString: "66666666-6666-6666-6666-666666666666")!
    let questionID1 = UUID(uuidString: "77777777-7777-7777-7777-777777777777")!
    let questionID2 = UUID(uuidString: "88888888-8888-8888-8888-888888888888")!
    let referenceID1 = UUID(uuidString: "99999999-9999-9999-9999-999999999999")!
    let referenceID2 = UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!
    let postEventID = UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!
    let questionIDs = Mutex([questionID1, questionID2])
    let referenceIDs = Mutex([referenceID1, referenceID2])
    let service = OrbitPhase1MeetingCompletionService(
      loadSnapshot: { _, _, _ in sampleMeetingSnapshot() },
      completeMeetingWrite: {
        workspaceID,
        summaryNote,
        meetingOutputState,
        decision,
        references,
        structuredAttachments,
        meetingOpenQuestions,
        meetingState,
        postEvent,
        realtimeEvents,
        threadID,
        threadLastActivityAt in
        await recorder.record(
          workspaceID: workspaceID,
          summaryNote: summaryNote,
          meetingOutputState: meetingOutputState,
          decision: decision,
          references: references,
          structuredAttachments: structuredAttachments,
          meetingOpenQuestions: meetingOpenQuestions,
          meetingState: meetingState,
          postEvent: postEvent,
          realtimeEvents: realtimeEvents,
          threadID: threadID,
          threadLastActivityAt: threadLastActivityAt
        )
      },
      now: { completedAt },
      makeDecisionID: { decisionID },
      makeReferenceID: {
        referenceIDs.withLock { ids in
          ids.removeFirst()
        }
      },
      makeMeetingOpenQuestionID: {
        questionIDs.withLock { ids in
          ids.removeFirst()
        }
      },
      makePostEventID: { postEventID }
    )

    let result = try await service.completeMeeting(
      OrbitPhase1CompleteMeetingRequest(
        workspaceSlug: "orbit",
        channelSlug: "command-center",
        postID: postID,
        summaryBody: "The meeting aligned on one canonical completion slice.",
        outcome: .decision,
        decisionTitle: "Ship the first meeting completion shell",
        decisionBody: "Persist summary, decision, open questions, and references through replay.",
        openQuestions: [
          "How should future edits reopen a completed meeting?",
          "Should summary authorship gain explicit updated metadata?",
        ],
        followUpReferences: [
          OrbitPhase1MeetingReferenceSpec(
            referenceType: .doc,
            target: "Docs/Orbit/Planning/Milestones/M5-Meeting-Promotion-And-Continuity/README.md",
            title: "M5 packet scope"
          ),
          OrbitPhase1MeetingReferenceSpec(
            referenceType: .file,
            target: "Sources/Features/OrbitServerRuntime/Phase1MeetingCompletionService.swift"
          ),
        ],
        completedByParticipantType: .user,
        completedByParticipantID: "aj"
      )
    )

    let capturedWrite = try #require(await recorder.write)
    #expect(capturedWrite.workspaceID == workspaceID)
    #expect(capturedWrite.summaryNote.id == summaryNoteID)
    #expect(capturedWrite.summaryNote.body == "The meeting aligned on one canonical completion slice.")
    #expect(capturedWrite.meetingOutputState.outcomeState == .decisionRecorded)
    #expect(capturedWrite.meetingOutputState.recordedByParticipantID == "aj")
    #expect(capturedWrite.decision?.id == decisionID)
    #expect(capturedWrite.decision?.decisionState == .adopted)
    #expect(capturedWrite.decision?.createdByParticipantID == "aj")
    #expect(capturedWrite.decision?.linkedReferenceIDs == [referenceID1, referenceID2])
    #expect(capturedWrite.references.map(\.id) == [referenceID1, referenceID2])
    #expect(capturedWrite.references.allSatisfy { $0.createdByParticipantID == "aj" })
    #expect(capturedWrite.structuredAttachments.count == 4)
    #expect(capturedWrite.meetingOpenQuestions.map(\.id) == [questionID1, questionID2])
    #expect(capturedWrite.meetingOpenQuestions[0].createdAt < capturedWrite.meetingOpenQuestions[1].createdAt)
    #expect(capturedWrite.references[0].createdAt < capturedWrite.references[1].createdAt)
    #expect(capturedWrite.meetingState.status == .completed)
    #expect(capturedWrite.meetingState.completedAt == completedAt)
    #expect(capturedWrite.postEvent.id == postEventID)
    #expect(capturedWrite.postEvent.eventType == OrbitPhase1RealtimeEventCategory.meetingOutputCommitted.rawValue)
    let completionPayload = try OrbitPhase1RealtimeEventPayloadCodec.decode(
      OrbitPhase1MeetingCompletionEventPayload.self,
      from: capturedWrite.postEvent.payloadJSON
    )
    #expect(completionPayload.structuredAttachments.map(\.structuredObjectType) == [
      .note,
      .decision,
      .reference,
      .reference,
    ])
    #expect(capturedWrite.realtimeEvents.map(\.category) == [.meetingOutputCommitted])
    #expect(capturedWrite.threadID == threadID)
    #expect(capturedWrite.threadLastActivityAt == completedAt)

    #expect(result.summaryNote.id == summaryNoteID)
    #expect(result.meetingOutputState.outcomeState == OrbitMeetingOutcomeState.decisionRecorded)
    #expect(result.decision?.title == "Ship the first meeting completion shell")
    #expect(result.references.count == 2)
    #expect(result.meetingOpenQuestions.count == 2)
    #expect(result.snapshot.thread.lastActivityAt == completedAt)
    #expect(result.snapshot.meetingState?.status == .completed)
    #expect(result.snapshot.meetingOutputState?.outcomeState == .decisionRecorded)
  }

  @Test
  func completeMeetingSupportsExplicitNoDecisionWithoutDecisionRecord() async throws {
    let recorder = MeetingCompletionRecorder()
    let completedAt = Date(timeIntervalSince1970: 1_742_342_701)
    let service = OrbitPhase1MeetingCompletionService(
      loadSnapshot: { _, _, _ in sampleMeetingSnapshot() },
      completeMeetingWrite: {
        workspaceID,
        summaryNote,
        meetingOutputState,
        decision,
        references,
        structuredAttachments,
        meetingOpenQuestions,
        meetingState,
        postEvent,
        realtimeEvents,
        threadID,
        threadLastActivityAt in
        await recorder.record(
          workspaceID: workspaceID,
          summaryNote: summaryNote,
          meetingOutputState: meetingOutputState,
          decision: decision,
          references: references,
          structuredAttachments: structuredAttachments,
          meetingOpenQuestions: meetingOpenQuestions,
          meetingState: meetingState,
          postEvent: postEvent,
          realtimeEvents: realtimeEvents,
          threadID: threadID,
          threadLastActivityAt: threadLastActivityAt
        )
      },
      now: { completedAt }
    )

    let result = try await service.completeMeeting(
      OrbitPhase1CompleteMeetingRequest(
        workspaceSlug: "orbit",
        channelSlug: "command-center",
        postID: postID,
        summaryBody: "The meeting closed with no final decision yet.",
        outcome: .noDecision,
        noDecisionDetail: "Team needs one more implementation spike before choosing.",
        completedByParticipantType: .user,
        completedByParticipantID: "aj"
      )
    )

    let capturedWrite = try #require(await recorder.write)
    #expect(capturedWrite.decision == nil)
    #expect(capturedWrite.meetingOutputState.outcomeState == .noDecisionRecorded)
    #expect(capturedWrite.meetingOutputState.detail == "Team needs one more implementation spike before choosing.")
    #expect(result.decision == nil)
    #expect(result.meetingOutputState.outcomeState == OrbitMeetingOutcomeState.noDecisionRecorded)
  }

  @Test
  func completeMeetingRejectsMixedNoDecisionPayload() async {
    let service = OrbitPhase1MeetingCompletionService(
      loadSnapshot: { _, _, _ in sampleMeetingSnapshot() },
      completeMeetingWrite: { _, _, _, _, _, _, _, _, _, _, _, _ in
        Issue.record("completeMeetingWrite should not be called")
      }
    )

    do {
      _ = try await service.completeMeeting(
        OrbitPhase1CompleteMeetingRequest(
          workspaceSlug: "orbit",
          channelSlug: "command-center",
          postID: postID,
          summaryBody: "No decision yet.",
          outcome: .noDecision,
          decisionTitle: "Should not be present",
          noDecisionDetail: "Still evaluating options.",
          completedByParticipantType: .user,
          completedByParticipantID: "aj"
        )
      )
      Issue.record("Expected mixed payload validation error")
    } catch let error as OrbitPhase1MeetingCompletionServiceError {
      #expect(error == .invalidNoDecisionPayload)
    } catch {
      Issue.record("Unexpected error: \(error)")
    }
  }

  @Test
  func completeMeetingRejectsBlankFollowUpReferenceTarget() async {
    let service = OrbitPhase1MeetingCompletionService(
      loadSnapshot: { _, _, _ in sampleMeetingSnapshot() },
      completeMeetingWrite: { _, _, _, _, _, _, _, _, _, _, _, _ in
        Issue.record("completeMeetingWrite should not be called")
      }
    )

    do {
      _ = try await service.completeMeeting(
        OrbitPhase1CompleteMeetingRequest(
          workspaceSlug: "orbit",
          channelSlug: "command-center",
          postID: postID,
          summaryBody: "Decision made.",
          outcome: .decision,
          decisionTitle: "Ship packet 4",
          decisionBody: "Keep the output bundle inspectable.",
          followUpReferences: [
            OrbitPhase1MeetingReferenceSpec(
              referenceType: .doc,
              target: "   "
            )
          ],
          completedByParticipantType: .user,
          completedByParticipantID: "aj"
        )
      )
      Issue.record("Expected invalid reference payload error")
    } catch let error as OrbitPhase1MeetingCompletionServiceError {
      #expect(error == .invalidReferencePayload)
    } catch {
      Issue.record("Unexpected error: \(error)")
    }
  }

  @Test
  func completeMeetingRejectsNonMeetingScope() async {
    let service = OrbitPhase1MeetingCompletionService(
      loadSnapshot: { _, _, _ in sampleNonMeetingSnapshot() },
      completeMeetingWrite: { _, _, _, _, _, _, _, _, _, _, _, _ in
        Issue.record("completeMeetingWrite should not be called")
      }
    )

    do {
      _ = try await service.completeMeeting(
        OrbitPhase1CompleteMeetingRequest(
          workspaceSlug: "orbit",
          channelSlug: "command-center",
          postID: postID,
          summaryBody: "Not a meeting.",
          outcome: .noDecision,
          completedByParticipantType: .user,
          completedByParticipantID: "aj"
        )
      )
      Issue.record("Expected room-is-not-meeting error")
    } catch let error as OrbitPhase1MeetingCompletionServiceError {
      #expect(error == .roomIsNotMeeting)
    } catch {
      Issue.record("Unexpected error: \(error)")
    }
  }

  @Test
  func completeMeetingMapsConcurrentWriteConflictToAlreadyCompleted() async {
    let service = OrbitPhase1MeetingCompletionService(
      loadSnapshot: { _, _, _ in sampleMeetingSnapshot() },
      completeMeetingWrite: { _, _, _, _, _, _, _, _, _, _, _, _ in
        throw OrbitPostgresRuntimeStoreError.meetingAlreadyCompleted
      }
    )

    do {
      _ = try await service.completeMeeting(
        OrbitPhase1CompleteMeetingRequest(
          workspaceSlug: "orbit",
          channelSlug: "command-center",
          postID: postID,
          summaryBody: "Conflict.",
          outcome: .noDecision,
          completedByParticipantType: .user,
          completedByParticipantID: "aj"
        )
      )
      Issue.record("Expected meeting-already-completed error")
    } catch let error as OrbitPhase1MeetingCompletionServiceError {
      #expect(error == .meetingAlreadyCompleted)
    } catch {
      Issue.record("Unexpected error: \(error)")
    }
  }

  private func sampleMeetingSnapshot() -> OrbitPhase1RoomSnapshot {
    let createdAt = Date(timeIntervalSince1970: 1_742_342_600)

    return OrbitPhase1RoomSnapshot(
      workspace: OrbitWorkspaceRecord(
        id: workspaceID,
        slug: "orbit",
        name: "Orbit",
        status: .active,
        createdAt: createdAt
      ),
      channel: OrbitChannelRecord(
        id: channelID,
        workspaceID: workspaceID,
        slug: "command-center",
        name: "Command Center",
        purpose: "Primary Orbit room",
        status: .active,
        createdAt: createdAt
      ),
      post: OrbitPostRecord(
        id: postID,
        workspaceID: workspaceID,
        channelID: channelID,
        postType: .meeting,
        createdByParticipantType: .user,
        createdByParticipantID: "aj",
        title: "Founding Group Meeting",
        status: .active,
        createdAt: createdAt
      ),
      thread: OrbitThreadRecord(
        id: threadID,
        postID: postID,
        status: .open,
        lastActivityAt: createdAt,
        createdAt: createdAt
      ),
      messages: [],
      postParticipants: [
        OrbitPostParticipantRecord(
          id: UUID(uuidString: "cccccccc-cccc-cccc-cccc-cccccccccccc")!,
          postID: postID,
          participantType: .workspacePersona,
          participantID: UUID(uuidString: "dddddddd-dddd-dddd-dddd-dddddddddddd")!.uuidString,
          joinedAt: createdAt,
          participationMode: .active
        )
      ],
      notes: [
        OrbitNoteRecord(
          id: summaryNoteID,
          postID: postID,
          noteType: .meetingSummary,
          body: "Summary pending.",
          createdByParticipantType: .system,
          createdByParticipantID: "orbit-system",
          createdAt: createdAt
        )
      ],
      meetingOutputState: OrbitMeetingOutputStateRecord(
        postID: postID,
        outcomeState: .pending,
        recordedByParticipantType: .system,
        recordedByParticipantID: "orbit-system",
        recordedAt: createdAt
      ),
      meetingState: OrbitMeetingStateRecord(
        postID: postID,
        meetingType: .team,
        status: .active,
        startedByParticipantType: .user,
        startedByParticipantID: "aj",
        startedAt: createdAt
      ),
      meetingMembers: [
        OrbitMeetingMemberRecord(
          id: UUID(uuidString: "eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee")!,
          meetingPostID: postID,
          postParticipantID: UUID(uuidString: "cccccccc-cccc-cccc-cccc-cccccccccccc")!,
          participationRole: .contributor,
          selectedReason: "Selected from founding-group scope.",
          joinedAt: createdAt
        )
      ]
    )
  }

  private func sampleNonMeetingSnapshot() -> OrbitPhase1RoomSnapshot {
    let snapshot = sampleMeetingSnapshot()

    return OrbitPhase1RoomSnapshot(
      workspace: snapshot.workspace,
      channel: snapshot.channel,
      post: OrbitPostRecord(
        id: snapshot.post.id,
        workspaceID: snapshot.post.workspaceID,
        channelID: snapshot.post.channelID,
        postType: .message,
        createdByParticipantType: snapshot.post.createdByParticipantType,
        createdByParticipantID: snapshot.post.createdByParticipantID,
        title: snapshot.post.title,
        status: snapshot.post.status,
        createdAt: snapshot.post.createdAt,
        archivedAt: snapshot.post.archivedAt
      ),
      thread: snapshot.thread,
      messages: snapshot.messages,
      postParticipants: snapshot.postParticipants,
      notes: snapshot.notes,
      meetingOutputState: snapshot.meetingOutputState,
      meetingState: nil,
      meetingMembers: snapshot.meetingMembers
    )
  }
}

private actor MeetingCompletionRecorder {
  struct Write: Equatable {
    let workspaceID: UUID
    let summaryNote: OrbitNoteRecord
    let meetingOutputState: OrbitMeetingOutputStateRecord
    let decision: OrbitDecisionRecord?
    let references: [OrbitReferenceRecord]
    let structuredAttachments: [OrbitStructuredAttachmentRecord]
    let meetingOpenQuestions: [OrbitMeetingOpenQuestionRecord]
    let meetingState: OrbitMeetingStateRecord
    let postEvent: OrbitPostEventRecord
    let realtimeEvents: [OrbitRealtimeEventRecord]
    let threadID: UUID
    let threadLastActivityAt: Date
  }

  private(set) var write: Write?

  func record(
    workspaceID: UUID,
    summaryNote: OrbitNoteRecord,
    meetingOutputState: OrbitMeetingOutputStateRecord,
    decision: OrbitDecisionRecord?,
    references: [OrbitReferenceRecord],
    structuredAttachments: [OrbitStructuredAttachmentRecord],
    meetingOpenQuestions: [OrbitMeetingOpenQuestionRecord],
    meetingState: OrbitMeetingStateRecord,
    postEvent: OrbitPostEventRecord,
    realtimeEvents: [OrbitRealtimeEventRecord],
    threadID: UUID,
    threadLastActivityAt: Date
  ) {
    write = Write(
      workspaceID: workspaceID,
      summaryNote: summaryNote,
      meetingOutputState: meetingOutputState,
      decision: decision,
      references: references,
      structuredAttachments: structuredAttachments,
      meetingOpenQuestions: meetingOpenQuestions,
      meetingState: meetingState,
      postEvent: postEvent,
      realtimeEvents: realtimeEvents,
      threadID: threadID,
      threadLastActivityAt: threadLastActivityAt
    )
  }
}
