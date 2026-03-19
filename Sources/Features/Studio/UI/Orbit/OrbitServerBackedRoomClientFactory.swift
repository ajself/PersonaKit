import Foundation
import OrbitServerRuntime

enum OrbitServerBackedRoomClientFactory {
  static func makeIfConfigured(
    environment: [String: String] = ProcessInfo.processInfo.environment
  ) -> OrbitServerBackedRoomClient? {
    guard environment["ORBIT_SERVER_BACKED_ROOM"] == "1" else {
      return nil
    }

    guard
      let baseURLString =
        environment["ORBIT_SERVER_GATEWAY_BASE_URL"]
        ?? environment["ORBIT_SERVER_BASE_URL"],
      let baseURL = URL(string: baseURLString)
    else {
      return nil
    }

    let gatewayClient = OrbitGatewayNetworkClient(baseURL: baseURL)

    return OrbitServerBackedRoomClient(
      connectHandler: { scope in
        try await gatewayClient.connect(
          request: OrbitPhase1RealtimeConnectRequest(scope: scope)
        )
      },
      pollHandler: { session in
        try await gatewayClient.poll(
          request: OrbitPhase1RealtimePollRequest(session: session)
        )
      },
      appendHandler: { request in
        try await gatewayClient.appendUserMessage(request)
      },
      appendSystemHandler: { request in
        try await gatewayClient.appendSystemMessage(request)
      },
      appendCollaboratorHandler: { request in
        try await gatewayClient.appendCollaboratorResponse(request)
      },
      appendFailureHandler: { request in
        try await gatewayClient.appendActivationFailure(request)
      }
    )
  }
}
