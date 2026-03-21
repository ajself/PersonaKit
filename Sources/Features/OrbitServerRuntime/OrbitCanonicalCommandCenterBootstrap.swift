import Foundation

public enum OrbitCanonicalCommandCenterBootstrap {
  public static let room = makeRoom()

  private static func encodedActivationPayload(
    activation: OrbitPersonaActivationRecord,
    agentRun: OrbitAgentRunRecord
  ) -> String {
    do {
      return try OrbitPhase1RealtimeEventPayloadCodec.encode(
        OrbitPhase1ActivationEventPayload(
          activation: activation,
          agentRun: agentRun,
          contract: OrbitPhase1ResolvedContractPayload(
            directiveID: "maintain-partner-sync-and-handoffs",
            directiveSource: "participantDefault",
            kitIDs: ["trusted-partner-core"],
            authorizedSkillIDs: ["codex-cli"],
            requiredSkillIDs: ["codex-cli"],
            reviewGateIDs: ["intent:partner-sync-review"]
          )
        )
      )
    } catch {
      preconditionFailure(
        "OrbitCanonicalCommandCenterBootstrap failed to encode the Samwise activation payload: \(String(reflecting: error))"
      )
    }
  }

  private static func makeRoom() -> OrbitPhase1RoomBootstrap {
    let workspaceID = UUID(uuidString: "d31218b2-1cf7-4d31-a8af-5fbe519db8d8")!
    let channelID = UUID(uuidString: "c7b4c0c2-9f8f-40db-95aa-54bd5dd092d5")!
    let samwiseWorkspacePersonaID = UUID(uuidString: "32e76314-c0d0-4cd3-b0d7-b855ff7c46e0")!
    let prodDocWorkspacePersonaID = UUID(uuidString: "8caa5050-4ce8-456a-b9d4-bf1bf59c285c")!
    let foundingGroupTeamID = UUID(uuidString: "9a2f6e3c-3822-44fe-a53d-b84726c96d02")!
    let feedbackSquadID = UUID(uuidString: "1ad4749b-aeb8-48ed-95c9-bd9443fc83c1")!
    let samwiseFoundingGroupMembershipID = UUID(uuidString: "594f57f8-c3ac-4bcb-b042-f42c1805dc72")!
    let prodDocFoundingGroupMembershipID = UUID(uuidString: "74d0938f-342d-4527-9fc7-83d1f6bc430d")!
    let prodDocFeedbackSquadMembershipID = UUID(uuidString: "d4cfeb4f-75d2-4608-8e22-ac4ed6f6f71f")!
    let postID = UUID(uuidString: "24b4ee9b-1fc6-4a34-bfdb-4a4b2a50214c")!
    let threadID = UUID(uuidString: "4d7102ed-353d-4f83-b84f-28b44e707840")!
    let kickoffMessageID = UUID(uuidString: "7e7f5cb7-92d3-4644-96cc-bd76cdd2f27c")!
    let samwiseResponseMessageID = UUID(uuidString: "4dbcb7ad-dc65-406f-8ff4-c57aa5a4f8c8")!
    let samwiseActivationID = UUID(uuidString: "f69df562-f818-4c33-98ea-0cfbd3ca5cb4")!
    let samwiseAgentRunID = UUID(uuidString: "b0f17cb5-86a4-40e1-abac-30d3e435fe14")!
    let samwiseActivationEventID = UUID(uuidString: "c718d4f7-cdc2-4605-b7bb-7fb3018ff0c3")!
    let samwiseParticipantID = UUID(uuidString: "0d42b75b-e846-429a-bc11-d4f1b3fdc344")!
    let prodDocParticipantID = UUID(uuidString: "4f6c1500-7935-4d8c-bfd3-005ef0ca16fb")!
    let createdAt = Date(timeIntervalSince1970: 1_742_342_400)
    let samwiseJoinedAt = createdAt.addingTimeInterval(5)
    let prodDocJoinedAt = createdAt.addingTimeInterval(6)
    let kickoffAt = createdAt.addingTimeInterval(10)
    let samwiseResponseAt = createdAt.addingTimeInterval(20)

    let workspace = OrbitWorkspaceRecord(
      id: workspaceID,
      slug: "orbit",
      name: "Orbit",
      status: .active,
      createdAt: createdAt
    )
    let channel = OrbitChannelRecord(
      id: channelID,
      workspaceID: workspaceID,
      slug: "command-center",
      name: "Command Center",
      purpose: "Command center for persistent AI collaborators working with AJ.",
      status: .active,
      createdAt: createdAt
    )
    let workspacePersonas = [
      OrbitWorkspacePersonaRecord(
        id: samwiseWorkspacePersonaID,
        workspaceID: workspaceID,
        personaTemplateID: "samwise",
        displayName: "Samwise",
        defaultDirectiveOverrideID: "maintain-partner-sync-and-handoffs",
        status: .active,
        createdAt: createdAt
      ),
      OrbitWorkspacePersonaRecord(
        id: prodDocWorkspacePersonaID,
        workspaceID: workspaceID,
        personaTemplateID: "venture-product-steward",
        displayName: "ProdDoc",
        defaultDirectiveOverrideID: "run-venture-product-planning",
        status: .active,
        createdAt: createdAt.addingTimeInterval(1)
      ),
    ]
    let teams = [
      OrbitTeamRecord(
        id: foundingGroupTeamID,
        workspaceID: workspaceID,
        slug: "founding-group",
        name: "Founding Group",
        purpose: "Seeded team target for the first Orbit coordination slice.",
        createdAt: createdAt
      )
    ]
    let squads = [
      OrbitSquadRecord(
        id: feedbackSquadID,
        workspaceID: workspaceID,
        teamID: foundingGroupTeamID,
        slug: "command-center-feedback-squad",
        name: "Command Center Feedback Squad",
        purpose: "Focused feedback lane for the command-center collaboration surface.",
        createdAt: createdAt.addingTimeInterval(2)
      )
    ]
    let workspacePersonaMemberships = [
      OrbitWorkspacePersonaMembershipRecord(
        id: samwiseFoundingGroupMembershipID,
        workspacePersonaID: samwiseWorkspacePersonaID,
        teamID: foundingGroupTeamID,
        roleInGroup: "trusted-partner",
        createdAt: createdAt.addingTimeInterval(3)
      ),
      OrbitWorkspacePersonaMembershipRecord(
        id: prodDocFoundingGroupMembershipID,
        workspacePersonaID: prodDocWorkspacePersonaID,
        teamID: foundingGroupTeamID,
        roleInGroup: "product-steward",
        createdAt: createdAt.addingTimeInterval(4)
      ),
      OrbitWorkspacePersonaMembershipRecord(
        id: prodDocFeedbackSquadMembershipID,
        workspacePersonaID: prodDocWorkspacePersonaID,
        squadID: feedbackSquadID,
        roleInGroup: "reviewer",
        createdAt: createdAt.addingTimeInterval(5)
      ),
    ]
    let post = OrbitPostRecord(
      id: postID,
      workspaceID: workspaceID,
      channelID: channelID,
      postType: .meeting,
      createdByParticipantType: .user,
      createdByParticipantID: "aj",
      title: "Orbit MVP Checkpoint",
      status: .active,
      createdAt: createdAt
    )
    let thread = OrbitThreadRecord(
      id: threadID,
      postID: postID,
      status: .open,
      lastActivityAt: samwiseResponseAt,
      createdAt: createdAt
    )
    let kickoffMessage = OrbitMessageRecord(
      id: kickoffMessageID,
      postID: postID,
      threadID: threadID,
      authorType: .user,
      authorID: "aj",
      body: "Founding group, lock the next Orbit checkpoint.",
      messageFormat: .plainText,
      state: .persisted,
      createdAt: kickoffAt,
      updatedAt: kickoffAt
    )
    let samwiseResponseMessage = OrbitMessageRecord(
      id: samwiseResponseMessageID,
      postID: postID,
      threadID: threadID,
      authorType: .workspacePersona,
      authorID: samwiseWorkspacePersonaID.uuidString,
      replyToMessageID: kickoffMessageID,
      body: "Orbit is ready for the first checkpoint. Start with workspace, roster, conversation, and trace.",
      messageFormat: .markdown,
      state: .completed,
      createdAt: samwiseResponseAt,
      updatedAt: samwiseResponseAt
    )
    let samwiseActivation = OrbitPersonaActivationRecord(
      id: samwiseActivationID,
      initiatedByParticipantType: .user,
      initiatedByParticipantID: "aj",
      workspaceID: workspaceID,
      channelID: channelID,
      originPostID: postID,
      originThreadID: threadID,
      triggerMessageID: kickoffMessageID,
      addressedTargetKind: .team,
      addressedTargetReferenceID: "founding-group",
      resolvedWorkspacePersonaInstanceID: samwiseWorkspacePersonaID,
      responseMode: .lightweightMeeting,
      createdAt: samwiseResponseAt
    )
    let samwiseAgentRun = OrbitAgentRunRecord(
      id: samwiseAgentRunID,
      personaActivationID: samwiseActivationID,
      runnerKind: "local-bridge",
      status: .completed,
      startedAt: samwiseResponseAt,
      completedAt: samwiseResponseAt
    )
    let samwiseActivationEvent = OrbitPostEventRecord(
      id: samwiseActivationEventID,
      postID: postID,
      threadID: threadID,
      eventType: OrbitPhase1RealtimeEventCategory.activationResolved.rawValue,
      payloadJSON: encodedActivationPayload(
        activation: samwiseActivation,
        agentRun: samwiseAgentRun
      ),
      createdAt: samwiseResponseAt
    )

    return OrbitPhase1RoomBootstrap(
      workspace: workspace,
      channel: channel,
      workspacePersonas: workspacePersonas,
      teams: teams,
      squads: squads,
      workspacePersonaMemberships: workspacePersonaMemberships,
      post: post,
      thread: thread,
      seedMessages: [
        kickoffMessage,
        samwiseResponseMessage,
      ],
      postParticipants: [
        OrbitPostParticipantRecord(
          id: samwiseParticipantID,
          postID: postID,
          participantType: .workspacePersona,
          participantID: samwiseWorkspacePersonaID.uuidString,
          joinedAt: samwiseJoinedAt,
          participationMode: .active
        ),
        OrbitPostParticipantRecord(
          id: prodDocParticipantID,
          postID: postID,
          participantType: .workspacePersona,
          participantID: prodDocWorkspacePersonaID.uuidString,
          joinedAt: prodDocJoinedAt,
          participationMode: .active
        ),
      ],
      postEvents: [samwiseActivationEvent],
      personaActivations: [samwiseActivation],
      agentRuns: [samwiseAgentRun]
    )
  }
}

