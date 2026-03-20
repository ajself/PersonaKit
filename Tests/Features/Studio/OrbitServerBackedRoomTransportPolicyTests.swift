import Testing

@testable import StudioFeatures

struct OrbitServerBackedRoomTransportPolicyTests {
  @Test
  func socketFailuresFallBackToHTTPPolling() {
    #expect(
      OrbitServerBackedRoomTransportPolicy.shouldFallBackToPolling(
        after: OrbitGatewayNetworkClientError.socketRejectedRequest
      ) == true
    )
    #expect(
      OrbitServerBackedRoomTransportPolicy.fallbackMessage(
        after: OrbitGatewayNetworkClientError.socketRejectedRequest
      ).contains("falling back to HTTP polling")
    )
  }

  @Test
  func cancellationDoesNotTriggerFallback() {
    #expect(
      OrbitServerBackedRoomTransportPolicy.shouldFallBackToPolling(
        after: CancellationError()
      ) == false
    )
  }
}
