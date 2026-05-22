import Foundation

/// In-memory lookup tables for all loaded PersonaKit entities.
public struct Registry: Sendable {
  public let personasById: [String: Persona]
  public let kitsById: [String: Kit]
  public let directivesById: [String: Directive]
  public let intentTemplatesById: [String: IntentTemplate]
  public let referencesById: [String: Reference]
  public let skillsById: [String: Skill]

  public var personas: [Persona] {
    personasById.sorted { $0.key < $1.key }.map { $0.value }
  }

  public var kits: [Kit] {
    kitsById.sorted { $0.key < $1.key }.map { $0.value }
  }

  public var directives: [Directive] {
    directivesById.sorted { $0.key < $1.key }.map { $0.value }
  }

  public var intentTemplates: [IntentTemplate] {
    intentTemplatesById.sorted { $0.key < $1.key }.map { $0.value }
  }

  public var references: [Reference] {
    referencesById.sorted { $0.key < $1.key }.map { $0.value }
  }

  public var skills: [Skill] {
    skillsById.sorted { $0.key < $1.key }.map { $0.value }
  }

  /// Loads a registry from a single root scope.
  ///
  /// - Parameters:
  ///   - root: PersonaKit root directory containing `Packs/`.
  ///   - fileManager: File system interface used for reads.
  /// - Returns: Populated ``Registry``.
  /// - Throws: ``RegistryLoadError`` when directory, read, or decode failures occur.
  public static func load(root: URL, fileManager: FileManager = .default) throws -> Registry {
    try load(scopes: ScopeSet(projectScopeURL: root, globalScopeURL: nil), fileManager: fileManager)
  }

  /// Loads and merges registry entities from the provided scope set.
  ///
  /// Later roots in load order override earlier entities by id.
  ///
  /// - Parameters:
  ///   - scopes: Project/global scope roots used for entity loading.
  ///   - fileManager: File system interface used for reads.
  /// - Returns: Populated ``Registry``.
  /// - Throws: ``RegistryLoadError`` when directory, read, or decode failures occur.
  public static func load(scopes: ScopeSet, fileManager: FileManager = .default) throws -> Registry {
    let roots = scopes.loadOrder

    guard !roots.isEmpty else {
      let error = RegistryError(
        relativePath: "Packs",
        entityType: .packsRoot,
        id: nil,
        message: "Missing Packs directory."
      )

      throw RegistryLoadError(errors: [error])
    }

    var errors: [RegistryError] = []
    let decoder = JSONDecoder()
    var personasById: [String: Persona] = [:]
    var kitsById: [String: Kit] = [:]
    var directivesById: [String: Directive] = [:]
    var intentTemplatesById: [String: IntentTemplate] = [:]
    var referencesById: [String: Reference] = [:]
    var skillsById: [String: Skill] = [:]

    for root in roots {
      let packsURL = PersonaKitDirectory.packsURL(root: root)
      var isDirectory: ObjCBool = false

      let packsExists = fileManager.fileExists(atPath: packsURL.path, isDirectory: &isDirectory)

      guard packsExists else {
        errors.append(
          RegistryError(
            relativePath: "Packs",
            entityType: .packsRoot,
            id: nil,
            message: "Missing Packs directory."
          )
        )

        continue
      }

      guard isDirectory.boolValue else {
        errors.append(
          RegistryError(
            relativePath: "Packs",
            entityType: .packsRoot,
            id: nil,
            message: "Expected directory."
          )
        )

        continue
      }

      let personas: [String: Persona] = loadEntities(
        root: root,
        directory: packsURL.appendingPathComponent("personas"),
        suffix: ".persona.json",
        entityType: .persona,
        decoder: decoder,
        fileManager: fileManager,
        errors: &errors
      )

      let kits: [String: Kit] = loadEntities(
        root: root,
        directory: packsURL.appendingPathComponent("kits"),
        suffix: ".kit.json",
        entityType: .kit,
        decoder: decoder,
        fileManager: fileManager,
        errors: &errors
      )

      let directives: [String: Directive] = loadEntities(
        root: root,
        directory: packsURL.appendingPathComponent("directives"),
        suffix: ".directive.json",
        entityType: .directive,
        decoder: decoder,
        fileManager: fileManager,
        errors: &errors
      )

      let intents: [String: IntentTemplate] = loadEntities(
        root: root,
        directory: packsURL.appendingPathComponent("intents"),
        suffix: ".intent.json",
        entityType: .intentTemplate,
        decoder: decoder,
        fileManager: fileManager,
        errors: &errors
      )

      let references: [String: Reference] = loadEntities(
        root: root,
        directory: packsURL.appendingPathComponent("references"),
        suffix: ".reference.json",
        entityType: .reference,
        decoder: decoder,
        fileManager: fileManager,
        errors: &errors
      )

      let skills: [String: Skill] = loadEntities(
        root: root,
        directory: packsURL.appendingPathComponent("skills"),
        suffix: ".skill.json",
        entityType: .skill,
        decoder: decoder,
        fileManager: fileManager,
        errors: &errors
      )

      for (id, persona) in personas {
        personasById[id] = persona
      }

      for (id, kit) in kits {
        kitsById[id] = kit
      }

      for (id, directive) in directives {
        directivesById[id] = directive
      }

      for (id, intent) in intents {
        intentTemplatesById[id] = intent
      }

      for (id, reference) in references {
        referencesById[id] = reference
      }

      for (id, skill) in skills {
        skillsById[id] = skill
      }
    }

    if !errors.isEmpty {
      throw RegistryLoadError(errors: errors)
    }

    return Registry(
      personasById: personasById,
      kitsById: kitsById,
      directivesById: directivesById,
      intentTemplatesById: intentTemplatesById,
      referencesById: referencesById,
      skillsById: skillsById
    )
  }
}

