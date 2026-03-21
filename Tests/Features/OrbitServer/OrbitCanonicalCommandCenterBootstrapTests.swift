import Foundation
import Testing

@testable import OrbitServerRuntime
@testable import StudioFeatures

struct OrbitCanonicalCommandCenterBootstrapTests {
  @Test
  func canonicalBootstrapProjectsIntoBelievableOrbitWorkspace() throws {
    let bootstrap = OrbitCanonicalCommandCenterBootstrap.room
    let snapshot = try makeRealtimeSnapshot(from: bootstrap)

    let workspace = OrbitServerRoomProjection.workspace(from: snapshot)

    #expect(workspace.id == "orbit")
    #expect(workspace.displayName == "Orbit")
    #expect(
      workspace.purpose == "Command center for persistent AI collaborators working with AJ."
    )
    #expect(workspace.participants.map(\.id).sorted() == ["aj", "proddoc", "samwise"])
    #expect(workspace.teams.map(\.slug) == ["founding-group"])
    #expect(workspace.squads.map(\.slug) == ["command-center-feedback-squad"])
    #expect(workspace.workspacePersonaMemberships.count == 3)
    #expect(workspace.activeThread?.title == "Orbit MVP Checkpoint")
    #expect(workspace.activeThread?.interactionMode == .lightweightMeeting)
    #expect(workspace.activeThread?.messages.count == 2)
    #expect(workspace.activationRecords.count == 1)
    #expect(workspace.activationContractSnapshots.count == 1)
  }

  @Test
  func bootstrapperSeedsCanonicalRoomWhenRoomIsMissing() async throws {
    let recorder = BootstrapRecorder()
    let bootstrapper = OrbitCanonicalCommandCenterBootstrapper(
      loadSnapshot: { _, _ in
        await recorder.recordLoad()
        return nil
      },
      bootstrapRoom: { room in
        await recorder.recordBootstrap(room)
      }
    )

    try await bootstrapper.ensureBootstrapped()

    #expect(await recorder.loadCount == 1)
    #expect(await recorder.bootstrappedRooms == [OrbitCanonicalCommandCenterBootstrap.room])
  }

  @Test
  func bootstrapperSkipsSeedingWhenCanonicalRoomAlreadyExists() async throws {
    let recorder = BootstrapRecorder()
    let existingRoom = makeRoomSnapshot(from: OrbitCanonicalCommandCenterBootstrap.room)
    let bootstrapper = OrbitCanonicalCommandCenterBootstrapper(
      loadSnapshot: { _, _ in
        await recorder.recordLoad()
        return existingRoom
      },
      bootstrapRoom: { room in
        await recorder.recordBootstrap(room)
      }
    )

    try await bootstrapper.ensureBootstrapped()

    #expect(await recorder.loadCount == 1)
    #expect(await recorder.bootstrappedRooms.isEmpty)
  }

  private func makeRealtimeSnapshot(
    from bootstrap: OrbitPhase1RoomBootstrap
  ) throws -> OrbitPhase1RealtimeSnapshot {
    let realtimeEvents = try OrbitPhase1RealtimeEventProjector.bootstrapEvents(for: bootstrap)
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
      room: makeRoomSnapshot(from: bootstrap),
      replayCursor: OrbitPhase1RealtimeContract.makeReplayCursor(
        workspaceID: bootstrap.workspace.id,
        from: envelopes
      )
    )
  }

  private func makeRoomSnapshot(
    from bootstrap: OrbitPhase1RoomBootstrap
  ) -> OrbitPhase1RoomSnapshot {
    OrbitPhase1RoomSnapshot(
      workspace: bootstrap.workspace,
      channel: bootstrap.channel,
      workspacePersonas: bootstrap.workspacePersonas,
      teams: bootstrap.teams,
      squads: bootstrap.squads,
      workspacePersonaMemberships: bootstrap.workspacePersonaMemberships,
      post: bootstrap.post,
      thread: bootstrap.thread,
      messages: bootstrap.seedMessages,
      postParticipants: bootstrap.postParticipants,
      postEvents: bootstrap.postEvents,
      personaActivations: bootstrap.personaActivations,
      agentRuns: bootstrap.agentRuns
    )
  }
}

private actor BootstrapRecorder {
  private(set) var loadCount = 0
  private(set) var bootstrappedRooms = [OrbitPhase1RoomBootstrap]()

  func recordLoad() {
    loadCount += 1
  }

  func recordBootstrap(
    _ room: OrbitPhase1RoomBootstrap
  ) {
    bootstrappedRooms.append(room)
  }
}
