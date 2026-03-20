import Foundation
import Testing
import Vapor
import XCTVapor

@testable import OrbitServer
@testable import OrbitServerGateway
@testable import OrbitServerRuntime

struct OrbitServerApplicationTests {
  @Test
  func configureRegistersHealthAndGatewayRoutes() async throws {
    let configuration = try OrbitServerConfiguration(
      environment: [
        "ORBIT_SERVER_HOST": "0.0.0.0",
        "ORBIT_SERVER_PORT": "9090",
        "ORBIT_PG_HOST": "127.0.0.1",
        "ORBIT_PG_USER": "orbit",
        "ORBIT_PG_PASSWORD": "secret",
        "ORBIT_PG_DATABASE": "orbit",
      ]
    )
    let snapshot = sampleSnapshot()
    let app = try await Application.make(.testing)

    do {
      OrbitServerApplication.configure(
        app: app,
        configuration: configuration,
        transport: StubTransport(snapshot: snapshot)
      )

      #expect(app.http.server.configuration.hostname == "0.0.0.0")
      #expect(app.http.server.configuration.port == 9090)

      try XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
        try app.test(.GET, "/healthz", afterResponse: { response in
          #expect(response.status == .ok)
        })

        try app.test(.POST, "/api/orbit/realtime/connect", beforeRequest: { request in
          try request.content.encode(
            OrbitGatewayConnectRequest(
              workspaceSlug: "orbit",
              channelSlug: "command-center"
            )
          )
        }, afterResponse: { response in
          #expect(response.status == .ok)
          let payload = try response.content.decode(OrbitGatewayTransportResponse.self)
          #expect(payload.kind == "bootstrap")
          #expect(payload.snapshot?.workspaceSlug == "orbit")
        })
      }
    } catch {
      try? await app.asyncShutdown()
      throw error
    }

    try await app.asyncShutdown()
  }

  private func sampleSnapshot() -> OrbitPhase1RealtimeSnapshot {
    let bootstrap = OrbitCanonicalCommandCenterBootstrap.room
    let realtimeEvents = try! OrbitPhase1RealtimeEventProjector.bootstrapEvents(
      for: bootstrap
    )
    let envelopes = realtimeEvents.map { event in
      OrbitPhase1RealtimeEventEnvelope(
        id: event.id,
        workspaceID: event.workspaceID,
        postID: event.postID,
        threadID: event.threadID,
        category: event.category,
        createdAt: event.createdAt,
        payloadJSON: event.payloadJSON
      )
    }

    return OrbitPhase1RealtimeSnapshot(
      room: OrbitPhase1RoomSnapshot(
        workspace: bootstrap.workspace,
        channel: bootstrap.channel,
        workspacePersonas: bootstrap.workspacePersonas,
        post: bootstrap.post,
        thread: bootstrap.thread,
        messages: bootstrap.seedMessages,
        postParticipants: bootstrap.postParticipants,
        postEvents: bootstrap.postEvents,
        personaActivations: bootstrap.personaActivations,
        agentRuns: bootstrap.agentRuns
      ),
      replayCursor: OrbitPhase1RealtimeContract.makeReplayCursor(
        workspaceID: bootstrap.workspace.id,
        from: envelopes
      )
    )
  }
}

private struct StubTransport: OrbitRealtimeTransportHandling {
  let snapshot: OrbitPhase1RealtimeSnapshot

  func connect(
    request: OrbitPhase1RealtimeConnectRequest
  ) async throws -> OrbitPhase1RealtimeTransportResponse {
    .bootstrap(
      OrbitPhase1RealtimeSession(
        scope: request.scope,
        replayCursor: snapshot.replayCursor,
        connectedAt: snapshot.room.thread.lastActivityAt,
        lastInteractionAt: snapshot.room.thread.lastActivityAt
      ),
      snapshot
    )
  }

  func poll(
    request: OrbitPhase1RealtimePollRequest
  ) async throws -> OrbitPhase1RealtimeTransportResponse {
    .noChange(request.session)
  }
}
