import Testing

@testable import StudioFeatures

struct OrbitServerBackedRoomClientFactoryTests {
  @Test
  func factoryReturnsNilWhenServerBackedRoomModeIsDisabled() {
    let client = OrbitServerBackedRoomClientFactory.makeIfConfigured(
      environment: [:]
    )

    #expect(client == nil)
  }

  @Test
  func factoryReturnsNilWhenGatewayConfigIsMissing() {
    let client = OrbitServerBackedRoomClientFactory.makeIfConfigured(
      environment: [
        "ORBIT_SERVER_BACKED_ROOM": "1",
      ]
    )

    #expect(client == nil)
  }

  @Test
  func factoryBuildsClientWhenGatewayConfigIsPresent() {
    let client = OrbitServerBackedRoomClientFactory.makeIfConfigured(
      environment: [
        "ORBIT_SERVER_BACKED_ROOM": "1",
        "ORBIT_SERVER_GATEWAY_BASE_URL": "http://localhost:8080",
      ]
    )

    #expect(client != nil)
  }
}
