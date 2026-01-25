import AppOpsCore
import Dependencies
import Foundation
import PersonaKitCore
import PersonaKitResources

/// Inputs used to run AppOps and produce a report.
struct AppOpsEnvironment {
  let fileClient: FileClient
  let now: () -> Date
  let repoRoot: () throws -> URL
  let runCommand: ([String]) -> String?
  let builtInPackURLs: (URL) -> [URL]

  /// Live environment wired to the local file system and process runner.
  static func live() -> AppOpsEnvironment {
    let provider = DependencyProvider()
    return AppOpsEnvironment(
      fileClient: provider.fileClient,
      now: Date.init,
      repoRoot: { try AppOpsCLI.defaultRepoRoot() },
      runCommand: AppOpsCLI.defaultRunCommand,
      builtInPackURLs: { repoRoot in
        AppOpsCLI.defaultBuiltInPackURLs(repoRoot: repoRoot)
      }
    )
  }
}

/// Output details captured after a successful AppOps run.
struct AppOpsRunResult {
  let outputRoot: URL
  let report: AppOpsReport
}

private struct DependencyProvider {
  @Dependency(\.fileClient)
  var fileClient
}

/// Command-line entry point for generating AppOps reports.
@main
enum AppOpsCLI {
  static func main() {
    do {
      _ = try run(arguments: Array(CommandLine.arguments.dropFirst()), environment: .live())
    } catch {
      fputs("Error: \(error)\n", stderr)
      exit(1)
    }
  }
}
