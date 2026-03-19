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
  func factoryReturnsNilWhenDatabaseConfigIsIncomplete() {
    let client = OrbitServerBackedRoomClientFactory.makeIfConfigured(
      environment: [
        "ORBIT_SERVER_BACKED_ROOM": "1",
        "ORBIT_PG_HOST": "localhost",
      ]
    )

    #expect(client == nil)
  }

  @Test
  func factoryBuildsClientWhenDatabaseConfigIsPresent() {
    let client = OrbitServerBackedRoomClientFactory.makeIfConfigured(
      environment: [
        "ORBIT_SERVER_BACKED_ROOM": "1",
        "ORBIT_PG_HOST": "localhost",
        "ORBIT_PG_PORT": "5432",
        "ORBIT_PG_USER": "orbit",
        "ORBIT_PG_PASSWORD": "secret",
        "ORBIT_PG_DATABASE": "orbit_runtime",
      ]
    )

    #expect(client != nil)
  }
}
