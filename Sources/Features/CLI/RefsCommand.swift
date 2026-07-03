import ArgumentParser
import ContextCore
import Foundation

/// Shared loader for the read-only PersonaKit reference graph.
enum ReferenceGraphLoader {
  static func load(scopes: ScopeSet) throws -> ReferenceGraph {
    let registry = try Registry.load(scopes: scopes)
    let sessions = try SessionFileLoader.list(scopes: scopes)

    return ReferenceGraph(registry: registry, sessions: sessions)
  }

  static func describe(_ node: ReferenceNode) -> String {
    "\(node.type.rawValue) \"\(node.id)\""
  }

  static func reportRegistryError(_ error: RegistryLoadError) {
    var stderrStream = StandardError()
    for registryError in error.errors {
      stderrStream.write(CLIHelpers.formatRegistryError(registryError) + "\n")
    }
  }
}

/// Traces forward and reverse references for a single entity id.
struct RefsCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "refs",
    abstract: "Trace what an entity references and what references it."
  )

  @OptionGroup
  var scope: ScopeOptions

  @Argument(help: "Entity id to trace across all entity types.")
  var id: String

  func run() throws {
    let scopes = try CLIHelpers.resolveScopes(options: scope)

    do {
      let graph = try ReferenceGraphLoader.load(scopes: scopes)
      let matches = graph.nodes(withId: id)

      guard !matches.isEmpty else {
        throw CLIError.failure("No entity with id \"\(id)\" found in the loaded scopes.")
      }

      var blocks: [String] = []

      for node in matches {
        var lines: [String] = [ReferenceGraphLoader.describe(node)]

        let outgoing = graph.outgoing(from: node)
        lines.append("  references (outgoing):")
        if outgoing.isEmpty {
          lines.append("    (none)")
        } else {
          for edge in outgoing {
            lines.append("    \(ReferenceGraphLoader.describe(edge.to)) (\(edge.field))")
          }
        }

        let incoming = graph.incoming(to: node)
        lines.append("  referenced by (incoming):")
        if incoming.isEmpty {
          lines.append("    (none)")
        } else {
          for edge in incoming {
            lines.append("    \(ReferenceGraphLoader.describe(edge.from)) (\(edge.field))")
          }
        }

        blocks.append(lines.joined(separator: "\n"))
      }

      print(blocks.joined(separator: "\n\n"))
    } catch let error as RegistryLoadError {
      ReferenceGraphLoader.reportRegistryError(error)
      throw ExitCode.failure
    }
  }
}

/// Lists entities that nothing references (orphans). Sessions are entry points and excluded.
struct OrphansCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "orphans",
    abstract: "List entities that nothing references (sessions are entry points and excluded)."
  )

  @OptionGroup
  var scope: ScopeOptions

  func run() throws {
    let scopes = try CLIHelpers.resolveScopes(options: scope)

    do {
      let graph = try ReferenceGraphLoader.load(scopes: scopes)
      let orphans = graph.orphans()

      guard !orphans.isEmpty else {
        print("No orphans found.")
        return
      }

      var lines = [
        "Orphans — entities nothing references (sessions excluded as entry points).",
        "Personas and directives are flagged below but remain invocable directly, so review before removing.",
      ]
      lines.append(contentsOf: orphans.map(Self.orphanLine))

      print(lines.joined(separator: "\n"))
    } catch let error as RegistryLoadError {
      ReferenceGraphLoader.reportRegistryError(error)
      throw ExitCode.failure
    }
  }

  /// Renders an orphan line, annotating directly-invocable entry points so an agent
  /// consuming the list cannot mistake a still-usable persona/directive for dead code.
  private static func orphanLine(_ node: ReferenceNode) -> String {
    let base = "  \(ReferenceGraphLoader.describe(node))"

    switch node.type {
    case .persona:
      return base + " — unreferenced by any session, but invocable directly via --persona"
    case .directive:
      return base + " — unreferenced by any session, but invocable directly via --directive"
    default:
      return base
    }
  }
}
