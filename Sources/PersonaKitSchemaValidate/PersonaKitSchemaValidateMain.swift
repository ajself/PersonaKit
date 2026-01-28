import Dependencies
import Foundation
import PersonaKitCore

/// Derived schema constraints used by the validation tool.
///
/// Values are read from the JSON schema when possible, and fall back to
/// known defaults if any segment is missing.
struct SchemaConfig {
  /// Supported values for top-level `documentType`.
  let documentTypes: Set<String>
  /// Required fields for `pack` objects inside a persona pack.
  let packRequired: [String]
  /// Required fields for a `persona` object.
  let personaRequired: [String]
  /// Required top-level fields for a persona pack document.
  let personaPackRequired: [String]
  /// Allowed output formats in `defaults.outputFormat`.
  let outputFormats: Set<String>
}

/// CLI entry point for validating PersonaKit JSON against the bundled schema.
@main
enum PersonaKitSchemaValidate {
  /// Runs schema validation for `Examples/` or for any JSON files passed as arguments.
  static func main() {
    let fileClient = DependencyValues.current.fileClient
    let cwd = URL(fileURLWithPath: fileClient.currentDirectoryPath())
    guard let repoRoot = findRepoRoot(start: cwd, fileClient: fileClient) else {
      fputs("Schema validation failed: could not locate Schema/personakit.schema.json.\n", stderr)
      exit(2)
    }

    let schemaURL = repoRoot.appendingPathComponent("Schema/personakit.schema.json")
    guard let schemaData = try? fileClient.readData(schemaURL),
      let schemaJSON = try? JSONSerialization.jsonObject(with: schemaData) as? [String: Any]
    else {
      fputs("Schema validation failed: could not read schema at \(schemaURL.path).\n", stderr)
      exit(2)
    }

    let config = loadSchemaConfig(schemaJSON: schemaJSON)

    let args = Array(CommandLine.arguments.dropFirst())
    let inputPaths =
      args.isEmpty
      ? [repoRoot.appendingPathComponent("Examples")]
      : args.map { URL(fileURLWithPath: $0, relativeTo: cwd) }

    let exampleFiles = collectJSONFiles(paths: inputPaths, fileClient: fileClient)
    if exampleFiles.isEmpty {
      fputs("Schema validation failed: no JSON files found in Examples/.\n", stderr)
      exit(2)
    }

    var failures: [String] = []
    for file in exampleFiles {
      if let message = validateFile(file, config: config, fileClient: fileClient) {
        failures.append(message)
      }
    }

    if !failures.isEmpty {
      fputs("Schema validation failed:\n", stderr)
      for message in failures {
        fputs("- \(message)\n", stderr)
      }
      exit(1)
    }

    print("Schema validation passed for \(exampleFiles.count) file(s).")
  }
}

extension PersonaKitSchemaValidate {
  /// Walks up the directory tree to find `Schema/personakit.schema.json`.
  ///
  /// - Parameters:
  ///   - start: The starting directory, typically the current working directory.
  ///   - fileClient: File system dependency.
  /// - Returns: The repository root URL if found, otherwise `nil`.
  private static func findRepoRoot(start: URL, fileClient: FileClient) -> URL? {
    var current = start
    for _ in 0..<6 {
      let schema = current.appendingPathComponent("Schema/personakit.schema.json")
      if fileClient.fileExists(schema) {
        return current
      }
      current = current.deletingLastPathComponent()
    }
    return nil
  }

  /// Collects JSON files from the provided paths.
  ///
  /// Directories are scanned non-recursively; files are included if they end in
  /// `.json`. The returned list is sorted by filename.
  private static func collectJSONFiles(paths: [URL], fileClient: FileClient) -> [URL] {
    var files: [URL] = []
    for path in paths {
      guard fileClient.fileExists(path) else { continue }
      if fileClient.isDirectory(path) {
        if let contents = try? fileClient.contentsOfDirectory(path, nil) {
          for item in contents where item.pathExtension.lowercased() == "json" {
            files.append(item)
          }
        }
      } else if path.pathExtension.lowercased() == "json" {
        files.append(path)
      }
    }
    return files.sorted {
      $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
    }
  }

  /// Extracts validation constraints from the JSON schema with fallback defaults.
  private static func loadSchemaConfig(schemaJSON: [String: Any]) -> SchemaConfig {
    let documentTypes = Set(
      readStringArray(
        schemaJSON["properties"],
        keyPath: ["documentType", "enum"]
      )
    )
    let personaRequired = readStringArray(
      schemaJSON["$defs"],
      keyPath: ["persona", "required"]
    )
    let personaPackRequired = readStringArray(
      schemaJSON["allOf"],
      matchConst: "personaPack"
    )
    let packRequired = readStringArray(
      schemaJSON["allOf"],
      matchConst: "personaPack",
      thenKeyPath: ["properties", "pack", "required"]
    )
    let outputFormats = Set(
      readStringArray(
        schemaJSON["allOf"],
        matchConst: "personaPack",
        thenKeyPath: ["properties", "defaults", "properties", "outputFormat", "enum"]
      )
    )

    return SchemaConfig(
      documentTypes: documentTypes.isEmpty ? ["personaPack", "persona"] : documentTypes,
      packRequired: packRequired.isEmpty ? ["id", "name"] : packRequired,
      personaRequired: personaRequired.isEmpty ? ["id", "name", "system"] : personaRequired,
      personaPackRequired: personaPackRequired.isEmpty
        ? ["pack", "personas"] : personaPackRequired,
      outputFormats: outputFormats.isEmpty ? ["markdown", "text", "json"] : outputFormats
    )
  }

  /// Reads an array of strings at a nested key path from a JSON object.
  ///
  /// - Parameters:
  ///   - root: Root JSON object.
  ///   - keyPath: Sequence of keys leading to the array.
  /// - Returns: String values at the path, or an empty array if the path is missing.
  private static func readStringArray(_ root: Any?, keyPath: [String]) -> [String] {
    guard var current = root as? [String: Any] else { return [] }
    for key in keyPath.dropLast() {
      guard let next = current[key] as? [String: Any] else { return [] }
      current = next
    }
    guard let arr = current[keyPath.last ?? ""] as? [Any] else { return [] }
    return arr.compactMap { $0 as? String }
  }

  /// Reads an array of strings from an `allOf` list with a matching `if` clause.
  ///
  /// - Parameters:
  ///   - root: The `allOf` array.
  ///   - matchConst: The `documentType` const value to match.
  ///   - thenKeyPath: Optional key path under the `then` object; if omitted, uses `required`.
  /// - Returns: String values for the matching clause, or an empty array if missing.
  private static func readStringArray(
    _ root: Any?,
    matchConst: String,
    thenKeyPath: [String]? = nil
  ) -> [String] {
    guard let list = root as? [Any] else { return [] }
    for item in list {
      guard let dict = item as? [String: Any],
        let ifObj = dict["if"] as? [String: Any],
        let props = ifObj["properties"] as? [String: Any],
        let docType = props["documentType"] as? [String: Any],
        let constValue = docType["const"] as? String,
        constValue == matchConst
      else { continue }

      guard let thenObj = dict["then"] as? [String: Any] else { return [] }
      if let thenKeyPath {
        return readStringArray(thenObj, keyPath: thenKeyPath)
      }
      if let req = thenObj["required"] as? [Any] {
        return req.compactMap { $0 as? String }
      }
    }
    return []
  }
}