public struct OrbitCanonicalCommandCenterBootstrapper: Sendable {
  public typealias SnapshotLoader =
    @Sendable (String, String) async throws -> OrbitPhase1RoomSnapshot?
  public typealias RoomBootstrapper =
    @Sendable (OrbitPhase1RoomBootstrap) async throws -> Void

  public let room: OrbitPhase1RoomBootstrap
  public let loadSnapshot: SnapshotLoader
  public let bootstrapRoom: RoomBootstrapper

  public init(
    room: OrbitPhase1RoomBootstrap = OrbitCanonicalCommandCenterBootstrap.room,
    loadSnapshot: @escaping SnapshotLoader,
    bootstrapRoom: @escaping RoomBootstrapper
  ) {
    self.room = room
    self.loadSnapshot = loadSnapshot
    self.bootstrapRoom = bootstrapRoom
  }

  public func ensureBootstrapped() async throws {
    guard try await loadSnapshot(room.workspace.slug, room.channel.slug) == nil else {
      return
    }

    try await bootstrapRoom(room)
  }
}

public extension OrbitCanonicalCommandCenterBootstrapper {
  init(
    runtimeStore: OrbitPostgresRuntimeStore,
    room: OrbitPhase1RoomBootstrap = OrbitCanonicalCommandCenterBootstrap.room
  ) {
    self.init(
      room: room,
      loadSnapshot: { workspaceSlug, channelSlug in
        try await runtimeStore.loadRoomSnapshot(
          workspaceSlug: workspaceSlug,
          channelSlug: channelSlug
        )
      },
      bootstrapRoom: { bootstrap in
        try await runtimeStore.bootstrapRoom(bootstrap)
      }
    )
  }
}
