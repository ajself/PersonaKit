import Foundation
import OrbitServerGateway
import OrbitServerRuntime
import Vapor

enum OrbitServerApplication {
  static func makeLive(
    environment: [String: String] = ProcessInfo.processInfo.environment,
    appEnvironment: Environment = .development
  ) async throws -> Application {
    let configuration = try OrbitServerConfiguration(environment: environment)
    let runtimeStore = OrbitPostgresRuntimeStore(configuration: configuration.postgres)
    let app = try await Application.make(appEnvironment)

    do {
      try await runtimeStore.applyPhase1Schema()
      try await OrbitCanonicalCommandCenterBootstrapper(
        runtimeStore: runtimeStore
      ).ensureBootstrapped()

      let realtimeLoader = OrbitPostgresRealtimeLoader(runtimeStore: runtimeStore)
      let feedService = realtimeLoader.makeFeedService()
      let subscriptionAdapter = OrbitPhase1RealtimeSubscriptionAdapter(
        feedService: feedService
      )
      let pollingService = OrbitPhase1RealtimePollingSessionService(
        adapter: subscriptionAdapter
      )
      let transport = OrbitPhase1RealtimeTransportAdapter(
        pollingService: pollingService
      )
      let roomWriter = OrbitPhase1RoomWriteService(runtimeStore: runtimeStore)
      let systemWriter = OrbitPhase1SystemMessageService(runtimeStore: runtimeStore)
      let failureWriter = OrbitPhase1ActivationFailureService(runtimeStore: runtimeStore)
      let promotionWriter = OrbitPhase1MeetingPromotionEventService(runtimeStore: runtimeStore)
      let meetingCreator = OrbitPhase1MeetingRoomCreationService(
        runtimeStore: runtimeStore
      )
      let meetingPromoter = OrbitPhase1MeetingRoomPromotionService(
        runtimeStore: runtimeStore,
        meetingCreationService: meetingCreator
      )
      let collaboratorWriter = OrbitPhase1CollaboratorResponseService(
        runtimeStore: runtimeStore
      )

      configure(
        app: app,
        configuration: configuration,
        transport: transport,
        roomWriter: roomWriter,
        systemWriter: systemWriter,
        failureWriter: failureWriter,
        promotionWriter: promotionWriter,
        meetingPromoter: meetingPromoter,
        collaboratorWriter: collaboratorWriter,
        meetingCreator: meetingCreator
      )

      return app
    } catch {
      try? await app.asyncShutdown()
      throw error
    }
  }

  static func configure<Transport: OrbitRealtimeTransportHandling>(
    app: Application,
    configuration: OrbitServerConfiguration,
    transport: Transport,
    roomWriter: (any OrbitPhase1RoomWriteServing)? = nil,
    systemWriter: (any OrbitSystemMessageHandling)? = nil,
    failureWriter: (any OrbitActivationFailureHandling)? = nil,
    promotionWriter: (any OrbitMeetingPromotionEventHandling)? = nil,
    meetingPromoter: (any OrbitMeetingRoomPromotionHandling)? = nil,
    collaboratorWriter: (any OrbitCollaboratorResponseHandling)? = nil,
    meetingCreator: (any OrbitMeetingRoomCreationHandling)? = nil
  ) {
    app.http.server.configuration.hostname = configuration.host
    app.http.server.configuration.port = configuration.port

    app.get("healthz") { _ in
      HTTPStatus.ok
    }

    OrbitGatewayRoutes.register(
      on: app,
      transport: transport,
      roomWriter: roomWriter,
      systemWriter: systemWriter,
      failureWriter: failureWriter,
      promotionWriter: promotionWriter,
      meetingPromoter: meetingPromoter,
      collaboratorWriter: collaboratorWriter,
      meetingCreator: meetingCreator
    )
  }
}
