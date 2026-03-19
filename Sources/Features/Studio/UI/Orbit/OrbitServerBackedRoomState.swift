import Foundation
import OrbitServerRuntime

struct OrbitServerBackedRoomState: Equatable {
  var snapshot: OrbitPhase1RealtimeSnapshot?
  var session: OrbitPhase1RealtimeSession?
  var projectedWorkspace: OrbitWorkspace?

  mutating func apply(
    _ response: OrbitPhase1RealtimeTransportResponse
  ) throws {
    switch response {
    case .bootstrap(let session, let snapshot), .resync(let session, let snapshot, _):
      self.session = session
      self.snapshot = snapshot
      self.projectedWorkspace = OrbitServerRoomProjection.workspace(from: snapshot)
    case .replay(let session, let events):
      guard let snapshot else {
        self.session = session
        return
      }

      let updatedSnapshot = try OrbitPhase1RealtimeSnapshotReducer.applying(
        events: events,
        to: snapshot
      )
      self.session = session
      self.snapshot = OrbitPhase1RealtimeSnapshot(
        room: updatedSnapshot.room,
        replayCursor: session.replayCursor
      )
      self.projectedWorkspace = OrbitServerRoomProjection.workspace(from: self.snapshot!)
    case .noChange(let session):
      self.session = session
    }
  }
}
