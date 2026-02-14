import Foundation

/// Structured schema validation error for a single JSON file location.
struct SchemaValidationError: Error, Equatable {
  let relativePath: String
  let schemaName: String
  let message: String
  let instanceLocation: String?

  /// Returns validation errors in deterministic order for stable output.
  static func sort(errors: [SchemaValidationError]) -> [SchemaValidationError] {
    return errors.sorted { lhs, rhs in
      if lhs.relativePath != rhs.relativePath {
        return lhs.relativePath < rhs.relativePath
      }

      if lhs.schemaName != rhs.schemaName {
        return lhs.schemaName < rhs.schemaName
      }

      let lhsLocation = lhs.instanceLocation ?? ""
      let rhsLocation = rhs.instanceLocation ?? ""

      if lhsLocation != rhsLocation {
        return lhsLocation < rhsLocation
      }

      return lhs.message < rhs.message
    }
  }
}

/// Validates PersonaKit pack JSON files against bundled JSON schemas.
struct SchemaValidator {
  /// Maps a pack directory and file suffix to its schema filename.
  private struct SchemaMapping {
    let directory: String
    let suffix: String
    let schemaName: String
  }

  private static let mappings: [SchemaMapping] = [
    SchemaMapping(directory: "personas", suffix: ".persona.json", schemaName: "persona.schema.json"),
    SchemaMapping(directory: "kits", suffix: ".kit.json", schemaName: "kit.schema.json"),
    SchemaMapping(directory: "directives", suffix: ".directive.json", schemaName: "directive.schema.json"),
    SchemaMapping(directory: "intents", suffix: ".intent.json", schemaName: "intentTemplate.schema.json"),
    SchemaMapping(directory: "skills", suffix: ".skill.json", schemaName: "skill.schema.json"),
  ]

  /// Validates all known schema-mapped entities for each root in load order.
  ///
  /// - Parameters:
  ///   - scopes: Scope set whose load order defines validation roots.
  ///   - fileManager: File system interface used for reads.
  /// - Returns: Sorted schema validation errors across all roots.
  static func validate(scopes: ScopeSet, fileManager: FileManager = .default) -> [SchemaValidationError] {
    var errors: [SchemaValidationError] = []

    for root in scopes.loadOrder {
      if Task.isCancelled {
        return SchemaValidationError.sort(errors: errors)
      }

      errors.append(contentsOf: validate(root: root, fileManager: fileManager))
    }

    return SchemaValidationError.sort(errors: errors)
  }

  /// Validates all schema-mapped entities under a single PersonaKit root.
  ///
  /// - Parameters:
  ///   - root: PersonaKit root containing `Packs/`.
  ///   - fileManager: File system interface used for reads.
  /// - Returns: Sorted schema validation errors for the root.
  static func validate(root: URL, fileManager: FileManager = .default) -> [SchemaValidationError] {
    var errors: [SchemaValidationError] = []
    var schemaCache: [String: SchemaNode] = [:]

    for mapping in mappings {
      if Task.isCancelled {
        return SchemaValidationError.sort(errors: errors)
      }

      let directoryURL = root.appendingPathComponent("Packs/\(mapping.directory)")
      var isDirectory: ObjCBool = false

      guard fileManager.fileExists(atPath: directoryURL.path, isDirectory: &isDirectory),
        isDirectory.boolValue
      else {
        continue
      }

      let files: [URL]

      do {
        files = try fileManager.contentsOfDirectory(
          at: directoryURL,
          includingPropertiesForKeys: nil,
          options: [.skipsHiddenFiles]
        )
      } catch {
        let relativePath = relativePath(for: directoryURL, root: root)

        errors.append(
          SchemaValidationError(
            relativePath: relativePath,
            schemaName: mapping.schemaName,
            message: "Failed to read directory: \(error.localizedDescription)",
            instanceLocation: nil
          )
        )

        continue
      }

      let sortedFiles = files.filter {
        $0.lastPathComponent.hasSuffix(mapping.suffix)
      }
      .sorted {
        $0.lastPathComponent < $1.lastPathComponent
      }

      let schemaNode: SchemaNode

      if let cached = schemaCache[mapping.schemaName] {
        schemaNode = cached
      } else if let loaded = loadSchema(named: mapping.schemaName) {
        schemaCache[mapping.schemaName] = loaded
        schemaNode = loaded
      } else {
        for fileURL in sortedFiles {
          errors.append(
            SchemaValidationError(
              relativePath: relativePath(for: fileURL, root: root),
              schemaName: mapping.schemaName,
              message: "Missing schema file \(mapping.schemaName).",
              instanceLocation: nil
            )
          )
        }

        continue
      }

      for fileURL in sortedFiles {
        if Task.isCancelled {
          return SchemaValidationError.sort(errors: errors)
        }

        let relativePath = relativePath(for: fileURL, root: root)
        let data: Data

        do {
          data = try Data(contentsOf: fileURL)
        } catch {
          errors.append(
            SchemaValidationError(
              relativePath: relativePath,
              schemaName: mapping.schemaName,
              message: "Failed to read file: \(error.localizedDescription)",
              instanceLocation: nil
            )
          )

          continue
        }

        let json: Any

        do {
          json = try JSONSerialization.jsonObject(with: data)
        } catch {
          errors.append(
            SchemaValidationError(
              relativePath: relativePath,
              schemaName: mapping.schemaName,
              message: "Invalid JSON: \(error.localizedDescription)",
              instanceLocation: nil
            )
          )

          continue
        }

        var fileErrors: [SchemaValidationError] = []

        schemaNode.validate(
          value: json,
          path: "",
          relativePath: relativePath,
          schemaName: mapping.schemaName,
          errors: &fileErrors
        )
        errors.append(contentsOf: fileErrors)
      }
    }

    return SchemaValidationError.sort(errors: errors)
  }

