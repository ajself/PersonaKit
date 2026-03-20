import Foundation
import Logging
import Vapor

@main
enum OrbitServerMain {
  static func main() async {
    do {
      var environment = try Environment.detect()
      try LoggingSystem.bootstrap(from: &environment)

      let app = try await OrbitServerApplication.makeLive(
        environment: ProcessInfo.processInfo.environment,
        appEnvironment: environment
      )

      do {
        try await app.execute()
        try await app.asyncShutdown()
      } catch {
        try? await app.asyncShutdown()
        throw error
      }
    } catch {
      let message =
        (error as? LocalizedError)?.errorDescription
        ?? String(describing: error)
      fputs("error: \(message)\n", stderr)
      Foundation.exit(1)
    }
  }
}
