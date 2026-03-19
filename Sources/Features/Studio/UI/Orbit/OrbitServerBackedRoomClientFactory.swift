import Foundation
import OrbitServerGateway
import OrbitServerRuntime

enum OrbitServerBackedRoomClientFactory {
  static func makeIfConfigured(
    environment: [String: String] = ProcessInfo.processInfo.environment
  ) -> OrbitServerBackedRoomClient? {
    guard environment["ORBIT_SERVER_BACKED_ROOM"] == "1" else {
      return nil
    }

    guard
      let host = environment["ORBIT_PG_HOST"],
      let username = environment["ORBIT_PG_USER"],
      let password = environment["ORBIT_PG_PASSWORD"],
      let database = environment["ORBIT_PG_DATABASE"]
    else {
      return nil
    }

    let port = environment["ORBIT_PG_PORT"].flatMap(Int.init) ?? 5432
    let configuration = OrbitPostgresConfiguration(
      host: host,
      port: port,
      username: username,
      password: password,
      database: database
    )
    let runtimeStore = OrbitPostgresRuntimeStore(configuration: configuration)
    let realtimeLoader = OrbitPostgresRealtimeLoader(runtimeStore: runtimeStore)
    let feedService = realtimeLoader.makeFeedService()
    let subscriptionAdapter = OrbitPhase1RealtimeSubscriptionAdapter(feedService: feedService)
    let pollingService = OrbitPhase1RealtimePollingSessionService(adapter: subscriptionAdapter)
    let transport = OrbitPhase1RealtimeTransportAdapter(pollingService: pollingService)
    let roomWriter = OrbitPhase1RoomWriteService(runtimeStore: runtimeStore)
    let systemWriter = OrbitPhase1SystemMessageService(runtimeStore: runtimeStore)
    let failureWriter = OrbitPhase1ActivationFailureService(runtimeStore: runtimeStore)
    let collaboratorWriter = OrbitPhase1CollaboratorResponseService(runtimeStore: runtimeStore)

    return OrbitServerBackedRoomClient(
      transport: transport,
      roomWriter: roomWriter,
      systemWriter: systemWriter,
      failureWriter: failureWriter,
      collaboratorWriter: collaboratorWriter
    )
  }
}