  /// Validates raw JSON bytes against a specific bundled schema.
  ///
  /// - Parameters:
  ///   - jsonData: UTF-8 JSON payload.
  ///   - schemaName: Bundled schema filename (for example, `persona.schema.json`).
  ///   - relativePath: Relative path label used in error output.
  /// - Returns: Sorted schema validation errors.
  static func validate(
    jsonData: Data,
    schemaName: String,
    relativePath: String
  ) -> [SchemaValidationError] {
    guard let schemaNode = loadSchema(named: schemaName) else {
      return [
        SchemaValidationError(
          relativePath: relativePath,
          schemaName: schemaName,
          message: "Missing schema file \(schemaName).",
          instanceLocation: nil
        )
      ]
    }

    let json: Any

    do {
      json = try JSONSerialization.jsonObject(with: jsonData)
    } catch {
      return [
        SchemaValidationError(
          relativePath: relativePath,
          schemaName: schemaName,
          message: "Invalid JSON: \(error.localizedDescription)",
          instanceLocation: nil
        )
      ]
    }

    var errors: [SchemaValidationError] = []
    schemaNode.validate(
      value: json,
      path: "",
      relativePath: relativePath,
      schemaName: schemaName,
      errors: &errors
    )

    return SchemaValidationError.sort(errors: errors)
  }

  /// Loads and parses a bundled JSON schema by filename.
  private static func loadSchema(named schemaName: String) -> SchemaNode? {
    guard let url = Bundle.module.url(forResource: schemaName, withExtension: nil) else {
      return nil
    }

    do {
      let data = try Data(contentsOf: url)
      let json = try JSONSerialization.jsonObject(with: data)

      return SchemaNode(json: json)
    } catch {
      return nil
    }
  }
}

