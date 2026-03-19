import Foundation
import OrbitServerRuntime
import Vapor

public struct OrbitGatewayConnectRequest: Content, Equatable {
  public let workspaceSlug: String
  public let channelSlug: String
  public let cursorWorkspaceID: UUID?
  public let cursorEventID: UUID?
  public let cursorEventCreatedAt: Date?

  public init(
    workspaceSlug: String,
    channelSlug: String,
    cursorWorkspaceID: UUID? = nil,
    cursorEventID: UUID? = nil,
    cursorEventCreatedAt: Date? = nil
  ) {
    self.workspaceSlug = workspaceSlug
    self.channelSlug = channelSlug
    self.cursorWorkspaceID = cursorWorkspaceID
    self.cursorEventID = cursorEventID
    self.cursorEventCreatedAt = cursorEventCreatedAt
  }

  var transportRequest: OrbitPhase1RealtimeConnectRequest {
    OrbitPhase1RealtimeConnectRequest(
      scope: OrbitPhase1RealtimeSubscriptionScope(
        workspaceSlug: workspaceSlug,
        channelSlug: channelSlug
      ),
      cursor: cursorEventID.flatMap { eventID in
        guard let cursorWorkspaceID else {
          return nil
        }

        return OrbitPhase1ReplayCursor(
          workspaceID: cursorWorkspaceID,
          lastEventID: eventID,
          lastEventCreatedAt: cursorEventCreatedAt
        )
      }
    )
  }
}

public struct OrbitGatewayPollRequest: Content, Equatable {
  public let session: OrbitGatewaySessionPayload

  public init(
    session: OrbitGatewaySessionPayload
  ) {
    self.session = session
  }

  var transportRequest: OrbitPhase1RealtimePollRequest {
    OrbitPhase1RealtimePollRequest(session: session.runtimeSession)
  }
}

public struct OrbitGatewaySessionPayload: Content, Equatable {
  public let workspaceSlug: String
  public let channelSlug: String
  public let workspaceID: UUID
  public let cursorEventID: UUID?
  public let cursorEventCreatedAt: Date?
  public let connectedAt: Date
  public let lastInteractionAt: Date

  public init(
    workspaceSlug: String,
    channelSlug: String,
    workspaceID: UUID,
    cursorEventID: UUID?,
    cursorEventCreatedAt: Date?,
    connectedAt: Date,
    lastInteractionAt: Date
  ) {
    self.workspaceSlug = workspaceSlug
    self.channelSlug = channelSlug
    self.workspaceID = workspaceID
    self.cursorEventID = cursorEventID
    self.cursorEventCreatedAt = cursorEventCreatedAt
    self.connectedAt = connectedAt
    self.lastInteractionAt = lastInteractionAt
  }

  init(
    session: OrbitPhase1RealtimeSession
  ) {
    self.workspaceSlug = session.scope.workspaceSlug
    self.channelSlug = session.scope.channelSlug
    self.workspaceID = session.replayCursor.workspaceID
    self.cursorEventID = session.replayCursor.lastEventID
    self.cursorEventCreatedAt = session.replayCursor.lastEventCreatedAt
    self.connectedAt = session.connectedAt
    self.lastInteractionAt = session.lastInteractionAt
  }

  var runtimeSession: OrbitPhase1RealtimeSession {
    OrbitPhase1RealtimeSession(
      scope: OrbitPhase1RealtimeSubscriptionScope(
        workspaceSlug: workspaceSlug,
        channelSlug: channelSlug
      ),
      replayCursor: OrbitPhase1ReplayCursor(
        workspaceID: workspaceID,
        lastEventID: cursorEventID,
        lastEventCreatedAt: cursorEventCreatedAt
      ),
      connectedAt: connectedAt,
      lastInteractionAt: lastInteractionAt
    )
  }
}

public struct OrbitGatewayTransportResponse: Content, Equatable {
  public let response: OrbitPhase1RealtimeTransportResponse
  public let kind: String
  public let session: OrbitGatewaySessionPayload
  public let snapshot: OrbitGatewaySnapshotPayload?
  public let events: [OrbitGatewayEventPayload]
  public let resyncReason: String?

