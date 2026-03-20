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

  @Test
  func degradedTransportRetriesPersistentPathAfterPollingCooldown() {
    var state = OrbitServerBackedRoomTransportRetryState()

    #expect(state.shouldAttemptPersistentTransport == true)

    state.recordPersistentTransportResult(.degradedToPolling)

    #expect(state.shouldAttemptPersistentTransport == false)

    for _ in 0 ..< OrbitServerBackedRoomTransportPolicy.pollsBeforePersistentRetry - 1 {
      state.recordPollingCycle()
      #expect(state.shouldAttemptPersistentTransport == false)
    }

    state.recordPollingCycle()

    #expect(state.shouldAttemptPersistentTransport == true)
  }

  @Test
  func unavailableTransportStopsPersistentRetries() {
    var state = OrbitServerBackedRoomTransportRetryState()

    state.recordPersistentTransportResult(.unavailable)

    for _ in 0 ..< 10 {
      state.recordPollingCycle()
    }

    #expect(state.shouldAttemptPersistentTransport == false)
  }
}