/// Shared constraint for decoded entities that expose an id.
private protocol EntityWithID {
  var id: String { get }
}

extension Persona: EntityWithID {}
extension Kit: EntityWithID {}
extension Directive: EntityWithID {}
extension IntentTemplate: EntityWithID {}
extension Reference: EntityWithID {}
extension Skill: EntityWithID {}

/// Loads entity JSON files for a single pack directory and validates duplicate ids.
private func loadEntities<T: Decodable & EntityWithID>(
  root: URL,
  directory: URL,
  suffix: String,
  entityType: RegistryEntityType,
  decoder: JSONDecoder,
  fileManager: FileManager,
  errors: inout [RegistryError]
) -> [String: T] {
  var results: [String: T] = [:]
  var isDirectory: ObjCBool = false

  let directoryExists = fileManager.fileExists(atPath: directory.path, isDirectory: &isDirectory)

  guard directoryExists else {
    return results
  }

  guard isDirectory.boolValue else {
    errors.append(
      RegistryError(
        relativePath: relativePath(for: directory, root: root),
        entityType: entityType,
        id: nil,
        message: "Expected directory."
      )
    )

    return results
  }

  let files: [URL]

  do {
    files = try fileManager.contentsOfDirectory(
      at: directory,
      includingPropertiesForKeys: nil,
      options: [.skipsHiddenFiles]
    )
  } catch {
    let relativePath = relativePath(for: directory, root: root)

    errors.append(
      RegistryError(
        relativePath: relativePath,
        entityType: entityType,
        id: nil,
        message: "Failed to read directory: \(error.localizedDescription)"
      )
    )

    return results
  }

  let sortedFiles =
    files
    .filter { $0.lastPathComponent.hasSuffix(suffix) }
    .sorted { $0.lastPathComponent < $1.lastPathComponent }

  for fileURL in sortedFiles {
    let relativePath = relativePath(for: fileURL, root: root)
    let data: Data

    do {
      data = try Data(contentsOf: fileURL)
    } catch {
      errors.append(
        RegistryError(
          relativePath: relativePath,
          entityType: entityType,
          id: nil,
          message: "Failed to read file: \(error.localizedDescription)"
        )
      )

      continue
    }

    let decoded: T

    do {
      decoded = try decoder.decode(T.self, from: data)
    } catch {
      errors.append(
        RegistryError(
          relativePath: relativePath,
          entityType: entityType,
          id: nil,
          message: "Failed to decode JSON: \(error.localizedDescription)"
        )
      )
      continue
    }

    if results[decoded.id] != nil {
      errors.append(
        RegistryError(
          relativePath: relativePath,
          entityType: entityType,
          id: decoded.id,
          message: "Duplicate id \"\(decoded.id)\"."
        )
      )

      continue
    }

    results[decoded.id] = decoded
  }

  return results
}

private func relativePath(for fileURL: URL, root: URL) -> String {
  let rootComponents = root.standardizedFileURL.pathComponents
  let fileComponents = fileURL.standardizedFileURL.pathComponents
  let relativeComponents = fileComponents.dropFirst(rootComponents.count)
  return relativeComponents.joined(separator: "/")
}
