import ArgumentParser
import ContextCore
import Foundation

/// Derives and prints the read-only checks manifest for a resolved contract.
///
/// Phase 1a: pure derivation and display. Emits no host artifacts and performs no
/// enforcement — projecting the manifest into a concrete host is Phase 1b.
struct ChecksCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "checks",
    abstract: "Derive the read-only checks manifest from a resolved contract.",
    discussion: """
      Classifies each mandate by the enforcement class it can reach: hook \
      (deterministic deny, from the persona's forbiddenCapabilities), command \
      (from directive verification commands), or review (the remaining \
      verification items). Output is deterministic and host-neutral; it neither \
      installs nor runs any enforcement.
      """
  )

  @OptionGroup
  var scope: ScopeOptions

  @OptionGroup
  var session: SessionSelection

  mutating func validate() throws {
    try session.validate(mode: .checks)
  }

  func run() throws {
    let scopes = try CLIHelpers.resolveScopes(options: scope)
    let result: SessionContractResult

    do {
      if let sessionId = session.sessionId {
        let sessionFile = try SessionFileLoader.load(scopes: scopes, sessionId: sessionId)
        result = try SessionContractResolver.resolve(scopes: scopes, session: sessionFile)
      } else {
        result = try SessionContractResolver.resolve(
          scopes: scopes,
          personaId: session.personaId ?? "",
          directiveId: session.directiveId,
          kitOverrides: session.directiveId == nil ? [] : session.kitIds
        )
      }
    } catch let error as ResolverResolutionError {
      var stderrStream = StandardError()
      for resolutionError in error.errors {
        stderrStream.write(CLIHelpers.formatResolutionError(resolutionError) + "\n")
      }
      throw ExitCode.failure
    } catch let error as RegistryLoadError {
      var stderrStream = StandardError()
      for registryError in error.errors {
        stderrStream.write(CLIHelpers.formatRegistryError(registryError) + "\n")
      }
      throw ExitCode.failure
    }

    let manifest = ChecksManifestDeriver.derive(from: result)

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(manifest)

    guard let output = String(data: data, encoding: .utf8) else {
      throw CLIError.failure("Failed to encode checks manifest output.")
    }

    print(output)
  }
}
