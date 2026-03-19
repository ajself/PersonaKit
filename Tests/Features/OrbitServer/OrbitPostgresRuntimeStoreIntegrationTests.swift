import Foundation
import Testing

@testable import OrbitServerRuntime

struct OrbitPostgresRuntimeStoreIntegrationTests {
  @Test
  func liveRuntimeStoreRoundTripWhenDatabaseEnvironmentIsAvailable() async throws {
    guard let configuration = integrationConfiguration() else {
      return
    }

    let store = OrbitPostgresRuntimeStore(configuration: configuration)
    let room = sampleRoomBootstrap()

    try await store.applyPhase1Schema()
    try await store.bootstrapRoom(room)

    let bootstrappedSnapshot = try await store.loadRoomSnapshot(
      workspaceSlug: room.workspace.slug,
      channelSlug: room.channel.slug
    )

    let message = OrbitMessageRecord(
      id: UUID(),
      postID: room.post.id,
      threadID: room.thread.id,
      authorType: .user,
      authorID: "aj",
      body: "Live Postgres append proof",
      messageFormat: .plainText,
      state: .persisted,
      createdAt: Date(timeIntervalSince1970: 1_742_342_520),
      updatedAt: Date(timeIntervalSince1970: 1_742_342_520)
    )
    let realtimeEvents = try OrbitPhase1RealtimeEventProjector.appendEvents(
      workspaceID: room.workspace.id,
      message: message,
      threadLastActivityAt: message.createdAt
    )

    try await store.appendMessage(
      workspaceID: room.workspace.id,
      message,
      realtimeEvents: realtimeEvents,
      threadLastActivityAt: message.createdAt
    )

    let loadedEvents = try await store.loadRealtimeEvents(
      workspaceID: room.workspace.id,
      after: nil
    )
    let updatedSnapshot = try await store.loadRoomSnapshot(
      workspaceSlug: room.workspace.slug,
      channelSlug: room.channel.slug
    )

    #expect(bootstrappedSnapshot?.messages.count == room.seedMessages.count)
    #expect(updatedSnapshot?.messages.count == room.seedMessages.count + 1)
    #expect(updatedSnapshot?.messages.last?.body == "Live Postgres append proof")
    #expect(loadedEvents.contains { $0.id == message.id && $0.category == .messageCreated })
  }

  private func integrationConfiguration() -> OrbitPostgresConfiguration? {
    let env = ProcessInfo.processInfo.environment

    guard
      let host = env["ORBIT_PG_HOST"],
      let username = env["ORBIT_PG_USER"],
      let password = env["ORBIT_PG_PASSWORD"],
      let database = env["ORBIT_PG_DATABASE"]
    else {
      return nil
    }

    let port = env["ORBIT_PG_PORT"].flatMap(Int.init) ?? 5432

    return OrbitPostgresConfiguration(
      host: host,
      port: port,
      username: username,
      password: password,
      database: database
    )
  }

  private func sampleRoomBootstrap() -> OrbitPhase1RoomBootstrap {
    let workspaceID = UUID()
    let channelID = UUID()
    let postID = UUID()
    let threadID = UUID()
    let baseDate = Date(timeIntervalSince1970: 1_742_342_400)
    let slugSuffix = UUID().uuidString.lowercased()

    return OrbitPhase1RoomBootstrap(
      workspace: OrbitWorkspaceRecord(
        id: workspaceID,
        slug: "orbit-integration-\(slugSuffix)",
        name: "Orbit Integration",
        status: .active,
        createdAt: baseDate
      ),
      channel: OrbitChannelRecord(
        id: channelID,
        workspaceID: workspaceID,
        slug: "command-center-\(slugSuffix)",
        name: "Command Center",
        purpose: "Integration test room",
        status: .active,
        createdAt: baseDate
      ),
      post: OrbitPostRecord(
        id: postID,
        workspaceID: workspaceID,
        channelID: channelID,
        postType: .message,
        createdByParticipantType: .user,
        createdByParticipantID: "aj",
        title: "Integration room",
        status: .active,
        createdAt: baseDate
      ),
      thread: OrbitThreadRecord(
        id: threadID,
        postID: postID,
        status: .open,
        lastActivityAt: baseDate,
        createdAt: baseDate
      ),
      seedMessages: [
        OrbitMessageRecord(
          id: UUID(),
          postID: postID,
          threadID: threadID,
          authorType: .user,
          authorID: "aj",
          body: "Integration bootstrap",
          messageFormat: .plainText,
          state: .persisted,
          createdAt: baseDate,
          updatedAt: baseDate
        )
      ]
    )
  }
}
