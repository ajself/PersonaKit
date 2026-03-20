import Testing

@testable import OrbitServer
@testable import OrbitServerRuntime

struct OrbitServerConfigurationTests {
  @Test
  func configurationUsesLocalServerDefaultsWhenOnlyPostgresEnvironmentIsProvided() throws {
    let configuration = try OrbitServerConfiguration(
      environment: [
        "ORBIT_PG_HOST": "127.0.0.1",
        "ORBIT_PG_USER": "orbit",
        "ORBIT_PG_PASSWORD": "secret",
        "ORBIT_PG_DATABASE": "orbit",
      ]
    )

    #expect(configuration.host == "127.0.0.1")
    #expect(configuration.port == 8080)
    #expect(
      configuration.postgres == OrbitPostgresConfiguration(
        host: "127.0.0.1",
        port: 5432,
        username: "orbit",
        password: "secret",
        database: "orbit"
      )
    )
  }

  @Test
  func configurationAllowsEmptyPostgresPasswordForLocalTrustAuth() throws {
    let configuration = try OrbitServerConfiguration(
      environment: [
        "ORBIT_PG_HOST": "127.0.0.1",
        "ORBIT_PG_USER": "orbit",
        "ORBIT_PG_PASSWORD": "",
        "ORBIT_PG_DATABASE": "orbit",
      ]
    )

    #expect(configuration.postgres.password.isEmpty)
  }

  @Test
  func configurationFailsFastWhenPostgresEnvironmentIsMissing() throws {
    do {
      _ = try OrbitServerConfiguration(
        environment: [
          "ORBIT_PG_USER": "orbit",
          "ORBIT_PG_PASSWORD": "secret",
          "ORBIT_PG_DATABASE": "orbit",
        ]
      )
      Issue.record("Expected missing Postgres host to fail.")
    } catch let error as OrbitServerConfigurationError {
      #expect(error == .missingEnvironmentVariable("ORBIT_PG_HOST"))
    } catch {
      Issue.record("Unexpected error: \(error)")
    }
  }

  @Test
  func configurationRejectsInvalidPortValues() throws {
    do {
      _ = try OrbitServerConfiguration(
        environment: [
          "ORBIT_SERVER_PORT": "port",
          "ORBIT_PG_HOST": "127.0.0.1",
          "ORBIT_PG_USER": "orbit",
          "ORBIT_PG_PASSWORD": "secret",
          "ORBIT_PG_DATABASE": "orbit",
        ]
      )
      Issue.record("Expected invalid server port to fail.")
    } catch let error as OrbitServerConfigurationError {
      #expect(error == .invalidEnvironmentVariable("ORBIT_SERVER_PORT", "port"))
    } catch {
      Issue.record("Unexpected error: \(error)")
    }

    do {
      _ = try OrbitServerConfiguration(
        environment: [
          "ORBIT_PG_HOST": "127.0.0.1",
          "ORBIT_PG_PORT": "port",
          "ORBIT_PG_USER": "orbit",
          "ORBIT_PG_PASSWORD": "secret",
          "ORBIT_PG_DATABASE": "orbit",
        ]
      )
      Issue.record("Expected invalid Postgres port to fail.")
    } catch let error as OrbitServerConfigurationError {
      #expect(error == .invalidEnvironmentVariable("ORBIT_PG_PORT", "port"))
    } catch {
      Issue.record("Unexpected error: \(error)")
    }
  }
}
