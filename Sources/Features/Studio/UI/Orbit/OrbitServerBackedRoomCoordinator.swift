import Foundation
import OrbitServerRuntime

struct OrbitServerBackedRoomCoordinator {
  private(set) var roomState = OrbitServerBackedRoomState()

  mutating func connect(
    scope: OrbitPhase1RealtimeSubscriptionScope,
    transport: some OrbitPhase1RealtimeTransportServing
  ) async throws {
    let response = try await transport.connect(
      request: OrbitPhase1RealtimeConnectRequest(scope: scope)
    )

    try roomState.apply(response)
  }

  mutating func connect(
    scope: OrbitPhase1RealtimeSubscriptionScope,
    client: OrbitServerBackedRoomClient
  ) async throws {
    let response = try await client.connect(scope: scope)
    try roomState.apply(response)
  }

  mutating func poll(
    transport: some OrbitPhase1RealtimeTransportServing
  ) async throws {
    guard let session = roomState.session else {
      return
    }

    let response = try await transport.poll(
      request: OrbitPhase1RealtimePollRequest(session: session)
    )

    try roomState.apply(response)
  }

  mutating func poll(
    client: OrbitServerBackedRoomClient
  ) async throws {
    guard let session = roomState.session else {
      return
    }

    let response = try await client.poll(session: session)
    try roomState.apply(response)
  }

  mutating func appendUserMessage(
    scope: OrbitPhase1RealtimeSubscriptionScope,
    authorID: String,
    body: String,
    client: OrbitServerBackedRoomClient
  ) async throws {
    _ = try await client.appendUserMessage(
      OrbitPhase1AppendUserMessageRequest(
        workspaceSlug: scope.workspaceSlug,
        channelSlug: scope.channelSlug,
        authorID: authorID,
        body: body
      )
    )

    try await connect(scope: scope, client: client)
  }
}
