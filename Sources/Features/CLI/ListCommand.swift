import ArgumentParser
import ContextCore
import Foundation

/// Supported entity categories for the `list` CLI command.
enum ListEntityType: String, CaseIterable, Codable, ExpressibleByArgument {
  case personas
  case kits
  case directives
  case intents
  case references
  case skills
  case essentials
  case sessions
}

/// Renders deterministic line-based listings from loaded PersonaKit scopes.
struct ListCommand {
  /// Lists entities using a single explicit root directory.
  ///
  /// - Parameters:
  ///   - root: PersonaKit root URL.
  ///   - entityType: Entity kind to render.
  ///   - fileManager: File manager used for disk reads.
  /// - Returns: Newline-separated listing output.
  static func list(
    root: URL,
    entityType: ListEntityType,
    fileManager: FileManager = .default
  ) throws -> String {
    try list(
      scopes: ScopeSet(projectScopeURL: root, globalScopeURL: nil),
      entityType: entityType,
      fileManager: fileManager
    )
  }

  /// Lists entities from merged scopes.
  ///
  /// - Parameters:
  ///   - scopes: Resolved project/global scope set.
  ///   - entityType: Entity kind to render.
  ///   - fileManager: File manager used for disk reads.
  /// - Returns: Newline-separated listing output.
  static func list(
    scopes: ScopeSet,
    entityType: ListEntityType,
    fileManager: FileManager = .default
  ) throws -> String {
    let registry = try Registry.load(scopes: scopes, fileManager: fileManager)
    let lines: [String]

    switch entityType {
    case .personas:
      lines = registry.personas.map { formatLine(id: $0.id, name: $0.name) }
    case .kits:
      lines = registry.kits.map { formatLine(id: $0.id, name: $0.name) }
    case .directives:
      lines = registry.directives.map { formatLine(id: $0.id, name: $0.title) }
    case .intents:
      lines = registry.intentTemplates.map { formatLine(id: $0.id, name: $0.name) }
    case .references:
      lines = registry.references.map { formatLine(id: $0.id, name: $0.name) }
    case .skills:
      lines = registry.skills.map { formatLine(id: $0.id, name: $0.name) }
    case .essentials:
      lines = try listEssentials(scopes: scopes, fileManager: fileManager)
    case .sessions:
      lines = try listSessions(scopes: scopes, fileManager: fileManager)
    }

    return lines.joined(separator: "\n")
  }

  static func sessionIDs(
    scopes: ScopeSet,
    fileManager: FileManager = .default
  ) throws -> [String] {
    try SessionFileLoader.list(scopes: scopes, fileManager: fileManager).map(\.id)
  }

  /// Discovers markdown essential IDs from the resolved scope load order.
  static func essentialIDs(
    scopes: ScopeSet,
    fileManager: FileManager = .default
  ) throws -> [String] {
    try listEssentials(scopes: scopes, fileManager: fileManager)
  }

  /// Formats an identifier and optional display name for human-readable output.
  private static func formatLine(id: String, name: String?) -> String {
    let trimmedName = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    guard !trimmedName.isEmpty else {
      return id
    }
    return "\(id) — \(trimmedName)"
  }

  /// Discovers markdown essential IDs from the resolved scope load order.
  private static func listEssentials(scopes: ScopeSet, fileManager: FileManager) throws -> [String] {
    var ids: Set<String> = []
    for root in scopes.loadOrder {
      let essentialsURL = root.appendingPathComponent("Packs/essentials")
      var isDirectory: ObjCBool = false

      let essentialsExists = fileManager.fileExists(
        atPath: essentialsURL.path,
        isDirectory: &isDirectory
      )

      guard essentialsExists else {
        continue
      }

      guard isDirectory.boolValue else {
        throw CLIError.failure("Essentials path is not a directory: \(essentialsURL.path)")
      }

      let files: [URL]
      do {
        files = try fileManager.contentsOfDirectory(
          at: essentialsURL,
          includingPropertiesForKeys: nil,
          options: [.skipsHiddenFiles]
        )
      } catch {
        throw CLIError.failure("Failed to read essentials directory: \(error.localizedDescription)")
      }

      for file in files where file.pathExtension == "md" {
        ids.insert(file.deletingPathExtension().lastPathComponent)
      }
    }

    return ids.sorted()
  }

  /// Discovers session files from the resolved scopes and renders stable summaries.
  private static func listSessions(scopes: ScopeSet, fileManager: FileManager) throws -> [String] {
    try SessionFileLoader.list(scopes: scopes, fileManager: fileManager).map(formatSessionLine)
  }

  private static func formatSessionLine(_ session: SessionFile) -> String {
    let kitOverrides = (session.kitOverrides ?? []).sorted()
    let summary = "\(session.personaId) / \(session.directiveId)"

    guard !kitOverrides.isEmpty else {
      return "\(session.id) — \(summary)"
    }

    return "\(session.id) — \(summary) [kits: \(kitOverrides.joined(separator: ", "))]"
  }
}
