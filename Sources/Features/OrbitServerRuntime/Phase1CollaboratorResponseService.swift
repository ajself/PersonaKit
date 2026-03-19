import Foundation

public struct OrbitPhase1AppendCollaboratorResponseRequest: Equatable, Sendable {
  public let workspaceSlug: String
  public let channelSlug: String
  public let workspacePersonaID: UUID
  public let initiatedByParticipantID: String
  public let triggerMessageID: UUID
  public let addressedTargetKind: OrbitAddressedTargetKind
  public let addressedTargetReferenceID: String
  public let responseMode: OrbitCanonicalResponseMode
  public let body: String
  public let contract: OrbitPhase1ResolvedContractPayload?
  public let runnerKind: String

  public init(
    workspaceSlug: String,
    channelSlug: String,
    workspacePersonaID: UUID,
    initiatedByParticipantID: String,
    triggerMessageID: UUID,
    addressedTargetKind: OrbitAddressedTargetKind,
    addressedTargetReferenceID: String,
    responseMode: OrbitCanonicalResponseMode,
    body: String,
    contract: OrbitPhase1ResolvedContractPayload? = nil,
    runnerKind: String = "local-bridge"
  ) {
    self.workspaceSlug = workspaceSlug
    self.channelSlug = channelSlug
    self.workspacePersonaID = workspacePersonaID
    self.initiatedByParticipantID = initiatedByParticipantID
    self.triggerMessageID = triggerMessageID
    self.addressedTargetKind = addressedTargetKind
    self.addressedTargetReferenceID = addressedTargetReferenceID
    self.responseMode = responseMode
    self.body = body
    self.contract = contract
    self.runnerKind = runnerKind
  }
}

public struct OrbitPhase1AppendCollaboratorResponseResult: Equatable, Sendable {
  public let snapshot: OrbitPhase1RoomSnapshot
  public let message: OrbitMessageRecord
  public let activation: OrbitPersonaActivationRecord
  public let agentRun: OrbitAgentRunRecord

  public init(
    snapshot: OrbitPhase1RoomSnapshot,
    message: OrbitMessageRecord,
    activation: OrbitPersonaActivationRecord,
    agentRun: OrbitAgentRunRecord
  ) {
    self.snapshot = snapshot
    self.message = message
    self.activation = activation
    self.agentRun = agentRun
  }
}

public enum OrbitPhase1CollaboratorResponseServiceError: Error, Equatable {
  case roomNotFound
  case workspacePersonaNotFound
  case triggerMessageNotFound
}

public struct OrbitPhase1CollaboratorResponseService: Sendable {
  public typealias SnapshotLoader = @Sendable (String, String) async throws -> OrbitPhase1RoomSnapshot?
  public typealias ResponseAppender = @Sendable (UUID, OrbitMessageRecord, OrbitPersonaActivationRecord, OrbitAgentRunRecord, OrbitPostEventRecord, [OrbitRealtimeEventRecord], Date) async throws -> Void

  public let loadSnapshot: SnapshotLoader
  public let appendResponse: ResponseAppender
  public let now: @Sendable () -> Date
  public let makeMessageID: @Sendable () -> UUID
  public let makeActivationID: @Sendable () -> UUID
  public let makeAgentRunID: @Sendable () -> UUID
  public let makePostEventID: @Sendable () -> UUID

  public init(
    loadSnapshot: @escaping SnapshotLoader,
    appendResponse: @escaping ResponseAppender,
    now: @escaping @Sendable () -> Date = Date.init,
    makeMessageID: @escaping @Sendable () -> UUID = UUID.init,
    makeActivationID: @escaping @Sendable () -> UUID = UUID.init,
    makeAgentRunID: @escaping @Sendable () -> UUID = UUID.init,
    makePostEventID: @escaping @Sendable () -> UUID = UUID.init
  ) {
    self.loadSnapshot = loadSnapshot
    self.appendResponse = appendResponse
    self.now = now
    self.makeMessageID = makeMessageID
    self.makeActivationID = makeActivationID
    self.makeAgentRunID = makeAgentRunID
    self.makePostEventID = makePostEventID
  }