  public init(
    response: OrbitPhase1RealtimeTransportResponse
  ) {
    self.response = response
    switch response {
    case .bootstrap(let session, let snapshot):
      self.kind = "bootstrap"
      self.session = OrbitGatewaySessionPayload(session: session)
      self.snapshot = OrbitGatewaySnapshotPayload(snapshot: snapshot)
      self.events = []
      self.resyncReason = nil
    case .replay(let session, let events):
      self.kind = "replay"
      self.session = OrbitGatewaySessionPayload(session: session)
      self.snapshot = nil
      self.events = events.map(OrbitGatewayEventPayload.init)
      self.resyncReason = nil
    case .noChange(let session):
      self.kind = "no-change"
      self.session = OrbitGatewaySessionPayload(session: session)
      self.snapshot = nil
      self.events = []
      self.resyncReason = nil
    case .resync(let session, let snapshot, let reason):
      self.kind = "resync"
      self.session = OrbitGatewaySessionPayload(session: session)
      self.snapshot = OrbitGatewaySnapshotPayload(snapshot: snapshot)
      self.events = []
      self.resyncReason = reason.rawValue
    }
  }
}

public struct OrbitGatewaySnapshotPayload: Content, Equatable {
  public let workspaceSlug: String
  public let workspaceName: String
  public let channelSlug: String
  public let channelName: String
  public let postID: UUID
  public let threadID: UUID
  public let messageCount: Int
  public let replayCursor: OrbitGatewayCursorPayload

  public init(
    snapshot: OrbitPhase1RealtimeSnapshot
  ) {
    self.workspaceSlug = snapshot.room.workspace.slug
    self.workspaceName = snapshot.room.workspace.name
    self.channelSlug = snapshot.room.channel.slug
    self.channelName = snapshot.room.channel.name
    self.postID = snapshot.room.post.id
    self.threadID = snapshot.room.thread.id
    self.messageCount = snapshot.room.messages.count
    self.replayCursor = OrbitGatewayCursorPayload(cursor: snapshot.replayCursor)
  }
}

public struct OrbitGatewayCursorPayload: Content, Equatable {
  public let workspaceID: UUID
  public let lastEventID: UUID?
  public let lastEventCreatedAt: Date?

  public init(
    cursor: OrbitPhase1ReplayCursor
  ) {
    self.workspaceID = cursor.workspaceID
    self.lastEventID = cursor.lastEventID
    self.lastEventCreatedAt = cursor.lastEventCreatedAt
  }
}

public struct OrbitGatewayEventPayload: Content, Equatable {
  public let id: UUID
  public let category: String
  public let workspaceID: UUID
  public let postID: UUID?
  public let threadID: UUID?
  public let createdAt: Date
  public let payloadJSON: String

  public init(
    _ event: OrbitPhase1RealtimeEventEnvelope
  ) {
    self.id = event.id
    self.category = event.category.rawValue
    self.workspaceID = event.workspaceID
    self.postID = event.postID
    self.threadID = event.threadID
    self.createdAt = event.createdAt
    self.payloadJSON = event.payloadJSON
  }
}

public struct OrbitGatewayAppendMessageRequest: Content, Equatable {
  public let workspaceSlug: String
  public let channelSlug: String
  public let authorID: String
  public let body: String

  public init(
    workspaceSlug: String,
    channelSlug: String,
    authorID: String,
    body: String
  ) {
    self.workspaceSlug = workspaceSlug
    self.channelSlug = channelSlug
    self.authorID = authorID
    self.body = body
  }

  var runtimeRequest: OrbitPhase1AppendUserMessageRequest {
    OrbitPhase1AppendUserMessageRequest(
      workspaceSlug: workspaceSlug,
      channelSlug: channelSlug,
      authorID: authorID,
      body: body
    )
  }
}

