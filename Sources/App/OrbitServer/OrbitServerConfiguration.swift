import Foundation
import OrbitServerRuntime

enum OrbitServerConfigurationError: Error, Equatable {
  case missingEnvironmentVariable(String)
  case invalidEnvironmentVariable(String, String)
}

extension OrbitServerConfigurationError: LocalizedError {
  var errorDescription: String? {
    switch self {
    case .missingEnvironmentVariable(let key):
      return "Missing required environment variable \(key)."
    case .invalidEnvironmentVariable(let key, let value):
      return "Environment variable \(key) must be valid, got \(value)."
    }
  }
}

struct OrbitServerConfiguration: Equatable, Sendable {
  let host: String
  let port: Int
  let postgres: OrbitPostgresConfiguration

  init(
    environment: [String: String] = ProcessInfo.processInfo.environment
  ) throws {
    self.host = environment["ORBIT_SERVER_HOST"] ?? "127.0.0.1"

    if let rawPort = environment["ORBIT_SERVER_PORT"] {
      guard let parsedPort = Int(rawPort) else {
        throw OrbitServerConfigurationError.invalidEnvironmentVariable(
          "ORBIT_SERVER_PORT",
          rawPort
        )
      }

      self.port = parsedPort
    } else {
      self.port = 8080
    }

    guard let host = environment["ORBIT_PG_HOST"], !host.isEmpty else {
      throw OrbitServerConfigurationError.missingEnvironmentVariable("ORBIT_PG_HOST")
    }

    guard let username = environment["ORBIT_PG_USER"], !username.isEmpty else {
      throw OrbitServerConfigurationError.missingEnvironmentVariable("ORBIT_PG_USER")
    }

    guard let password = environment["ORBIT_PG_PASSWORD"] else {
      throw OrbitServerConfigurationError.missingEnvironmentVariable("ORBIT_PG_PASSWORD")
    }

    guard let database = environment["ORBIT_PG_DATABASE"], !database.isEmpty else {
      throw OrbitServerConfigurationError.missingEnvironmentVariable("ORBIT_PG_DATABASE")
    }

    let postgresPort: Int
    if let rawPort = environment["ORBIT_PG_PORT"] {
      guard let parsedPort = Int(rawPort) else {
        throw OrbitServerConfigurationError.invalidEnvironmentVariable(
          "ORBIT_PG_PORT",
          rawPort
        )
      }

      postgresPort = parsedPort
    } else {
      postgresPort = 5432
    }

    self.postgres = OrbitPostgresConfiguration(
      host: host,
      port: postgresPort,
      username: username,
      password: password,
      database: database
    )
  }
}
