import Testing

@testable import StudioFeatures

struct OrbitServerBackedRoomClientFactoryTests {
  @Test
  func factoryReturnsNilWhenGatewayConfigIsMissing() {
    let client = OrbitServerBackedRoomClientFactory.makeIfConfigured(
      environment: [:]
    )

    #expect(client == nil)
  }

  @Test
  func factoryBuildsClientWhenGatewayConfigIsPresent() {
    let client = OrbitServerBackedRoomClientFactory.makeIfConfigured(
      environment: [
        "ORBIT_SERVER_GATEWAY_BASE_URL": "http://localhost:8080",
      ]
    )

    #expect(client != nil)
  }

  @Test
  func factoryBuildsClientWhenBaseURLFallbackIsPresent() {
    let client = OrbitServerBackedRoomClientFactory.makeIfConfigured(
      environment: [
        "ORBIT_SERVER_BASE_URL": "http://localhost:8081",
      ]
    )

    #expect(client != nil)
  }
}