/// Recursive runtime representation of supported schema node types.
private indirect enum SchemaNode {
  case object(properties: [String: SchemaNode], required: Set<String>)
  case array(items: SchemaNode)
  case string
  case boolean
  case number
  case integer

  /// Initializes a schema node from decoded schema JSON.
  init?(json: Any) {
    guard let dictionary = json as? [String: Any], let type = dictionary["type"] as? String
    else {
      return nil
    }

    switch type {
    case "object":
      let propertiesValue = dictionary["properties"] as? [String: Any] ?? [:]
      var properties: [String: SchemaNode] = [:]

      for (key, value) in propertiesValue {
        if let schema = SchemaNode(json: value) {
          properties[key] = schema
        }
      }

      let required = Set(dictionary["required"] as? [String] ?? [])
      self = .object(properties: properties, required: required)
    case "array":
      guard let itemsValue = dictionary["items"], let items = SchemaNode(json: itemsValue) else {
        return nil
      }

      self = .array(items: items)
    case "string":
      self = .string
    case "boolean":
      self = .boolean
    case "number":
      self = .number
    case "integer":
      self = .integer
    default:
      return nil
    }
  }

  /// Validates a value against the schema node and appends violations.
  func validate(
    value: Any,
    path: String,
    relativePath: String,
    schemaName: String,
    errors: inout [SchemaValidationError]
  ) {
    switch self {
    case .object(let properties, let required):
      guard let object = value as? [String: Any] else {
        errors.append(
          typeError(
            relativePath: relativePath,
            schemaName: schemaName,
            path: path,
            expected: "object",
            actual: value
          )
        )
        return
      }

      for key in required.sorted() {
        if object[key] == nil {
          let location = pointerPath(path, key)
          errors.append(
            SchemaValidationError(
              relativePath: relativePath,
              schemaName: schemaName,
              message: "Missing required property \"\(key)\".",
              instanceLocation: location
            )
          )
        }
      }

      for key in properties.keys.sorted() {
        guard let schema = properties[key], let child = object[key] else {
          continue
        }

        schema.validate(
          value: child,
          path: pointerPath(path, key),
          relativePath: relativePath,
          schemaName: schemaName,
          errors: &errors
        )
      }
    case .array(let items):
      guard let array = value as? [Any] else {
        errors.append(
          typeError(
            relativePath: relativePath,
            schemaName: schemaName,
            path: path,
            expected: "array",
            actual: value
          )
        )

        return
      }

      for (index, element) in array.enumerated() {
        items.validate(
          value: element,
          path: pointerPath(path, String(index)),
          relativePath: relativePath,
          schemaName: schemaName,
          errors: &errors
        )
      }
    case .string:
      if value is String {
        return
      }

      errors.append(
        typeError(
          relativePath: relativePath,
          schemaName: schemaName,
          path: path,
          expected: "string",
          actual: value
        )
      )
    case .boolean:
      if value is Bool {
        return
      }

      errors.append(
        typeError(
          relativePath: relativePath,
          schemaName: schemaName,
          path: path,
          expected: "boolean",
          actual: value
        )
      )
    case .number:
      if let number = value as? NSNumber, !isBoolNumber(number) {
        return
      }

      errors.append(
        typeError(
          relativePath: relativePath,
          schemaName: schemaName,
          path: path,
          expected: "number",
          actual: value
        )
      )

    case .integer:
      if let number = value as? NSNumber, !isBoolNumber(number) {
        let doubleValue = number.doubleValue

        if doubleValue.rounded() == doubleValue {
          return
        }
      }

      errors.append(
        typeError(
          relativePath: relativePath,
          schemaName: schemaName,
          path: path,
          expected: "integer",
          actual: value
        )
      )
    }
  }

  /// Builds an escaped JSON Pointer path by appending one path component.
  private func pointerPath(_ path: String, _ component: String) -> String {
    let escaped = component.replacingOccurrences(of: "~", with: "~0").replacingOccurrences(of: "/", with: "~1")

    if path.isEmpty {
      return "/\(escaped)"
    }

    return "\(path)/\(escaped)"
  }

  /// Creates a standardized type-mismatch validation error.
  private func typeError(
    relativePath: String,
    schemaName: String,
    path: String,
    expected: String,
    actual: Any
  ) -> SchemaValidationError {
    let actualType = describeType(actual)
    let location = path.isEmpty ? "/" : path

    return SchemaValidationError(
      relativePath: relativePath,
      schemaName: schemaName,
      message: "Expected \(expected) but found \(actualType).",
      instanceLocation: location
    )
  }

  /// Maps runtime Swift/Foundation values to schema type labels.
  private func describeType(_ value: Any) -> String {
    if value is NSNull {
      return "null"
    }

    if value is String {
      return "string"
    }

    if value is Bool {
      return "boolean"
    }

    if value is [Any] {
      return "array"
    }

    if value is [String: Any] {
      return "object"
    }

    if let number = value as? NSNumber {
      return isBoolNumber(number) ? "boolean" : "number"
    }

    return "unknown"
  }

  /// Distinguishes boolean NSNumbers from numeric NSNumbers.
  private func isBoolNumber(_ number: NSNumber) -> Bool {
    return CFGetTypeID(number) == CFBooleanGetTypeID()
  }
}

/// Computes a root-relative path string for deterministic diagnostics.
private func relativePath(for fileURL: URL, root: URL) -> String {
  let rootComponents = root.standardizedFileURL.pathComponents
  let fileComponents = fileURL.standardizedFileURL.pathComponents
  let relativeComponents = fileComponents.dropFirst(rootComponents.count)

  return relativeComponents.joined(separator: "/")
}