public struct OrbitGatewayAppendMessageResponse: Content, Equatable {
  public let result: OrbitPhase1AppendUserMessageResult
  public let workspaceSlug: String
  public let channelSlug: String
  public let messageID: UUID
  public let messageCount: Int
  public let threadID: UUID

  public init(
    result: OrbitPhase1AppendUserMessageResult
  ) {
    self.result = result
    self.workspaceSlug = result.snapshot.workspace.slug
    self.channelSlug = result.snapshot.channel.slug
    self.messageID = result.message.id
    self.messageCount = result.snapshot.messages.count
    self.threadID = result.snapshot.thread.id
  }
}

public struct OrbitGatewayAppendSystemMessageRequest: Content, Equatable {
  public let workspaceSlug: String
  public let channelSlug: String
  public let body: String
  public let replyToMessageID: UUID?

  public init(
    workspaceSlug: String,
    channelSlug: String,
    body: String,
    replyToMessageID: UUID? = nil
  ) {
    self.workspaceSlug = workspaceSlug
    self.channelSlug = channelSlug
    self.body = body
    self.replyToMessageID = replyToMessageID
  }

  var runtimeRequest: OrbitPhase1AppendSystemMessageRequest {
    OrbitPhase1AppendSystemMessageRequest(
      workspaceSlug: workspaceSlug,
      channelSlug: channelSlug,
      body: body,
      replyToMessageID: replyToMessageID
    )
  }
}

public struct OrbitGatewayAppendSystemMessageResponse: Content, Equatable {
  public let result: OrbitPhase1AppendSystemMessageResult
  public let workspaceSlug: String
  public let channelSlug: String
  public let messageID: UUID
  public let messageCount: Int
  public let threadID: UUID

  public init(
    result: OrbitPhase1AppendSystemMessageResult
  ) {
    self.result = result
    self.workspaceSlug = result.snapshot.workspace.slug
    self.channelSlug = result.snapshot.channel.slug
    self.messageID = result.message.id
    self.messageCount = result.snapshot.messages.count
    self.threadID = result.snapshot.thread.id
  }
}

public struct OrbitGatewayAppendCollaboratorResponseRequest: Content, Equatable {
  public let workspaceSlug: String
  public let channelSlug: String
  public let workspacePersonaID: UUID
  public let initiatedByParticipantID: String
  public let triggerMessageID: UUID
  public let addressedTargetKind: String
  public let addressedTargetReferenceID: String
  public let responseMode: String
  public let body: String
  public let contract: OrbitPhase1ResolvedContractPayload?
  public let runnerKind: String

  public init(
    workspaceSlug: String,
    channelSlug: String,
    workspacePersonaID: UUID,
    initiatedByParticipantID: String,
    triggerMessageID: UUID,
    addressedTargetKind: String,
    addressedTargetReferenceID: String,
    responseMode: String,
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

  var runtimeRequest: OrbitPhase1AppendCollaboratorResponseRequest? {
    guard
      let targetKind = OrbitAddressedTargetKind(rawValue: addressedTargetKind),
      let responseMode = OrbitCanonicalResponseMode(rawValue: responseMode)
    else {
      return nil
    }

    return OrbitPhase1AppendCollaboratorResponseRequest(
      workspaceSlug: workspaceSlug,
      channelSlug: channelSlug,
      workspacePersonaID: workspacePersonaID,
      initiatedByParticipantID: initiatedByParticipantID,
      triggerMessageID: triggerMessageID,
      addressedTargetKind: targetKind,
      addressedTargetReferenceID: addressedTargetReferenceID,
      responseMode: responseMode,
      body: body,
      contract: contract,
      runnerKind: runnerKind
    )
  }
}

public struct OrbitGatewayAppendCollaboratorResponse: Content, Equatable {
  public let result: OrbitPhase1AppendCollaboratorResponseResult
  public let workspaceSlug: String
  public let channelSlug: String
  public let messageID: UUID
  public let activationID: UUID
  public let agentRunID: UUID
  public let messageCount: Int