  public func appendCollaboratorResponse(
    _ request: OrbitPhase1AppendCollaboratorResponseRequest
  ) async throws -> OrbitPhase1AppendCollaboratorResponseResult {
    guard let snapshot = try await loadSnapshot(request.workspaceSlug, request.channelSlug) else {
      throw OrbitPhase1CollaboratorResponseServiceError.roomNotFound
    }

    guard let workspacePersona = snapshot.workspacePersonas.first(where: { $0.id == request.workspacePersonaID }) else {
      throw OrbitPhase1CollaboratorResponseServiceError.workspacePersonaNotFound
    }

    guard snapshot.messages.contains(where: { $0.id == request.triggerMessageID }) else {
      throw OrbitPhase1CollaboratorResponseServiceError.triggerMessageNotFound
    }

    let timestamp = now()
    let message = OrbitMessageRecord(
      id: makeMessageID(),
      postID: snapshot.post.id,
      threadID: snapshot.thread.id,
      authorType: .workspacePersona,
      authorID: workspacePersona.id.uuidString,
      replyToMessageID: request.triggerMessageID,
      body: request.body,
      messageFormat: .markdown,
      state: .completed,
      createdAt: timestamp,
      updatedAt: timestamp
    )
    let activation = OrbitPersonaActivationRecord(
      id: makeActivationID(),
      initiatedByParticipantType: .user,
      initiatedByParticipantID: request.initiatedByParticipantID,
      workspaceID: snapshot.workspace.id,
      channelID: snapshot.channel.id,
      originPostID: snapshot.post.id,
      originThreadID: snapshot.thread.id,
      triggerMessageID: request.triggerMessageID,
      addressedTargetKind: request.addressedTargetKind,
      addressedTargetReferenceID: request.addressedTargetReferenceID,
      resolvedWorkspacePersonaInstanceID: workspacePersona.id,
      responseMode: request.responseMode,
      createdAt: timestamp
    )
    let agentRun = OrbitAgentRunRecord(
      id: makeAgentRunID(),
      personaActivationID: activation.id,
      runnerKind: request.runnerKind,
      status: .completed,
      startedAt: timestamp,
      completedAt: timestamp
    )
    let postEvent = OrbitPostEventRecord(
      id: makePostEventID(),
      postID: snapshot.post.id,
      threadID: snapshot.thread.id,
      eventType: OrbitPhase1RealtimeEventCategory.activationResolved.rawValue,
      payloadJSON: try OrbitPhase1RealtimeEventPayloadCodec.encode(
        OrbitPhase1ActivationEventPayload(
          activation: activation,
          agentRun: agentRun,
          contract: request.contract
        )
      ),
      createdAt: timestamp
    )
    let realtimeEvents = try OrbitPhase1RealtimeEventProjector.collaboratorResponseEvents(
      workspaceID: snapshot.workspace.id,
      message: message,
      activation: activation,
      agentRun: agentRun,
      contract: request.contract,
      threadLastActivityAt: timestamp
    )

    try await appendResponse(
      snapshot.workspace.id,
      message,
      activation,
      agentRun,
      postEvent,
      realtimeEvents,
      timestamp
    )

    let updatedSnapshot = OrbitPhase1RoomSnapshot(
      workspace: snapshot.workspace,
      channel: snapshot.channel,
      workspacePersonas: snapshot.workspacePersonas,
      post: snapshot.post,
      thread: OrbitThreadRecord(
        id: snapshot.thread.id,
        postID: snapshot.thread.postID,
        status: snapshot.thread.status,
        lastActivityAt: timestamp,
        createdAt: snapshot.thread.createdAt,
        closedAt: snapshot.thread.closedAt
      ),
      messages: snapshot.messages + [message],
      postParticipants: snapshot.postParticipants,
      postEvents: snapshot.postEvents + [postEvent],
      personaActivations: snapshot.personaActivations + [activation],
      agentRuns: snapshot.agentRuns + [agentRun]
    )

    return OrbitPhase1AppendCollaboratorResponseResult(
      snapshot: updatedSnapshot,
      message: message,
      activation: activation,
      agentRun: agentRun
    )
  }
}

public protocol OrbitPhase1CollaboratorResponseServing: Sendable {
  func appendCollaboratorResponse(
    _ request: OrbitPhase1AppendCollaboratorResponseRequest
  ) async throws -> OrbitPhase1AppendCollaboratorResponseResult
}

public extension OrbitPhase1CollaboratorResponseService {
  init(
    runtimeStore: OrbitPostgresRuntimeStore,
    now: @escaping @Sendable () -> Date = Date.init,
    makeMessageID: @escaping @Sendable () -> UUID = UUID.init,
    makeActivationID: @escaping @Sendable () -> UUID = UUID.init,
    makeAgentRunID: @escaping @Sendable () -> UUID = UUID.init,
    makePostEventID: @escaping @Sendable () -> UUID = UUID.init
  ) {
    self.init(
      loadSnapshot: { workspaceSlug, channelSlug in
        try await runtimeStore.loadRoomSnapshot(
          workspaceSlug: workspaceSlug,
          channelSlug: channelSlug
        )
      },
      appendResponse: { workspaceID, message, activation, agentRun, postEvent, realtimeEvents, timestamp in
        try await runtimeStore.appendCollaboratorResponse(
          workspaceID: workspaceID,
          message,
          activation: activation,
          agentRun: agentRun,
          postEvent: postEvent,
          realtimeEvents: realtimeEvents,
          threadLastActivityAt: timestamp
        )
      },
      now: now,
      makeMessageID: makeMessageID,
      makeActivationID: makeActivationID,
      makeAgentRunID: makeAgentRunID,
      makePostEventID: makePostEventID
    )
  }
}

extension OrbitPhase1CollaboratorResponseService: OrbitPhase1CollaboratorResponseServing {}