  public init(
    result: OrbitPhase1AppendCollaboratorResponseResult
  ) {
    self.result = result
    self.workspaceSlug = result.snapshot.workspace.slug
    self.channelSlug = result.snapshot.channel.slug
    self.messageID = result.message.id
    self.activationID = result.activation.id
    self.agentRunID = result.agentRun.id
    self.messageCount = result.snapshot.messages.count
  }
}

public struct OrbitGatewayAppendActivationFailureRequest: Content, Equatable {
  public let workspaceSlug: String
  public let channelSlug: String
  public let initiatedByParticipantID: String
  public let triggerMessageID: UUID
  public let failure: OrbitPhase1ActivationFailurePayload

  public init(
    workspaceSlug: String,
    channelSlug: String,
    initiatedByParticipantID: String,
    triggerMessageID: UUID,
    failure: OrbitPhase1ActivationFailurePayload
  ) {
    self.workspaceSlug = workspaceSlug
    self.channelSlug = channelSlug
    self.initiatedByParticipantID = initiatedByParticipantID
    self.triggerMessageID = triggerMessageID
    self.failure = failure
  }

  var runtimeRequest: OrbitPhase1AppendActivationFailureRequest {
    OrbitPhase1AppendActivationFailureRequest(
      workspaceSlug: workspaceSlug,
      channelSlug: channelSlug,
      initiatedByParticipantID: initiatedByParticipantID,
      triggerMessageID: triggerMessageID,
      failure: failure
    )
  }
}

public struct OrbitGatewayAppendActivationFailureResponse: Content, Equatable {
  public let result: OrbitPhase1AppendActivationFailureResult
  public let workspaceSlug: String
  public let channelSlug: String
  public let systemMessageID: UUID
  public let postEventID: UUID
  public let messageCount: Int
  public let threadID: UUID

  public init(
    result: OrbitPhase1AppendActivationFailureResult
  ) {
    self.result = result
    self.workspaceSlug = result.snapshot.workspace.slug
    self.channelSlug = result.snapshot.channel.slug
    self.systemMessageID = result.systemMessage.id
    self.postEventID = result.postEvent.id
    self.messageCount = result.snapshot.messages.count
    self.threadID = result.snapshot.thread.id
  }
}

public struct OrbitGatewayWebSocketConnectQuery: Equatable, Sendable {
  public let workspaceSlug: String
  public let channelSlug: String
  public let cursorWorkspaceID: UUID?
  public let cursorEventID: UUID?
  public let cursorEventCreatedAt: Date?

  public init(
    workspaceSlug: String,
    channelSlug: String,
    cursorWorkspaceID: UUID? = nil,
    cursorEventID: UUID? = nil,
    cursorEventCreatedAt: Date? = nil
  ) {
    self.workspaceSlug = workspaceSlug
    self.channelSlug = channelSlug
    self.cursorWorkspaceID = cursorWorkspaceID
    self.cursorEventID = cursorEventID
    self.cursorEventCreatedAt = cursorEventCreatedAt
  }

  var connectRequest: OrbitPhase1RealtimeConnectRequest {
    OrbitGatewayConnectRequest(
      workspaceSlug: workspaceSlug,
      channelSlug: channelSlug,
      cursorWorkspaceID: cursorWorkspaceID,
      cursorEventID: cursorEventID,
      cursorEventCreatedAt: cursorEventCreatedAt
    ).transportRequest
  }
}

public struct OrbitGatewayWebSocketClientMessage: Content, Equatable {
  public enum Kind: String, Content {
    case bootstrap
    case poll
  }

  public let kind: Kind
  public let session: OrbitGatewaySessionPayload?

  public init(
    kind: Kind,
    session: OrbitGatewaySessionPayload? = nil
  ) {
    self.kind = kind
    self.session = session
  }

  var transportRequest: OrbitPhase1RealtimePollRequest? {
    guard let session else {
      return nil
    }

    return OrbitPhase1RealtimePollRequest(session: session.runtimeSession)
  }
}
